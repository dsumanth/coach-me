//
//  SyncConflictResolver.swift
//  CoachMe
//
//  Story 7.4: Sync Conflict Resolution
//  Resolves conflicts between local cache and remote data during sync.
//  Two rules: server wins for conversations/messages, most recent updatedAt wins for context profiles.
//

import Foundation

@MainActor
final class SyncConflictResolver {
    private let logger: SyncConflictLogger

    // MARK: - Types

    enum ConflictResolution {
        case serverWins
        case localWins
        case noConflict
    }

    struct ResolutionResult {
        let recordType: String
        let recordId: UUID
        let resolution: ConflictResolution
    }

    // MARK: - Initialization

    init(logger: SyncConflictLogger = SyncConflictLogger()) {
        self.logger = logger
    }

    // MARK: - Conversation Resolution (Server Always Wins)

    func resolveConversationConflict(
        local: CachedConversation,
        remote: ConversationService.Conversation
    ) -> ResolutionResult {
        if local.updatedAt != remote.updatedAt {
            logger.logConflict(
                type: "conversation",
                conflictType: "timestamp_mismatch",
                resolution: "server_wins",
                localTimestamp: local.updatedAt,
                remoteTimestamp: remote.updatedAt,
                recordId: local.remoteId
            )
            return ResolutionResult(
                recordType: "conversation",
                recordId: local.remoteId,
                resolution: .serverWins
            )
        }
        return ResolutionResult(
            recordType: "conversation",
            recordId: local.remoteId,
            resolution: .noConflict
        )
    }

    // MARK: - Message Resolution (Server Always Wins)

    func resolveMessageConflict(
        local: CachedMessage,
        remote: ChatMessage
    ) -> ResolutionResult {
        if local.createdAt != remote.createdAt || local.content != remote.content {
            logger.logConflict(
                type: "message",
                conflictType: "data_mismatch",
                resolution: "server_wins",
                localTimestamp: local.createdAt,
                remoteTimestamp: remote.createdAt,
                recordId: local.remoteId
            )
            return ResolutionResult(
                recordType: "message",
                recordId: local.remoteId,
                resolution: .serverWins
            )
        }
        return ResolutionResult(
            recordType: "message",
            recordId: local.remoteId,
            resolution: .noConflict
        )
    }

    // MARK: - Context Profile Resolution (Most Recent Wins)

    func resolveContextProfileConflict(
        local: CachedContextProfile,
        remote: ContextProfile
    ) -> ResolutionResult {
        guard let localUpdatedAt = local.localUpdatedAt else {
            return ResolutionResult(
                recordType: "context_profile",
                recordId: remote.id,
                resolution: .serverWins
            )
        }

        if localUpdatedAt > remote.updatedAt {
            logger.logConflict(
                type: "context_profile",
                conflictType: "timestamp_mismatch",
                resolution: "local_wins",
                localTimestamp: localUpdatedAt,
                remoteTimestamp: remote.updatedAt,
                recordId: remote.id
            )
            return ResolutionResult(
                recordType: "context_profile",
                recordId: remote.id,
                resolution: .localWins
            )
        } else if localUpdatedAt < remote.updatedAt {
            logger.logConflict(
                type: "context_profile",
                conflictType: "timestamp_mismatch",
                resolution: "server_wins",
                localTimestamp: localUpdatedAt,
                remoteTimestamp: remote.updatedAt,
                recordId: remote.id
            )
            return ResolutionResult(
                recordType: "context_profile",
                recordId: remote.id,
                resolution: .serverWins
            )
        } else {
            return ResolutionResult(
                recordType: "context_profile",
                recordId: remote.id,
                resolution: .noConflict
            )
        }
    }
}
