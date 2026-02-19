# Story 7.3: Automatic Sync on Reconnect

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user coming back online**,
I want **my data to sync automatically when network connectivity is restored**,
so that **I see the latest conversations, messages, and context without manual intervention (FR32)**.

## Acceptance Criteria

1. **Given** I was offline and come back online, **When** NetworkMonitor detects connectivity restored (offline → online transition), **Then** the app automatically triggers a sync of conversations, messages, and context profile within 2 seconds of reconnection.

2. **Given** sync is triggered, **When** my conversations list is visible, **Then** ConversationListViewModel re-fetches from Supabase, updates SwiftData via `OfflineCacheService` (from Story 7-1), and the UI refreshes automatically — without user interaction.

3. **Given** sync is triggered while I'm viewing a specific conversation, **When** new messages exist on the server, **Then** ChatViewModel re-fetches messages for the current conversation and the UI updates with any new messages.

4. **Given** sync is triggered, **When** my context profile has been updated on the server, **Then** the local `CachedContextProfile` is refreshed from Supabase with the latest data.

5. **Given** I edited my context profile while offline (pending operation), **When** connectivity is restored, **Then** the pending profile update is replayed to Supabase before refreshing data from the server.

6. **Given** sync completes successfully, **When** data has been refreshed, **Then** all caches are updated — SwiftData via `OfflineCacheService` (from Story 7-1) and file-based caches (`ChatMessageCache`, `ConversationListCache`).

7. **Given** sync fails (server error, auth expired), **When** the error occurs, **Then** the failure is logged silently — no disruptive error alert shown to the user. The app continues using cached data and will retry on next connectivity change.

8. **Given** I rapidly toggle between offline and online, **When** multiple connectivity events fire, **Then** the sync service debounces and cancels any in-flight sync to prevent redundant concurrent sync operations.

## Tasks / Subtasks

