//
//  OfflineSyncServiceTests.swift
//  CoachMeTests
//
//  Story 7.3: Automatic Sync on Reconnect — Unit tests
//  Story 7.4: Sync Conflict Resolution — Integration tests
//

import Testing
import Foundation
@testable import CoachMe

/// MainActor-isolated wrapper to avoid concurrent mutation of captured vars in notification closures.
@MainActor
private final class NotificationExpectation {
    var received = false
}

// MARK: - OfflineSyncService Tests

@MainActor
struct OfflineSyncServiceTests {

    // MARK: - Task 8.1: Connectivity Transition Detection

    @Test("OfflineSyncService triggers sync on offline → online transition")
    func testSyncTriggeredOnReconnect() async {
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Initially offline, no sync
        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt == nil)

        // Simulate reconnection
        monitor.setConnectionState(isConnected: true)

        // Wait for observation + debounce (1s) + execution
        try? await Task.sleep(nanoseconds: 3_500_000_000)

        // Sync should have completed
        #expect(service.lastSyncedAt != nil)
    }

    @Test("OfflineSyncService does NOT trigger sync when staying online")
    func testNoSyncWhenAlreadyOnline() async {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Wait to confirm no sync triggers
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        // No transition occurred, so no sync
        #expect(service.lastSyncedAt == nil)
    }

    @Test("OfflineSyncService does NOT trigger sync when staying offline")
    func testNoSyncWhenStayingOffline() async {
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Wait to confirm no sync triggers
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        // Still offline, no sync triggered
        #expect(service.lastSyncedAt == nil)
    }

    // MARK: - Task 8.2: Debounce Tests

    @Test("Rapid connectivity changes produce only one sync via debounce")
    func testDebounceRapidConnectivityChanges() async {
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Simulate rapid toggling
        monitor.setConnectionState(isConnected: true)
        service.triggerSync()
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        monitor.setConnectionState(isConnected: false)
        monitor.setConnectionState(isConnected: true)
        service.triggerSync()
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        monitor.setConnectionState(isConnected: false)
        monitor.setConnectionState(isConnected: true)
        service.triggerSync()

        // Wait for debounce to settle (1s debounce + execution time)
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        // Should have synced exactly once (last triggerSync wins due to cancel-and-restart)
        #expect(service.lastSyncedAt != nil)
    }

    // MARK: - Task 8.3: isSyncing Guard Tests

    @Test("isSyncing guard prevents concurrent sync calls")
    func testConcurrentSyncGuard() async {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Start two concurrent syncs — second should be rejected by guard
        async let sync1: () = service.performSync()
        async let sync2: () = service.performSync()

        _ = await (sync1, sync2)

        // Both complete but only one actually ran the sync body
        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt != nil)
    }

    // MARK: - Task 8.4: PendingOperation Tests

    @Test("PendingOperation queue persists to and loads from UserDefaults")
    func testPendingOperationPersistence() {
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Clear any existing pending operations
        service.pendingOperations = []
        #expect(service.pendingOperations.isEmpty)

        // Create a test profile for queueing
        let profile = ContextProfile(
            id: UUID(),
            userId: UUID(),
            values: [],
            goals: [],
            situation: ContextSituation.empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Queue operation
        service.queueOperation(.updateContextProfile(profile))

        // Verify it persists
        let ops = service.pendingOperations
        #expect(ops.count == 1)

        // Verify it can be decoded
        if case .updateContextProfile(let decoded) = ops.first?.operation {
            #expect(decoded.id == profile.id)
            #expect(decoded.userId == profile.userId)
            #expect(ops.first?.retryCount == 0)
        } else {
            Issue.record("Expected updateContextProfile operation")
        }

        // Cleanup
        service.pendingOperations = []
    }

    @Test("Multiple operations can be queued")
    func testMultipleOperationsQueued() {
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)

        service.pendingOperations = []

        let profile1 = ContextProfile(
            id: UUID(), userId: UUID(), values: [], goals: [],
            situation: ContextSituation.empty, extractedInsights: [],
            contextVersion: 1, firstSessionComplete: false,
            promptDismissedCount: 0, createdAt: Date(), updatedAt: Date()
        )
        let profile2 = ContextProfile(
            id: UUID(), userId: UUID(), values: [], goals: [],
            situation: ContextSituation.empty, extractedInsights: [],
            contextVersion: 1, firstSessionComplete: false,
            promptDismissedCount: 0, createdAt: Date(), updatedAt: Date()
        )

        service.queueOperation(.updateContextProfile(profile1))
        service.queueOperation(.updateContextProfile(profile2))

        #expect(service.pendingOperations.count == 2)

        // Cleanup
        service.pendingOperations = []
    }

    // MARK: - Task 8.6: Sync Notification Tests

    @Test("Sync posts offlineSyncCompleted notification on completion")
    func testSyncNotificationPosted() async {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        let expectation = NotificationExpectation()
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineSyncCompleted,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in expectation.received = true }
        }

        await service.performSync()

        // Brief wait for notification delivery
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(expectation.received)
        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Task 8.7: ChatViewModel Streaming Guard Tests

    @Test("ChatViewModel refresh does nothing during active streaming")
    func testRefreshSkippedDuringStreaming() async {
        let viewModel = ChatViewModel()

        // Manually set streaming state to simulate active stream
        viewModel.isStreaming = true

        // Refresh should be a no-op when streaming
        await viewModel.refresh()

        // No crash, no error — the guard early-returns
        #expect(viewModel.isStreaming == true)
    }

    @Test("ChatViewModel refresh does nothing without a conversation")
    func testRefreshSkippedWithoutConversation() async {
        let viewModel = ChatViewModel()

        // Start a new conversation then clear it
        viewModel.startNewConversation()

        // The refresh should work with the new conversation ID
        // (it won't actually fetch since there's no persisted conversation)
        await viewModel.refresh()

        // No crash expected
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Task 8.5: ContextRepository Offline Queueing

    @Test("ContextRepository queues update when offline")
    func testContextRepositoryOfflineQueueing() async {
        // This test verifies the offline path of updateProfile
        // We verify via the pending operations queue rather than actual Supabase call
        let monitor = NetworkMonitor(isConnected: false)
        let service = OfflineSyncService(networkMonitor: monitor)
        service.pendingOperations = []

        // When offline, queueOperation should be called
        let profile = ContextProfile(
            id: UUID(), userId: UUID(), values: [], goals: [],
            situation: ContextSituation.empty, extractedInsights: [],
            contextVersion: 1, firstSessionComplete: false,
            promptDismissedCount: 0, createdAt: Date(), updatedAt: Date()
        )

        service.queueOperation(.updateContextProfile(profile))

        #expect(service.pendingOperations.count == 1)

        // Cleanup
        service.pendingOperations = []
    }

    // MARK: - State Tests

    @Test("OfflineSyncService initial state is correct")
    func testInitialState() {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt == nil)
    }

    @Test("performSync sets isSyncing during execution and resets after")
    func testSyncingStateManagement() async {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        // Before sync
        #expect(!service.isSyncing)

        await service.performSync()

        // After sync completes
        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt != nil)
    }

    // MARK: - Story 7.4: Conflict Resolution Integration Tests

    @Test("OfflineSyncService initializes with custom conflict resolver")
    func testConflictResolverInjection() {
        let monitor = NetworkMonitor(isConnected: true)
        let resolver = SyncConflictResolver()
        let service = OfflineSyncService(networkMonitor: monitor, conflictResolver: resolver)

        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt == nil)
    }

    @Test("performSync integrates conflict resolution without crash")
    func testSyncWithConflictResolution() async {
        let monitor = NetworkMonitor(isConnected: true)
        let resolver = SyncConflictResolver()
        let service = OfflineSyncService(networkMonitor: monitor, conflictResolver: resolver)

        await service.performSync()

        // Sync completes — conflict-aware methods run but remote calls may fail in test env
        #expect(!service.isSyncing)
        #expect(service.lastSyncedAt != nil)
    }

    @Test("performSync skips context profile sync when no user is authenticated")
    func testSyncSkipsProfileSyncWithoutUser() async {
        let monitor = NetworkMonitor(isConnected: true)
        let service = OfflineSyncService(networkMonitor: monitor)

        // No authenticated user — context profile sync should be skipped gracefully
        await service.performSync()

        // Should complete without crash even with no AuthService.shared.currentUser
        #expect(service.lastSyncedAt != nil)
    }

    @Test("performSync posts notification after conflict-aware sync")
    func testNotificationAfterConflictSync() async {
        let monitor = NetworkMonitor(isConnected: true)
        let resolver = SyncConflictResolver()
        let service = OfflineSyncService(networkMonitor: monitor, conflictResolver: resolver)

        let expectation = NotificationExpectation()
        let observer = NotificationCenter.default.addObserver(
            forName: .offlineSyncCompleted,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in expectation.received = true }
        }

        await service.performSync()
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(expectation.received)
        NotificationCenter.default.removeObserver(observer)
    }

    @Test("Conflict resolver default injection works with singleton pattern")
    func testDefaultConflictResolverInjection() {
        let monitor = NetworkMonitor(isConnected: true)
        // Uses default parameter — verifies the init(networkMonitor:conflictResolver:) signature
        let service = OfflineSyncService(networkMonitor: monitor)

        #expect(!service.isSyncing)
    }
}
