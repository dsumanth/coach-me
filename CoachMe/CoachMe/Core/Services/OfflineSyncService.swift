//
//  OfflineSyncService.swift
//  CoachMe
//
//  Story 7.3: Automatic Sync on Reconnect
//  Monitors network transitions and syncs data when connectivity is restored.
//

import Foundation
import os
@preconcurrency import Supabase
import SwiftData

// MARK: - Notification Name

extension Notification.Name {
    static let offlineSyncCompleted = Notification.Name("com.coachme.offlineSyncCompleted")
}

// MARK: - PendingOperation

/// Operations queued while offline for replay when connectivity is restored.
/// Only context profile edits can happen offline (messages require server-side LLM).
enum PendingOperationType: Codable {
    case updateContextProfile(ContextProfile)
}

/// Wraps an operation with retry metadata to prevent stale ops from accumulating.
struct PendingOperation: Codable {
    let operation: PendingOperationType
    var retryCount: Int
    let createdAt: Date

    static let maxRetries = 5
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init(operation: PendingOperationType) {
        self.operation = operation
        self.retryCount = 0
        self.createdAt = Date()
    }
}

// MARK: - OfflineSyncService

/// Monitors network connectivity transitions and automatically syncs data
/// when the device comes back online. Replays pending operations first,
/// then refreshes conversations and context profile.
///
/// Designed for Story 7-4 extension: `performSync()` is a clean sequence
/// where conflict resolution checks can be inserted.
@MainActor
@Observable
final class OfflineSyncService {
    // MARK: - Singleton

    static let shared = OfflineSyncService()

    // MARK: - Observable State

    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    // MARK: - Private State

    private var wasConnected: Bool
    private let taskLock = OSAllocatedUnfairLock<(sync: Task<Void, Never>?, observation: Task<Void, Never>?)>(initialState: (nil, nil))
    private let networkMonitor: NetworkMonitor
    private let conflictResolver: SyncConflictResolver

    private static let pendingOpsKey = "com.coachme.pendingOperations"

    // MARK: - Initialization

    init(networkMonitor: NetworkMonitor = .shared, conflictResolver: SyncConflictResolver = SyncConflictResolver()) {
        self.networkMonitor = networkMonitor
        self.conflictResolver = conflictResolver
        self.wasConnected = networkMonitor.isConnected
        startObserving()
    }

    deinit {
        taskLock.withLock { tasks in
            tasks.observation?.cancel()
            tasks.sync?.cancel()
        }
    }

    // MARK: - Observation