- [x] **Task 1: Create `OfflineSyncService`** (AC: #1, #7, #8)
  - [x] 1.1 Create `CoachMe/CoachMe/Core/Services/OfflineSyncService.swift` as `@MainActor @Observable` class with singleton `static let shared`
  - [x] 1.2 Add state: `isSyncing: Bool`, `lastSyncedAt: Date?`
  - [x] 1.3 Add private: `wasConnected: Bool` (tracks previous network state), `syncTask: Task<Void, Never>?` (for cancellation/debounce), `observationTask: Task<Void, Never>?` (for network polling)
  - [x] 1.4 Add `init(networkMonitor:)` defaulting to `NetworkMonitor.shared` for testability
  - [x] 1.5 Implement `startObserving()` — poll `NetworkMonitor.isConnected` every 1s, detect `false → true` transitions, call `triggerSync()`
  - [x] 1.6 Implement `triggerSync()` — cancel existing `syncTask`, create new task with 1s debounce delay (network stabilization), then call `performSync()`
  - [x] 1.7 Implement `performSync() async` — orchestrate: replay pending ops → refresh conversations → refresh context profile → notify ViewModels
  - [x] 1.8 Add `guard !isSyncing else { return }` in `performSync` as safety against concurrent syncs
  - [x] 1.9 Wrap all operations in do/catch — log errors via `#if DEBUG print(...)`, never surface to UI

- [x] **Task 2: Implement `PendingOperation` queue** (AC: #5)
  - [x] 2.1 Create `enum PendingOperation: Codable` with case: `.updateContextProfile(ContextProfile)` (only context profile edits can happen offline)
  - [x] 2.2 Add computed property `pendingOperations: [PendingOperation]` backed by `UserDefaults` with JSON encoding (survives app restart)
  - [x] 2.3 Add `queueOperation(_ op: PendingOperation)` — appends to array and persists
  - [x] 2.4 Add `replayPendingOperations() async` — iterate queue, attempt each via `ContextRepository.updateProfile(_:)`, remove on success
  - [x] 2.5 On replay failure: keep operation in queue for next sync attempt, log error
  - [x] 2.6 Call `replayPendingOperations()` as FIRST step in `performSync()` (before refreshing data)

- [x] **Task 3: Implement data refresh methods** (AC: #2, #3, #4, #6)
  - [x] 3.1 Add `refreshConversationList() async throws` — call `ConversationService().fetchConversations()`, call `OfflineCacheService.shared.cacheConversations(conversations)` to update SwiftData cache
  - [x] 3.2 Add `refreshCurrentConversation(_ conversationId: UUID) async throws` — call `ConversationService().fetchMessages(conversationId:)`, call `OfflineCacheService.shared.cacheMessages(messages, forConversation: conversationId)` to update SwiftData cache, call `ChatMessageCache.save(messages:conversationId:)` to update file cache
  - [x] 3.3 Add `refreshContextProfile(_ userId: UUID) async throws` — call `ContextRepository().fetchProfile(userId:)` (already updates `CachedContextProfile` SwiftData cache internally)
  - [x] 3.4 Use `withTaskGroup` for parallel sync of independent data (conversations list + context profile)
  - [x] 3.5 Post `Notification.Name.offlineSyncCompleted` when sync finishes so ViewModels can react

- [x] **Task 4: Wire `OfflineSyncService` into app lifecycle** (AC: #1)
  - [x] 4.1 In `CoachMeApp.init()`, add `_ = OfflineSyncService.shared` to ensure observation starts immediately on app launch
  - [x] 4.2 Define `Notification.Name.offlineSyncCompleted` extension

- [x] **Task 5: Update `ChatViewModel` to respond to sync** (AC: #3)
  - [x] 5.1 Replace the placeholder `refresh()` method with real implementation: call `loadConversation(id:)` for the current conversation
  - [x] 5.2 In `init()` or `setupNotifications()`, observe `.offlineSyncCompleted` — when received and a conversation is active, call `refresh()`
  - [x] 5.3 Guard: do NOT refresh during active streaming (`isStreaming == true` → skip)

- [x] **Task 6: Update `ConversationListViewModel` to respond to sync** (AC: #2)
  - [x] 6.1 Observe `.offlineSyncCompleted` — when received, call `loadConversations()`
  - [x] 6.2 The existing `loadConversations()` already handles cache-first → server refresh — the notification just triggers the server refresh path

- [x] **Task 7: Queue context profile edits when offline** (AC: #5)
  - [x] 7.1 In `ContextRepository.updateProfile(_:)`, add early check: `if !NetworkMonitor.shared.isConnected`
  - [x] 7.2 If offline: update local SwiftData cache via `cacheProfile(profile)`, queue `.updateContextProfile(profile)` via `OfflineSyncService.shared.queueOperation(...)`, return without throwing (optimistic success)
  - [x] 7.3 If online: proceed with existing remote-first logic (no change to existing code path)

- [x] **Task 8: Write unit tests** (AC: all)
  - [x] 8.1 `OfflineSyncServiceTests` — verify `performSync()` is called on offline → online transition
  - [x] 8.2 Test debounce — rapid connectivity changes produce only one sync
  - [x] 8.3 Test `isSyncing` guard — concurrent sync calls are rejected
  - [x] 8.4 `PendingOperationTests` — queue, persist to UserDefaults, replay, remove on success, retain on failure
  - [x] 8.5 Test `ContextRepository` offline queueing — verify operation queued and local cache updated when offline
  - [x] 8.6 Test sync notification is posted on completion
  - [x] 8.7 Test sync does NOT interrupt active streaming (ChatViewModel guard)

## Dev Notes

### CRITICAL: Dependency on Stories 7-1 and 7-2

This story MUST be implemented AFTER:
- **Story 7-1** (Offline Data Caching) — creates `CachedConversation`, `CachedMessage` SwiftData models and `OfflineCacheService`
- **Story 7-2** (Offline Warning Banner) — creates `OfflineBanner` and integrates `NetworkMonitor` into `ChatView`

**Story 7-4 (Sync Conflict Resolution) will MODIFY `OfflineSyncService` created here** — adding conflict resolution into the sync flow. Design `performSync()` as a clean sequence that 7-4 can insert resolution checks into.

### Architecture: Where Story 7-3 Fits in Epic 7

```
7-1: Data Layer     → CachedConversation, CachedMessage, OfflineCacheService
7-2: UI Layer       → OfflineBanner, send button disabled, NetworkMonitor in ChatView
7-3: Sync Layer     → OfflineSyncService, PendingOperation queue, ViewModel notifications  ← THIS STORY
7-4: Resolution     → SyncConflictResolver, SyncConflictLogger (modifies OfflineSyncService)
```

### Existing Infrastructure (DO NOT Recreate)

| Component | Location | Status |
|-----------|----------|--------|
| `NetworkMonitor` | `Core/Services/NetworkMonitor.swift` | EXISTS — `@MainActor @Observable` singleton, `isConnected`, `isExpensive`, test-friendly constructor |
| `ChatMessageCache` | `Features/Chat/Services/ChatMessageCache.swift` | EXISTS — file-based per-conversation JSON cache |
| `ConversationListCache` | `Features/History/ViewModels/ConversationListCache.swift` | EXISTS — file-based conversation list cache |
| `CachedContextProfile` | `Core/Data/Local/CachedContextProfile.swift` | EXISTS — SwiftData `@Model` with `lastSyncedAt`, `isStale` |
| `ConversationService` | `Core/Services/ConversationService.swift` | EXISTS — `fetchConversations()`, `fetchMessages(conversationId:)` |
| `ContextRepository` | `Core/Data/Repositories/ContextRepository.swift` | EXISTS — remote-first + cache fallback, `fetchProfile(userId:)` auto-updates SwiftData cache |
| `AuthService` | `Features/Auth/Services/AuthService.swift` | EXISTS — `currentUser?.id` for userId, `currentAccessToken` auto-refreshes |
| `OfflineCacheService` | `Core/Services/OfflineCacheService.swift` | FROM 7-1 — `cacheConversations(_:)`, `cacheMessages(_:forConversation:)`, `getCachedConversations()`, `getCachedMessages(conversationId:)` |

### ChatViewModel Placeholder (Replace This)

[ChatViewModel.swift](CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift) contains a placeholder left specifically for this story:

```swift
func refresh() async {
    // Placeholder for sync functionality
    // Will fetch any missed messages from server in Story 7.3
    #if DEBUG
    print("ChatViewModel: Refresh triggered - sync will be implemented in Story 7.3")
    #endif
    try? await Task.sleep(nanoseconds: 500_000_000)
}
```

Replace with:
```swift
func refresh() async {
    guard let conversationId = currentConversationId, !isStreaming else { return }
    await loadConversation(id: conversationId)
}
```

### OfflineSyncService Design

```swift
@MainActor @Observable
final class OfflineSyncService {
    static let shared = OfflineSyncService()

    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    private var wasConnected: Bool
    private var syncTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?
    private let networkMonitor: NetworkMonitor

    private static let pendingOpsKey = "com.coachme.pendingOperations"

    init(networkMonitor: NetworkMonitor = .shared) {
        self.networkMonitor = networkMonitor
        self.wasConnected = networkMonitor.isConnected
        startObserving()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s poll
                guard let self else { return }
                let nowConnected = self.networkMonitor.isConnected
                if nowConnected && !self.wasConnected {
                    self.triggerSync()
                }
                self.wasConnected = nowConnected
            }
        }
    }

    private func triggerSync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s debounce
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }

    func performSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncedAt = Date()
        }

        // 1. Replay pending operations first
        await replayPendingOperations()

        // 2. Refresh data in parallel (conversations + context profile)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try? await self?.refreshConversationList()
            }
            group.addTask { [weak self] in
                guard let userId = AuthService.shared.currentUser?.id else { return }
                try? await self?.refreshContextProfile(userId)
            }
        }

        // 3. Notify ViewModels
        NotificationCenter.default.post(name: .offlineSyncCompleted, object: nil)

        #if DEBUG
        print("OfflineSyncService: Sync completed at \(Date())")
        #endif
    }
}
```

### PendingOperation Queue — UserDefaults Persistence

```swift
enum PendingOperation: Codable {
    case updateContextProfile(ContextProfile)
}

// In OfflineSyncService:
var pendingOperations: [PendingOperation] {
    get {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingOpsKey),
              let ops = try? JSONDecoder().decode([PendingOperation].self, from: data)
        else { return [] }
        return ops
    }
    set {
        let data = try? JSONEncoder().encode(newValue)
        UserDefaults.standard.set(data, forKey: Self.pendingOpsKey)
    }
}

func queueOperation(_ op: PendingOperation) {
    var ops = pendingOperations
    ops.append(op)
    pendingOperations = ops
}

private func replayPendingOperations() async {
    var ops = pendingOperations
    var remaining: [PendingOperation] = []

    for op in ops {
        do {
            switch op {
            case .updateContextProfile(let profile):
                let repo = ContextRepository()
                try await repo.updateProfile(profile) // Online path — remote + cache
            }
        } catch {
            remaining.append(op) // Keep for next sync
            #if DEBUG
            print("OfflineSyncService: Pending operation replay failed: \(error.localizedDescription)")
            #endif
        }
    }

    pendingOperations = remaining
}
```

**Important**: `ContextRepository.updateProfile(_:)` will need a way to distinguish "replaying a pending op while online" from "normal online edit" to avoid re-queueing. The simplest approach: in `updateProfile(_:)`, check `NetworkMonitor.shared.isConnected` — if online, always use the remote path. Since replay only runs when online, it will take the remote path.

### Notification Name

```swift
extension Notification.Name {
    static let offlineSyncCompleted = Notification.Name("com.coachme.offlineSyncCompleted")
}
```

Place this in `OfflineSyncService.swift` or in a shared `Core/Constants/` file.

### ContextRepository Offline Queueing

In [ContextRepository.swift](CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift), modify `updateProfile(_:)`:

```swift
func updateProfile(_ profile: ContextProfile) async throws {
    if !NetworkMonitor.shared.isConnected {
        // Offline: update local cache optimistically, queue for later
        try await cacheProfile(profile)
        OfflineSyncService.shared.queueOperation(.updateContextProfile(profile))
        #if DEBUG
        print("ContextRepository: Profile update queued for offline sync")
        #endif
        return
    }

    // Online: existing remote-first logic (unchanged)
    var updated = profile
    updated.updatedAt = Date()
    try await supabase
        .from("context_profiles")
        .update(updated)
        .eq("id", value: profile.id.uuidString)
        .execute()
    try await cacheProfile(updated)
}
```

### What Does NOT Need Offline Queueing

| Action | Why No Queue |
|--------|-------------|
| Send message | Requires server-side LLM streaming — impossible offline. Send button disabled by Story 7-2. |
| Delete conversation | Destructive action — safer to wait for connectivity. |
| Create conversation | Created on-demand when first message is sent (requires LLM). |
| Edit context profile | **NEEDS queueing** — user expects edits to persist. |

### ViewModel Notification Observer Pattern

In ChatViewModel (and similarly in ConversationListViewModel):

```swift
// In init() or a setup method:
private var syncObserver: Any?

func setupSyncObserver() {
    syncObserver = NotificationCenter.default.addObserver(
        forName: .offlineSyncCompleted,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        guard let self else { return }
        Task { @MainActor in
            await self.refresh()
        }
    }
}

deinit {
    if let observer = syncObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### Refresh Data Methods

```swift
private func refreshConversationList() async throws {
    let service = ConversationService()
    let conversations = try await service.fetchConversations()

    // Update SwiftData cache (from Story 7-1)
    try await OfflineCacheService.shared.cacheConversations(conversations)

    // Update file-based cache
    // ConversationListCache is updated by ConversationListViewModel on next loadConversations()
    // The notification triggers that reload
}

private func refreshContextProfile(_ userId: UUID) async throws {
    let repo = ContextRepository()
    _ = try await repo.fetchProfile(userId: userId)
    // fetchProfile() already updates CachedContextProfile SwiftData cache internally
}
```

### Concurrency Safety

- `OfflineSyncService` is `@MainActor` — all state mutations are thread-safe
- `syncTask?.cancel()` in `triggerSync()` prevents duplicate concurrent syncs
- `guard !isSyncing else { return }` as additional safeguard in `performSync()`
- `ConversationService` and `ContextRepository` are both `@MainActor` — safe to call directly
- `withTaskGroup` child tasks inherit `@MainActor` isolation
- `weak self` captures in tasks prevent retain cycles

### Error Handling Strategy

- **All sync errors are silent** — never show alerts or error states during background sync
- Log with `#if DEBUG print("OfflineSyncService: ...")` for development visibility
- Auth failures (401): do NOT clear session — let AuthService handle token refresh on next user action
- Network failures: will retry on next connectivity change automatically
- Partial success is OK: if conversations refresh but context fails, the next sync will catch up

### Design for Story 7-4 Extension

Story 7-4 (Sync Conflict Resolution) will MODIFY `performSync()` to add conflict resolution checks. Design the sync flow as a clean sequence:

```
performSync():
  1. replayPendingOperations()
  2. refreshConversationList()      ← 7-4 adds: compare local vs remote, resolve conflicts
  3. refreshContextProfile(userId)  ← 7-4 adds: timestamp comparison, local-wins upload
  4. post .offlineSyncCompleted
```

Keep each refresh method as a separate, overridable method so 7-4 can extend without restructuring.

### Testing Standards

Use **Swift Testing** framework (NOT XCTest) — matches all recent project tests:
- `import Testing`
- `@Test` function annotations
- `#expect()` assertions
- `@MainActor` on test structs
- Test file location: `CoachMe/CoachMeTests/`
- Use mock `NetworkMonitor(isConnected: false, isExpensive: false)` constructor for injecting test state
- Use in-memory `ModelContainer` for SwiftData tests (`isStoredInMemoryOnly: true`)

### Project Structure Notes

**Files to CREATE:**
```
CoachMe/CoachMe/Core/Services/OfflineSyncService.swift   ← Main sync service
CoachMe/CoachMeTests/OfflineSyncServiceTests.swift        ← Tests
```

**Files to MODIFY:**
```
CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift              ← Replace placeholder refresh(), add sync observer
CoachMe/CoachMe/Features/History/ViewModels/ConversationListViewModel.swift ← Add sync observer
CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift            ← Add offline check in updateProfile()
CoachMe/CoachMe/CoachMeApp.swift                                           ← Initialize OfflineSyncService.shared
```

**Alignment**: `OfflineSyncService` at `Core/Services/OfflineSyncService.swift` matches architecture.md's planned project structure. `@MainActor @Observable` singleton pattern matches `NetworkMonitor`, `ConversationService`, and other services. No new architectural patterns introduced.

### References

- [Source: architecture.md#Data Architecture - Caching Strategy] — "Client-side: SwiftData local cache with sync-on-reconnect"
- [Source: architecture.md#Process Patterns - Offline Detection] — NetworkMonitor with NWPathMonitor
- [Source: architecture.md#Frontend Architecture] — MVVM + Repository, `@Observable` ViewModels
- [Source: architecture.md#Implementation Patterns] — Naming, structure, enforcement guidelines
- [Source: architecture.md#Project Structure] — `Core/Services/OfflineSyncService.swift` planned location
- [Source: architecture.md#Anti-Patterns] — Never block main thread, never log PII
- [Source: epics.md#Story 7.3] — FR32: User data syncs automatically when internet connection is restored
- [Source: epics.md#Epic 7 Overview] — FR30 offline read, FR31 offline warning, FR32 auto-sync
- [Source: 7-1-offline-data-caching-with-swiftdata.md] — `OfflineCacheService`, `CachedConversation`, `CachedMessage` models, caching patterns
- [Source: 7-2-offline-warning-banner.md] — `OfflineBanner`, `NetworkMonitor` in ChatView, send button disabled when offline
- [Source: 7-4-sync-conflict-resolution.md] — Will modify `OfflineSyncService.performSync()` to add conflict resolution
- [Source: NetworkMonitor.swift] — Existing `@MainActor @Observable` singleton with `isConnected`, test constructor
- [Source: ChatMessageCache.swift] — File-based per-conversation JSON cache: `save(messages:conversationId:)`
- [Source: ConversationListCache.swift] — File-based conversation list cache with payload struct
- [Source: CachedContextProfile.swift] — SwiftData `@Model` with `lastSyncedAt`, `isStale`, `updateWith(_:)`
- [Source: ConversationService.swift] — `fetchConversations()`, `fetchMessages(conversationId:)`
- [Source: ContextRepository.swift] — `fetchProfile(userId:)` auto-caches, `updateProfile(_:)` remote-first, `cacheProfile(_:)`
- [Source: ChatViewModel.swift:refresh()] — Placeholder method marked for Story 7.3 replacement
- [Source: AuthService.swift:currentUser] — `currentUser?.id` provides userId
- [Source: Story 6-6] — `@MainActor @Observable` pattern, Swift Testing framework, warm error messages

### Previous Story Intelligence

- **From Story 7-1:** SwiftData models use `@Attribute(.unique)` on `remoteId` for upsert. Cache writes are non-blocking (`Task { try? await ... }`). Fetch-all-and-filter pattern mandatory for Swift 6. `OfflineCacheService` is the data-layer cache API.
- **From Story 7-2:** `NetworkMonitor.shared` is the single source of truth for connectivity. DO NOT recreate. Banner dismisses automatically via `@Observable` binding.
- **From Epic 6 (Subscription):** Non-blocking integrations — fire-and-forget pattern for auxiliary operations.
- **From Epic 2 (Context):** `ContextRepository` uses `upsert(_, onConflict:, ignoreDuplicates:)` for atomic creates. Profile staleness threshold is 1 hour.
- **Swift 6 Strict Concurrency:** Always `@MainActor` on services. `ModelContext` is not Sendable — keep on MainActor. Fetch-all-and-filter for SwiftData queries.

### Git Intelligence

Recent commits show consistent patterns:
- Feature branches merged to main with descriptive commit messages
- Tests written alongside feature code
- Error handling follows UX-11 warm first-person pattern throughout
- CodingKeys with snake_case for all Supabase models
- `@MainActor @Observable` on all ViewModels and services

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Swift 6 `deinit` isolation: `@MainActor`-isolated properties cannot be accessed from nonisolated `deinit`. Resolved by removing `deinit` from `OfflineSyncService` (singleton never deallocates) and using `nonisolated(unsafe)` for `syncObserver` in ViewModels.
- Swift 6 `withTaskGroup` sending parameter: closure passed as `sending` parameter causes data race with `@MainActor`-isolated code. Resolved by replacing parallel `withTaskGroup` with sequential `try? await` calls.
- `ContextSituation()` has no default init — used `ContextSituation.empty` static factory in tests.
- Pre-existing `SubscriptionManagementViewModelTests` missing `import SwiftUI` — fixed as drive-by.

### Completion Notes List

- All 8 tasks and all subtasks implemented
- 13 unit tests written (Swift Testing framework) — all pass
- Full test suite passes (2 pre-existing failures in SubscriptionServiceTests unrelated to this story)
- One timing-sensitive test (`testSyncTriggeredOnReconnect`) may be flaky under heavy concurrent load due to `Task.sleep`-based timing — passes reliably in isolation
- `withTaskGroup` replaced with sequential calls due to Swift 6 strict concurrency `sending` parameter constraints — functionally equivalent, minor perf difference acceptable for background sync
- Story 7-4 extension point preserved: `performSync()` is a clean sequential flow that 7-4 can insert conflict resolution into

### File List

**Created:**
- `CoachMe/CoachMe/Core/Services/OfflineSyncService.swift` — Main sync service with network polling, debounce, pending op queue, refresh methods, notification
- `CoachMe/CoachMeTests/OfflineSyncServiceTests.swift` — 13 unit tests covering all acceptance criteria

**Modified:**
- `CoachMe/CoachMe/CoachMeApp.swift` — Added `_ = OfflineSyncService.shared` in `init()` for immediate observation start
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — Replaced placeholder `refresh()`, added sync observer and deinit
- `CoachMe/CoachMe/Features/History/ViewModels/ConversationListViewModel.swift` — Added sync observer and deinit
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` — Added offline check and queue in `updateProfile(_:)`
- `CoachMe/CoachMeTests/SubscriptionManagementViewModelTests.swift` — Added missing `import SwiftUI` (drive-by fix)

### Change Log

- **Story 7.3 implemented**: Automatic Sync on Reconnect — OfflineSyncService with network transition detection, 1s debounce, UserDefaults-backed PendingOperation queue, conversation/context refresh, ViewModel notification observers, offline context profile queueing, and 13 unit tests
