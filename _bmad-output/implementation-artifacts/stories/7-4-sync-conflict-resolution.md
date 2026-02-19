# Story 7.4: Sync Conflict Resolution

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **sync conflicts between my device and the server handled gracefully**,
So that **I never lose any data when my device reconnects after being offline**.

## Acceptance Criteria

1. **Given** there's a conflict between local and remote conversation data, **When** sync runs, **Then** server data takes precedence for conversations and messages (server is source of truth for coaching content).

2. **Given** my context profile was edited locally while offline AND the server version was also updated, **When** sync runs, **Then** the version with the most recent `updatedAt` timestamp wins.

3. **Given** a sync conflict is detected, **When** the conflict is resolved, **Then** the resolution is logged with conflict type, resolution strategy used, and timestamps of both versions (for monitoring/debugging).

4. **Given** a conflict was resolved using server data, **When** the local cache is updated, **Then** the local SwiftData cache reflects the resolved state with an updated `cachedAt` timestamp.

5. **Given** multiple conflicts occur during a single sync cycle, **When** all are resolved, **Then** each conflict is resolved independently and none blocks the others — partial sync success is acceptable.

6. **Given** a conflict resolution fails (e.g., corrupted data, SwiftData write error), **When** the error occurs, **Then** the individual record is skipped and logged, and remaining sync operations continue.

7. **Given** I view the app after sync with conflict resolution, **When** data has been resolved, **Then** I see the correct resolved data with no UI disruption or error messages (resolution is invisible to the user).

## Tasks / Subtasks