    private func startObserving() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // Check for transition since last iteration (catches changes
                // that occurred before observation tracking was registered)
                let nowConnected = self.networkMonitor.isConnected
                if nowConnected && !self.wasConnected {
                    self.triggerSync()
                }
                self.wasConnected = nowConnected
                // Suspend until networkMonitor.isConnected changes
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.networkMonitor.isConnected
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
        taskLock.withLock { $0.observation = task }
    }

    // MARK: - Sync Trigger

    func triggerSync() {
        let task = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s debounce
            guard !Task.isCancelled else { return }
            await performSync()
        }
        taskLock.withLock {
            $0.sync?.cancel()
            $0.sync = task
        }
    }

    // MARK: - Sync Execution

    func performSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncedAt = Date()
        }

        // 1. Replay pending operations first (before refreshing data)
        await replayPendingOperations()

        // 2. Sync conversations with conflict resolution (server always wins)
        await syncConversationsWithConflictResolution()

        // 3. Sync context profile with conflict resolution (most recent wins)
        if let userId = AuthService.shared.currentUser?.id {
            await syncContextProfileWithConflictResolution(userId)
        }

        // 4. Notify ViewModels
        NotificationCenter.default.post(name: .offlineSyncCompleted, object: nil)

        #if DEBUG
        print("OfflineSyncService: Sync completed at \(Date())")
        #endif
    }

    // MARK: - Pending Operations

    var pendingOperations: [PendingOperation] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.pendingOpsKey),
                  let ops = try? JSONDecoder().decode([PendingOperation].self, from: data)
            else { return [] }
            return ops
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                #if DEBUG
                print("OfflineSyncService: Failed to encode pending operations — keeping existing data")
                #endif
                return
            }
            UserDefaults.standard.set(data, forKey: Self.pendingOpsKey)
        }
    }

    func queueOperation(_ op: PendingOperationType) {
        var ops = pendingOperations
        // Remove previous operations of the same type (only latest matters)
        switch op {
        case .updateContextProfile:
            ops.removeAll { if case .updateContextProfile = $0.operation { return true } else { return false } }
        }
        ops.append(PendingOperation(operation: op))
        pendingOperations = ops
    }

    private func replayPendingOperations() async {
        let ops = pendingOperations
        guard !ops.isEmpty else { return }

        var remaining: [PendingOperation] = []

        for var op in ops {
            // Drop stale operations
            if Date().timeIntervalSince(op.createdAt) > PendingOperation.maxAge {
                #if DEBUG
                print("OfflineSyncService: Dropping stale operation created at \(op.createdAt)")
                #endif
                continue
            }
            do {
                switch op.operation {
                case .updateContextProfile(let profile):
                    try await ContextRepository.shared.updateProfile(profile)
                }
            } catch {
                op.retryCount += 1
                if op.retryCount < PendingOperation.maxRetries {
                    remaining.append(op)
                } else {
                    #if DEBUG
                    print("OfflineSyncService: Dropping operation after \(PendingOperation.maxRetries) retries: \(error.localizedDescription)")
                    #endif
                }
            }
        }

        pendingOperations = remaining
    }

    // MARK: - Conflict-Aware Sync (Story 7.4)

    private func syncConversationsWithConflictResolution() async {
        do {
            let remoteConversations = try await ConversationService.shared.fetchConversations()
            let localConversations = OfflineCacheService.shared.getCachedConversations()
            let grouped = Dictionary(grouping: localConversations, by: \.remoteId)
            for (remoteId, entries) in grouped where entries.count > 1 {
                #if DEBUG
                assertionFailure("OfflineSyncService: Duplicate cached conversations for remoteId \(remoteId) — count: \(entries.count)")
                #else
                print("OfflineSyncService: Warning — duplicate cached conversations for remoteId \(remoteId), count: \(entries.count)")
                #endif
            }
            let localByRemoteId = grouped.compactMapValues { entries in
                entries.max(by: { $0.updatedAt < $1.updatedAt })
            }
            var resolvedConversationIds: [UUID] = []
            let context = AppEnvironment.shared.modelContext

            for remote in remoteConversations {
                if let local = localByRemoteId[remote.id] {
                    let result = conflictResolver.resolveConversationConflict(local: local, remote: remote)
                    switch result.resolution {
                    case .serverWins:
                        local.update(from: remote)
                        local.syncStatus = "synced"
                        resolvedConversationIds.append(remote.id)
                    case .noConflict:
                        local.syncStatus = "synced"
                    case .localWins:
                        break
                    }
                } else {
                    // New remote conversation — insert directly, save once at end
                    let cached = CachedConversation(from: remote)
                    context.insert(cached)
                }
            }

            // Single save for all modifications and inserts
            try context.save()

            // Sync messages for conversations with resolved conflicts (AC #1: server always wins)
            for conversationId in resolvedConversationIds {
                await syncMessagesWithConflictResolution(conversationId)
            }
        } catch {
            #if DEBUG
            print("OfflineSyncService: Conversation sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func syncContextProfileWithConflictResolution(_ userId: UUID) async {
        do {
            // Fetch remote profile directly from Supabase — bypasses ContextRepository.fetchProfile()
            // because that method auto-caches, and we need to compare BEFORE updating the cache.
            let remoteProfiles: [ContextProfile] = try await AppEnvironment.shared.supabase
                .from("context_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = remoteProfiles.first else { return }

            // Get local cached profile (direct ModelContext access needed for CachedContextProfile metadata)
            let descriptor = FetchDescriptor<CachedContextProfile>()
            let cached = try AppEnvironment.shared.modelContext.fetch(descriptor)
            guard let local = cached.first(where: { $0.userId == userId }) else {
                // No local cache — just cache the remote
                try await ContextRepository.shared.updateLocalCache(remote)
                return
            }

            let result = conflictResolver.resolveContextProfileConflict(local: local, remote: remote)
            switch result.resolution {
            case .serverWins:
                try local.updateWith(remote)
                local.localUpdatedAt = nil
                local.syncStatus = "synced"
                try AppEnvironment.shared.modelContext.save()
            case .localWins:
                // Push local to server — only clear local state on confirmed success
                if let decoded = local.decodeProfile() {
                    do {
                        try await AppEnvironment.shared.supabase
                            .from("context_profiles")
                            .update(decoded)
                            .eq("id", value: remote.id.uuidString)
                            .execute()
                        local.localUpdatedAt = nil
                        local.syncStatus = "synced"
                        try AppEnvironment.shared.modelContext.save()
                    } catch {
                        #if DEBUG
                        print("OfflineSyncService: Local-wins push failed, keeping local changes: \(error.localizedDescription)")
                        #endif
                    }
                }
            case .noConflict:
                local.syncStatus = "synced"
                try AppEnvironment.shared.modelContext.save()
            }
        } catch {
            #if DEBUG
            print("OfflineSyncService: Context profile sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Message Sync (Story 7.4 — AC #1: server always wins)

    private func syncMessagesWithConflictResolution(_ conversationId: UUID) async {
        do {
            let remoteMessages: [ChatMessage] = try await AppEnvironment.shared.supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            let localMessages = OfflineCacheService.shared.getCachedMessages(conversationId: conversationId)
            let groupedMsgs = Dictionary(grouping: localMessages, by: \.remoteId)
            for (remoteId, entries) in groupedMsgs where entries.count > 1 {
                #if DEBUG
                assertionFailure("OfflineSyncService: Duplicate cached messages for remoteId \(remoteId) — count: \(entries.count)")
                #else
                print("OfflineSyncService: Warning — duplicate cached messages for remoteId \(remoteId), count: \(entries.count)")
                #endif
            }
            let localByRemoteId = groupedMsgs.compactMapValues { entries in
                entries.max(by: { $0.createdAt < $1.createdAt })
            }
            let context = AppEnvironment.shared.modelContext

            for remote in remoteMessages {
                if let local = localByRemoteId[remote.id] {
                    // Detect and log conflicts (AC #3) — server always wins for messages
                    let result = conflictResolver.resolveMessageConflict(local: local, remote: remote)
                    if case .serverWins = result.resolution {
                        local.update(from: remote)
                        local.syncStatus = "synced"
                    }
                } else {
                    // New remote message — insert directly, save once at end
                    let cached = CachedMessage(from: remote)
                    context.insert(cached)
                }
            }

            // Single save for all modifications and inserts
            try context.save()
        } catch {
            #if DEBUG
            print("OfflineSyncService: Message sync failed for conversation \(conversationId): \(error.localizedDescription)")
            #endif
        }
    }

}