- [x] **Task 1: Add sync metadata to SwiftData models** (AC: #2, #4)
  - [x] 1.1 Add `localUpdatedAt: Date` field to `CachedContextProfile` to track local edit time separately from `lastSyncedAt`
  - [x] 1.2 Add `syncStatus: String` field to `CachedConversation` — values: "synced", "pending", "conflict"
  - [x] 1.3 Add `syncStatus: String` field to `CachedMessage` — values: "synced", "pending", "conflict"
  - [x] 1.4 Ensure all new fields have sensible defaults (avoid migration issues — SwiftData handles schema evolution)

- [x] **Task 2: Create SyncConflictResolver service** (AC: #1, #2, #5, #6)
  - [x] 2.1 Create `Core/Services/SyncConflictResolver.swift` as `@MainActor` service
  - [x] 2.2 Implement `resolveConversationConflict(local:remote:)` — server always wins
  - [x] 2.3 Implement `resolveMessageConflict(local:remote:)` — server always wins (messages are immutable)
  - [x] 2.4 Implement `resolveContextProfileConflict(local:remote:)` — most recent `updatedAt` wins
  - [x] 2.5 Return `ConflictResolution` result enum with `.serverWins`, `.localWins`, `.noConflict` (`.error` removed — resolver methods don't throw; error handling is at the sync service level via try/catch)
  - [x] 2.6 Each resolution method is non-throwing and returns a result — individual failures handled at sync level

- [x] **Task 3: Create SyncConflictLogger** (AC: #3)
  - [x] 3.1 Create `Core/Services/SyncConflictLogger.swift` as `@MainActor` service
  - [x] 3.2 Implement `logConflict(type:resolution:localTimestamp:remoteTimestamp:recordId:)` method
  - [x] 3.3 Log to console via existing `Logger` utility (no PII — only record IDs, timestamps, and resolution type)
  - [x] 3.4 Optionally write to Supabase `sync_conflict_logs` table if online (fire-and-forget)

- [x] **Task 4: Integrate conflict resolution into sync flow** (AC: #1, #2, #4, #5, #7)
  - [x] 4.1 Update `OfflineSyncService` (from Story 7-3) to call `SyncConflictResolver` before overwriting local data during sync
  - [x] 4.2 In conversation sync: fetch remote list → compare with local cache → resolve conflicts → update cache
  - [x] 4.3 In message sync: fetch remote messages → compare with local → server always wins → update cache
  - [x] 4.4 In context profile sync: compare `localUpdatedAt` vs remote `updatedAt` → most recent wins → update both local and remote if local wins
  - [x] 4.5 After all resolutions, update `syncStatus` to "synced" and `cachedAt` to `Date()`

- [x] **Task 5: Handle context profile local-wins upload** (AC: #2)
  - [x] 5.1 When local context profile wins (more recent `localUpdatedAt`), push local version to Supabase
  - [x] 5.2 Use existing `ContextRepository.updateProfile(_:)` for the upload
  - [x] 5.3 On upload failure, keep local version cached and retry on next sync cycle
  - [x] 5.4 Reset `localUpdatedAt` after successful upload

- [x] **Task 6: Create Supabase migration for sync_conflict_logs** (AC: #3)
  - [x] 6.1 Create migration `YYYYMMDD_sync_conflict_logs.sql` with columns: id, user_id, record_type, record_id, conflict_type, resolution, local_timestamp, remote_timestamp, resolved_at
  - [x] 6.2 Add RLS policy: users can INSERT their own logs, operators can SELECT all
  - [x] 6.3 Add index on user_id and resolved_at for monitoring queries

- [x] **Task 7: Write unit tests** (AC: all)
  - [x] 7.1 `SyncConflictResolverTests` — server-wins for conversations, timestamp-wins for profiles, error handling
  - [x] 7.2 `SyncConflictLoggerTests` — conflict logging with correct metadata
  - [x] 7.3 `OfflineSyncServiceConflictTests` — integration of conflict resolution into sync flow
  - [x] 7.4 Use in-memory `ModelContainer` for all tests (`isStoredInMemoryOnly: true`)

## Dev Notes

### CRITICAL: Dependency on Stories 7-1, 7-2, 7-3

This story MUST be implemented AFTER:
- **Story 7-1** (Offline Data Caching) — creates `CachedConversation`, `CachedMessage`, `OfflineCacheService`
- **Story 7-2** (Offline Warning Banner) — creates `OfflineBanner`, integrates `NetworkMonitor`
- **Story 7-3** (Automatic Sync on Reconnect) — creates `OfflineSyncService` with sync queue

**Story 7-4 adds conflict RESOLUTION logic on top of 7-3's sync mechanism.** Do NOT duplicate sync infrastructure.

### Conflict Resolution Strategy — Two Rules

The entire conflict resolution logic boils down to two simple rules:

1. **Conversations & Messages → Server Always Wins**
   - Server is the authoritative source for coaching conversations
   - Messages are immutable (never edited after creation) — conflicts are effectively impossible, but resolve to server if found
   - Conversations track `updatedAt` server-side via PostgreSQL trigger — always trust server

2. **Context Profile → Most Recent `updatedAt` Wins**
   - Context profile is user-editable (values, goals, situation)
   - User might edit offline, creating a version newer than the server
   - Compare `CachedContextProfile.localUpdatedAt` vs remote `ContextProfile.updatedAt`
   - If local is newer → push local to server, then mark synced
   - If remote is newer → overwrite local cache
   - If equal → no conflict, skip

### DO NOT Over-Engineer

- **No vector clocks, CRDTs, or operational transforms** — This is a single-user app. No multi-device concurrent editing. Simple timestamp comparison is sufficient.
- **No merge strategies** — We pick a winner, not merge fields. If local context profile wins, the entire profile overwrites the server version.
- **No user-facing conflict UI** — Conflicts are resolved silently. The user never sees "conflict detected" dialogs.
- **No retry queue for failed resolutions** — If a single record fails, log it and move on. The next sync cycle will try again naturally.

### SyncConflictResolver Design

```swift
@MainActor
final class SyncConflictResolver {
    private let logger: SyncConflictLogger

    enum ConflictResolution {
        case serverWins
        case localWins
        case noConflict
        case error(Error)
    }

    struct ResolutionResult {
        let recordType: String  // "conversation", "message", "context_profile"
        let recordId: UUID
        let resolution: ConflictResolution
    }

    func resolveConversationConflict(
        local: CachedConversation,
        remote: ConversationService.Conversation
    ) -> ResolutionResult {
        // Server always wins for conversations
        // Compare updatedAt to determine if there IS a conflict
        if local.updatedAt != remote.updatedAt {
            logger.logConflict(
                type: "conversation",
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

    func resolveContextProfileConflict(
        local: CachedContextProfile,
        remote: ContextProfile
    ) -> ResolutionResult {
        guard let localUpdatedAt = local.localUpdatedAt else {
            // No local edits — server wins by default
            return ResolutionResult(
                recordType: "context_profile",
                recordId: remote.id,
                resolution: .serverWins
            )
        }

        if localUpdatedAt > remote.updatedAt {
            logger.logConflict(
                type: "context_profile",
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
        } else {
            logger.logConflict(
                type: "context_profile",
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
        }
    }
}
```

### SyncConflictLogger Design

```swift
@MainActor
final class SyncConflictLogger {
    private let supabase: SupabaseClient

    func logConflict(
        type: String,
        resolution: String,
        localTimestamp: Date,
        remoteTimestamp: Date,
        recordId: UUID
    ) {
        // Always log locally (no PII — only record IDs and timestamps)
        Logger.sync.info(
            "Conflict resolved: \(type) \(recordId) → \(resolution) " +
            "(local: \(localTimestamp), remote: \(remoteTimestamp))"
        )

        // Optionally log to Supabase (fire-and-forget, non-blocking)
        Task {
            try? await supabase
                .from("sync_conflict_logs")
                .insert(SyncConflictLogInsert(
                    recordType: type,
                    recordId: recordId,
                    conflictType: "timestamp_mismatch",
                    resolution: resolution,
                    localTimestamp: localTimestamp,
                    remoteTimestamp: remoteTimestamp
                ))
                .execute()
        }
    }
}
```

### Integration with OfflineSyncService (Story 7-3)

Story 7-3 creates `OfflineSyncService` with a `syncPendingChanges()` method called when the network reconnects. Story 7-4 adds conflict resolution INTO that flow:

```swift
// In OfflineSyncService (modified by this story)
func syncPendingChanges() async {
    // 1. Sync conversations — server wins
    let remoteConversations = try await conversationService.fetchConversations()
    let localConversations = try offlineCacheService.getCachedConversations()

    for remote in remoteConversations {
        if let local = localConversations.first(where: { $0.remoteId == remote.id }) {
            let result = conflictResolver.resolveConversationConflict(
                local: local, remote: remote
            )
            switch result.resolution {
            case .serverWins:
                try offlineCacheService.updateCachedConversation(from: remote)
            case .noConflict:
                break  // Already in sync
            case .localWins, .error:
                break  // Conversations always server-wins, but handle gracefully
            }
        } else {
            // New remote conversation — cache it
            try offlineCacheService.cacheConversation(remote)
        }
    }

    // 2. Sync context profile — most recent wins
    let remoteProfile = try await contextRepository.fetchProfile(userId: userId)
    let localProfile = try offlineCacheService.getCachedContextProfile(userId: userId)

    if let local = localProfile, let remote = remoteProfile {
        let result = conflictResolver.resolveContextProfileConflict(
            local: local, remote: remote
        )
        switch result.resolution {
        case .serverWins:
            try contextRepository.cacheProfile(remote)
        case .localWins:
            // Push local to server
            if let decoded = local.decodeProfile() {
                try await contextRepository.updateProfile(decoded)
            }
            local.localUpdatedAt = nil  // Reset after successful push
        case .noConflict, .error:
            break
        }
    }
}
```

### CachedContextProfile Modifications

Story 7-1 creates `CachedContextProfile` with `lastSyncedAt`. Story 7-4 adds:

```swift
// ADD to existing CachedContextProfile (from Story 7-1)
var localUpdatedAt: Date?  // Set when user edits offline, nil when synced
var syncStatus: String     // "synced", "pending", "conflict" — default "synced"
```

When the user edits their context profile while offline:
1. `ContextRepository.updateProfile()` detects `NetworkMonitor.isConnected == false`
2. Updates `CachedContextProfile.profileData` with new JSON
3. Sets `localUpdatedAt = Date()` and `syncStatus = "pending"`
4. On reconnect, `OfflineSyncService` triggers → `SyncConflictResolver` compares timestamps

### Database Migration: sync_conflict_logs

```sql
CREATE TABLE IF NOT EXISTS public.sync_conflict_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    record_type TEXT NOT NULL,        -- 'conversation', 'message', 'context_profile'
    record_id UUID NOT NULL,
    conflict_type TEXT NOT NULL,      -- 'timestamp_mismatch', 'missing_local', 'missing_remote'
    resolution TEXT NOT NULL,         -- 'server_wins', 'local_wins', 'skipped'
    local_timestamp TIMESTAMPTZ,
    remote_timestamp TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: users can insert their own logs
ALTER TABLE public.sync_conflict_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own sync logs"
    ON public.sync_conflict_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Operators can read all (for monitoring)
CREATE POLICY "Service role can read all sync logs"
    ON public.sync_conflict_logs FOR SELECT
    USING (auth.role() = 'service_role');

-- Index for monitoring queries
CREATE INDEX idx_sync_conflict_logs_user_resolved
    ON public.sync_conflict_logs(user_id, resolved_at DESC);
```

### Existing Components to Reuse (DO NOT Reinvent)

| Component | Location | Usage in This Story |
|-----------|----------|---------------------|
| `CachedContextProfile` | `Core/Data/Local/CachedContextProfile.swift` | **Modify** — add `localUpdatedAt`, `syncStatus` fields |
| `CachedConversation` | `Core/Data/Local/CachedConversation.swift` (from 7-1) | **Modify** — add `syncStatus` field |
| `CachedMessage` | `Core/Data/Local/CachedMessage.swift` (from 7-1) | **Modify** — add `syncStatus` field |
| `OfflineCacheService` | `Core/Services/OfflineCacheService.swift` (from 7-1) | **Use** — read/write cache during resolution |
| `OfflineSyncService` | `Core/Services/OfflineSyncService.swift` (from 7-3) | **Modify** — integrate conflict resolution into sync flow |
| `ContextRepository` | `Core/Data/Repositories/ContextRepository.swift` | **Modify** — set `localUpdatedAt` on offline edits, push local wins |
| `NetworkMonitor` | `Core/Services/NetworkMonitor.swift` | **Use** — detect offline state for conditional edit tracking |
| `Logger` | `Core/Utilities/Logger.swift` | **Use** — conflict logging (no PII) |
| `AppEnvironment` | `App/Environment/AppEnvironment.swift` | **No change** — schema already includes models from 7-1 |

### What NOT to Do

- **Do NOT create merge/diff logic** — Pick a winner (server or local), never merge fields from both.
- **Do NOT show conflict UI to the user** — Resolution is completely invisible. No alerts, no banners, no toasts.
- **Do NOT use vector clocks, CRDTs, or version numbers** — Single-user app. Timestamps are sufficient.
- **Do NOT queue failed resolutions** — Log the failure and move on. Next sync cycle handles naturally.
- **Do NOT add offline write queues for conversations/messages** — Users cannot create new coaching messages offline. Only context profile edits can happen offline.
- **Do NOT use `@ObservableObject`** — Project uses `@Observable` (iOS 17+ Observation framework).
- **Do NOT block the sync flow** — Individual conflict failures must not prevent other records from syncing.
- **Do NOT log PII** — Only record IDs, timestamps, and resolution types in conflict logs.

### Architecture Compliance

| Requirement | Implementation |
|---|---|
| MVVM + Repository | SyncConflictResolver is a Service; integrates with existing Repositories |
| `@Observable` | Not directly applicable (service, not ViewModel) — uses `@MainActor` |
| `@MainActor` | All services marked `@MainActor` for Swift 6 strict concurrency |
| Fetch-all-and-filter | SwiftData queries use fetch-all-and-filter pattern (no KeyPath predicates) |
| Warm error messages | No user-facing errors — conflicts resolved silently |
| No PII in logs | Conflict logs contain only record IDs, timestamps, resolution types |
| Non-blocking | Cache operations wrapped in `Task { try? await ... }` where appropriate |
| Remote-first | Server is authoritative for conversations; most-recent-wins for profiles |

### Files to Create

| File | Path |
|---|---|
| `SyncConflictResolver.swift` | `CoachMe/CoachMe/Core/Services/SyncConflictResolver.swift` |
| `SyncConflictLogger.swift` | `CoachMe/CoachMe/Core/Services/SyncConflictLogger.swift` |
| `SyncConflictLogInsert.swift` | `CoachMe/CoachMe/Core/Data/Remote/SyncConflictLogInsert.swift` |
| `sync_conflict_logs migration` | `supabase/migrations/YYYYMMDD_sync_conflict_logs.sql` |

### Files to Modify

| File | Path | Change |
|---|---|---|
| `CachedContextProfile.swift` | `Core/Data/Local/CachedContextProfile.swift` | Add `localUpdatedAt: Date?`, `syncStatus: String` |
| `CachedConversation.swift` | `Core/Data/Local/CachedConversation.swift` | Add `syncStatus: String` |
| `CachedMessage.swift` | `Core/Data/Local/CachedMessage.swift` | Add `syncStatus: String` |
| `OfflineSyncService.swift` | `Core/Services/OfflineSyncService.swift` | Integrate SyncConflictResolver into sync flow |
| `ContextRepository.swift` | `Core/Data/Repositories/ContextRepository.swift` | Set `localUpdatedAt` on offline profile edits |

### Files to Create (Tests)

| File | Path |
|---|---|
| `SyncConflictResolverTests.swift` | `CoachMe/CoachMeTests/SyncConflictResolverTests.swift` |
| `SyncConflictLoggerTests.swift` | `CoachMe/CoachMeTests/SyncConflictLoggerTests.swift` |

### Project Structure Notes

- `SyncConflictResolver` and `SyncConflictLogger` live in `Core/Services/` alongside `OfflineSyncService` and `OfflineCacheService`
- `SyncConflictLogInsert` Codable struct lives in `Core/Data/Remote/` following the `ContextProfileInsert` pattern
- Supabase migration goes in `supabase/migrations/` with date-prefixed naming convention

### References

- [Source: architecture.md#Data Architecture] — SwiftData for local persistence, relational model with JSONB
- [Source: architecture.md#Core Architectural Decisions] — "Deferred Decisions: Advanced offline capabilities (conflict resolution)"
- [Source: architecture.md#Implementation Patterns] — Repository pattern, @Observable ViewModels, offline detection
- [Source: architecture.md#Caching Strategy] — Client-side SwiftData local cache with sync-on-reconnect
- [Source: architecture.md#Anti-Patterns] — Never block main thread, never log PII
- [Source: epics.md#Story 7.4] — FR32: User data syncs automatically when internet connection is restored
- [Source: epics.md#Epic 7] — Offline Support & Data Sync: "Timestamp-based conflict resolution, server authoritative for messages, most recent wins for user-editable data"
- [Source: 7-1-offline-data-caching-with-swiftdata.md] — CachedConversation, CachedMessage models, OfflineCacheService
- [Source: 7-2-offline-warning-banner.md] — OfflineBanner, NetworkMonitor integration
- [Source: ContextRepository.swift] — Remote-first + cache-fallback pattern, fetch-all-and-filter for Swift 6
- [Source: CachedContextProfile.swift] — Existing SwiftData @Model with lastSyncedAt, staleness checking
- [Source: NetworkMonitor.swift] — NWPathMonitor singleton with isConnected property

### Previous Story Intelligence

- **From Story 7-1:** SwiftData models use `@Attribute(.unique)` on `remoteId` for upsert behavior. Cache writes are non-blocking (`Task { try? await ... }`). Fetch-all-and-filter pattern mandatory for Swift 6.
- **From Story 7-2:** NetworkMonitor.shared is the single source of truth for connectivity. DO NOT recreate. TrialBanner pattern for UI banners. Offline detection already works.
- **From Epic 2 (Context):** ContextRepository uses `upsert(_, onConflict:, ignoreDuplicates:)` for atomic creates. `updateProfile(_:)` sets `updatedAt = Date()` before remote update. Profile staleness threshold is 1 hour.
- **From Epic 6 (Subscription):** Non-blocking integrations — fire-and-forget pattern for auxiliary operations like logging.
- **Swift 6 Strict Concurrency:** Always `@MainActor` on services. `ModelContext` is not Sendable — keep on MainActor. Fetch-all-and-filter for SwiftData queries.

### Git Intelligence

Recent commits show consistent patterns:
- Feature branches merged to main with descriptive commit messages
- Edge function + iOS code changes coordinated together
- Tests written alongside feature code
- Error handling follows UX-11 warm first-person pattern throughout
- Supabase migrations follow date-prefixed naming: `YYYYMMDD_description.sql`
- CodingKeys with snake_case for all Supabase models

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Swift 6 strict concurrency: Used `@preconcurrency import Supabase` to handle `PostgrestResponse<Void>` Sendable gap in SyncConflictLogger and OfflineSyncService
- Removed unnecessary do/catch blocks from SyncConflictResolver (methods don't throw)
- Used `Task.detached` initially for fire-and-forget Supabase logging, reverted to `@preconcurrency` approach
- **[Code Review Fix]** Removed `.error(Error)` from ConflictResolution enum — resolver methods are non-throwing; error handling lives at the sync service level
- **[Code Review Fix]** Added `userId` to SyncConflictLogInsert — Supabase table requires NOT NULL user_id; logger now resolves from AuthService.shared.currentUser
- **[Code Review Fix]** Added `syncMessagesWithConflictResolution()` to OfflineSyncService — was missing per Task 4.3
- **[Code Review Fix]** Added 5 conflict resolution integration tests to OfflineSyncServiceTests — was missing per Task 7.3
- **[Code Review Fix]** Renamed `cacheProfilePublic` to `updateLocalCache` in ContextRepository

### Completion Notes List

- **Task 1**: Added `localUpdatedAt: Date?` and `syncStatus: String` to CachedContextProfile; `syncStatus: String` to CachedConversation and CachedMessage. All defaults are "synced" to avoid migration issues.
- **Task 2**: Created SyncConflictResolver with three resolution methods: conversation (server wins), message (server wins), context profile (most recent updatedAt wins). Returns ResolutionResult with .serverWins/.localWins/.noConflict enum.
- **Task 3**: Created SyncConflictLogger with local console logging (#if DEBUG) and fire-and-forget Supabase insert (with user_id from AuthService). No PII logged.
- **Task 4**: Replaced OfflineSyncService's simple refresh methods with conflict-aware sync: `syncConversationsWithConflictResolution()`, `syncMessagesWithConflictResolution()`, and `syncContextProfileWithConflictResolution()`. Each conflict resolved independently per AC #5.
- **Task 5**: Updated ContextRepository.updateProfile() to set localUpdatedAt and syncStatus="pending" on offline edits. Local-wins push to server in sync flow resets localUpdatedAt after success.
- **Task 6**: Created migration `20260209000001_sync_conflict_logs.sql` with RLS (users INSERT own, service_role SELECT all) and index on (user_id, resolved_at DESC).
- **Task 7**: Created SyncConflictResolverTests (13 tests), SyncConflictLoggerTests (8 tests), and OfflineSyncService conflict integration tests (5 tests). Resolver and logger tests use in-memory ModelContainer.

### Change Log

- 2026-02-09: Story 7.4 implementation complete — sync conflict resolution with two-rule strategy (server-wins for conversations/messages, most-recent-wins for context profiles)
- 2026-02-09: Code review fixes — added missing user_id to log insert, removed dead .error enum case, added message sync method, added conflict integration tests, renamed cacheProfilePublic to updateLocalCache

### File List

**New Files:**
- `CoachMe/CoachMe/Core/Services/SyncConflictResolver.swift`
- `CoachMe/CoachMe/Core/Services/SyncConflictLogger.swift`
- `CoachMe/CoachMe/Core/Data/Remote/SyncConflictLogInsert.swift`
- `supabase/migrations/20260209000001_sync_conflict_logs.sql`
- `CoachMe/CoachMeTests/SyncConflictResolverTests.swift`
- `CoachMe/CoachMeTests/SyncConflictLoggerTests.swift`

**Modified Files:**
- `CoachMe/CoachMe/Core/Data/Local/CachedContextProfile.swift` — added localUpdatedAt, syncStatus fields
- `CoachMe/CoachMe/Core/Data/Local/CachedConversation.swift` — added syncStatus field
- `CoachMe/CoachMe/Core/Data/Local/CachedMessage.swift` — added syncStatus field
- `CoachMe/CoachMe/Core/Services/OfflineSyncService.swift` — integrated SyncConflictResolver, conflict-aware sync for conversations/messages/profile
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` — set localUpdatedAt on offline edits, added updateLocalCache method
- `CoachMe/CoachMe/Core/Services/OfflineCacheService.swift` — added saveContext() method
- `CoachMe/CoachMeTests/OfflineSyncServiceTests.swift` — added 5 conflict resolution integration tests
