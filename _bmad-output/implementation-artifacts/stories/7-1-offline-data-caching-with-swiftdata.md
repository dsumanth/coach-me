# Story 7.1: Offline Data Caching with SwiftData

Status: review

## Story

As a **user**,
I want **my conversations and context cached on my device**,
So that **I can browse my past coaching sessions when offline**.

## Acceptance Criteria

1. **Given** I have conversations and messages fetched from Supabase, **When** the data is loaded successfully, **Then** it is also persisted to SwiftData for offline access.

2. **Given** I lose network connection, **When** I open the app, **Then** I can browse my cached conversations and read past messages.

3. **Given** I am offline, **When** I open a cached conversation, **Then** I see all previously-fetched messages with correct ordering and timestamps.

4. **Given** I am offline, **When** I view my context profile, **Then** I see my cached profile data (values, goals, situation) — this already works via `CachedContextProfile`.

5. **Given** I come back online, **When** fresh data is fetched from Supabase, **Then** the local SwiftData cache is updated with the latest data.

6. **Given** I delete a conversation, **When** the deletion succeeds remotely, **Then** the corresponding cached conversation and its messages are also removed from SwiftData.

7. **Given** I sign out, **When** the sign-out completes, **Then** all cached conversations, messages, and context are cleared from SwiftData.

## Tasks / Subtasks

- [x] **Task 1: Create SwiftData models** (AC: #1, #2, #3)
  - [x] 1.1 Create `CachedConversation` @Model in `Core/Data/Local/CachedConversation.swift`
  - [x] 1.2 Create `CachedMessage` @Model in `Core/Data/Local/CachedMessage.swift`
  - [x] 1.3 Update `AppEnvironment.modelContainer` schema to include new models
  - [x] 1.4 Add `@Attribute(.unique)` on `remoteId` fields for upsert behavior

- [x] **Task 2: Create OfflineCacheService** (AC: #1, #5, #6, #7)
  - [x] 2.1 Create `Core/Services/OfflineCacheService.swift` following @MainActor singleton pattern
  - [x] 2.2 Implement `cacheConversations(_:)` — bulk upsert conversations to SwiftData
  - [x] 2.3 Implement `cacheMessages(_:forConversation:)` — bulk upsert messages to SwiftData
  - [x] 2.4 Implement `getCachedConversations()` → `[CachedConversation]`
  - [x] 2.5 Implement `getCachedMessages(conversationId:)` → `[CachedMessage]`
  - [x] 2.6 Implement `deleteCachedConversation(id:)` — cascade delete messages
  - [x] 2.7 Implement `clearAllCachedData()` — full wipe for sign-out
  - [x] 2.8 Use fetch-all-and-filter pattern (Swift 6 Sendable compliance)

- [x] **Task 3: Integrate caching into existing data flows** (AC: #1, #5)
  - [x] 3.1 Update `ConversationService.fetchConversations()` to cache results via `OfflineCacheService`
  - [x] 3.2 Update `ConversationService.fetchMessages(conversationId:)` to cache results
  - [x] 3.3 Update `ChatViewModel` to cache messages after stream completes (on `StreamEvent.done`)
  - [x] 3.4 Ensure cache writes are non-blocking (`Task { try? await ... }` pattern)

- [x] **Task 4: Integrate offline fallback into ViewModels** (AC: #2, #3)
  - [x] 4.1 Update `ConversationListViewModel` to fall back to `OfflineCacheService.getCachedConversations()` when `NetworkMonitor.isConnected == false`
  - [x] 4.2 Update `ChatViewModel` to load from `OfflineCacheService.getCachedMessages(conversationId:)` when offline
  - [x] 4.3 Map `CachedConversation` → `ConversationService.Conversation` and `CachedMessage` → `ChatMessage` for seamless ViewModel consumption

- [x] **Task 5: Integrate deletion and sign-out cleanup** (AC: #6, #7)
  - [x] 5.1 Update `ConversationService.deleteConversation(id:)` to also call `OfflineCacheService.deleteCachedConversation(id:)`
  - [x] 5.2 Update `AuthService.signOut()` to call `OfflineCacheService.clearAllCachedData()`
  - [x] 5.3 Ensure `ChatMessageCache` (file-based) is also cleared on sign-out (already exists — verify)

- [x] **Task 6: Write unit tests** (AC: all)
  - [x] 6.1 `OfflineCacheServiceTests` — cache CRUD, bulk operations, cascade delete, clear all
  - [x] 6.2 `CachedConversationTests` — model encoding/decoding, unique constraints
  - [x] 6.3 `CachedMessageTests` — model encoding/decoding, ordering
  - [x] 6.4 Use in-memory `ModelContainer` for all tests (`isStoredInMemoryOnly: true`)

## Dev Notes

### Architecture Patterns & Constraints

**MVVM + Repository pattern** — ViewModels call Services/Repositories, never Supabase directly.

**@MainActor on all services** — Required for Swift 6 strict concurrency. All SwiftData operations must run on MainActor since `ModelContext` is not `Sendable`.

**Fetch-all-and-filter pattern** — Do NOT use predicates in `FetchDescriptor`. Swift 6 KeyPath predicates cause `Sendable` issues. Instead:
```swift
let descriptor = FetchDescriptor<CachedConversation>()
let all = try modelContext.fetch(descriptor)
let matching = all.filter { $0.userId == userId }
```

**Non-blocking cache writes** — Cache operations must never block the main flow. Wrap in `Task { try? await ... }` so remote-fetch success is returned immediately while cache updates happen in the background.

**Remote-first, cache-fallback** — The existing pattern (from `ContextRepository`) is: attempt remote fetch → on success, update cache and return data → on failure, fall back to local cache. Story 7.1 follows this same pattern for conversations and messages.

### Existing Code to Reuse (DO NOT Reinvent)

| Component | Location | Reuse Strategy |
|-----------|----------|----------------|
| `CachedContextProfile` | `Core/Data/Local/CachedContextProfile.swift` | **Model pattern** — copy structure for new models |
| `ContextRepository` | `Core/Data/Repositories/ContextRepository.swift` | **Cache integration pattern** — remote-first + fallback |
| `ChatMessageCache` | `Features/Chat/Services/ChatMessageCache.swift` | **Keep as-is** — file-based cache still useful for fast thread switching; SwiftData adds structured offline access |
| `ConversationListCache` | `Features/History/ViewModels/ConversationListCache.swift` | **Keep as-is** — file-based cache for instant list display; SwiftData adds offline reliability |
| `NetworkMonitor` | `Core/Services/NetworkMonitor.swift` | **Use directly** — `NetworkMonitor.shared.isConnected` for offline detection |
| `AppEnvironment` | `App/Environment/AppEnvironment.swift` | **Modify** — add new models to schema |
| `ConversationService` | `Core/Services/ConversationService.swift` | **Modify** — add cache calls after remote fetches |
| `AuthService` | `Features/Auth/Services/AuthService.swift` | **Modify** — add cache clear on sign-out |

### What NOT to Do

- **Do NOT replace `ChatMessageCache` or `ConversationListCache`** — They serve as fast in-memory/file caches for instant UI. SwiftData adds offline persistence alongside them.
- **Do NOT add complex sync logic** — Story 7.3 handles auto-sync on reconnect. Story 7.1 is cache-on-fetch only.
- **Do NOT add conflict resolution** — Story 7.4 handles conflicts. Story 7.1 treats server as authoritative.
- **Do NOT add offline write queues** — Story 7.1 is read-only offline. Users cannot create new messages offline.
- **Do NOT add UI changes** — Story 7.2 adds the offline warning banner. Story 7.1 is data-layer only.
- **Do NOT use `@ObservableObject`** — Project uses `@Observable` (iOS 17+ Observation framework).
- **Do NOT use raw `.glassEffect()`** — Always use adaptive modifiers (not relevant here, but guard against accidental UI work).

### SwiftData Model Design

**CachedConversation:**
```swift
@Model
final class CachedConversation {
    @Attribute(.unique) var remoteId: UUID
    var userId: UUID
    var title: String?
    var domain: String?
    var lastMessageAt: Date?
    var messageCount: Int
    var createdAt: Date
    var updatedAt: Date
    var cachedAt: Date

    init(from conversation: ConversationService.Conversation) { ... }
    func toConversation() -> ConversationService.Conversation { ... }
}
```

**CachedMessage:**
```swift
@Model
final class CachedMessage {
    @Attribute(.unique) var remoteId: UUID
    var conversationId: UUID
    var role: String  // "user" or "assistant" — store as String, not enum (SwiftData limitation)
    var content: String
    var createdAt: Date
    var cachedAt: Date

    init(from message: ChatMessage) { ... }
    func toChatMessage() -> ChatMessage { ... }
}
```

### Project Structure Notes

**New files to create:**
```
Core/Data/Local/CachedConversation.swift    ← @Model
Core/Data/Local/CachedMessage.swift          ← @Model
Core/Services/OfflineCacheService.swift      ← Cache service
```

**Files to modify:**
```
App/Environment/AppEnvironment.swift         ← Add models to schema
Core/Services/ConversationService.swift      ← Cache after remote fetch
Features/Chat/ViewModels/ChatViewModel.swift ← Cache after stream, offline fallback
Features/History/ViewModels/ConversationListViewModel.swift ← Offline fallback
Features/Auth/Services/AuthService.swift     ← Clear cache on sign-out
```

**Test files to create:**
```
CoachMeTests/OfflineCacheServiceTests.swift
CoachMeTests/CachedConversationTests.swift
CoachMeTests/CachedMessageTests.swift
```

### References

- [Source: architecture.md#Data Architecture] — SwiftData for local persistence, Keychain for sensitive data
- [Source: architecture.md#Implementation Patterns] — Repository pattern, @Observable ViewModels, offline detection
- [Source: architecture.md#Anti-Patterns] — Never use raw `.glassEffect()`, never block main thread
- [Source: epics.md#Story 7.1] — FR30: Users can access past conversations and context profile while offline
- [Source: epics.md#Epic 7 Dependencies] — Epic 7 standalone with Epics 1+2 complete
- [Source: CachedContextProfile.swift] — Existing SwiftData @Model pattern with staleness checking
- [Source: ContextRepository.swift] — Remote-first + cache-fallback pattern, fetch-all-and-filter for Swift 6
- [Source: ChatMessageCache.swift] — Existing file-based cache to preserve alongside SwiftData
- [Source: ConversationListCache.swift] — Existing file-based conversation list cache
- [Source: NetworkMonitor.swift] — Existing NWPathMonitor with `isConnected` and `isExpensive` properties

### Previous Epic Learnings

- **From Epic 6 (Subscription):** Non-blocking integrations — wrap SDK calls in `Task { try? await ... }`. Cache init should never block app launch.
- **From Epic 4 (Safety):** Data flows through system identically regardless of source. Cached data must be indistinguishable from remote data in ViewModels.
- **From Epic 2 (Context):** SwiftData `@Attribute(.unique)` on `userId` for upsert behavior. Use JSON `Data` encoding for complex nested models if needed. 1-hour staleness threshold for cache freshness.
- **Swift 6 Strict Concurrency:** Always use `@MainActor` on services. Always use fetch-all-and-filter for SwiftData queries. `ModelContext` is not Sendable — keep on MainActor.

### Git Intelligence

Recent commits show consistent patterns:
- Feature branches merged to main with descriptive commit messages
- Edge function + iOS code changes coordinated together
- Tests written alongside feature code
- Error handling follows UX-11 warm first-person pattern throughout

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build verified after each task — all 6 builds succeeded
- Pre-existing test compilation failures in SubscriptionManagementViewModelTests, SubscriptionServiceTests, VoiceInputButtonTests, VoiceInputViewModelTests (missing SwiftUI import) — unrelated to this story

### Completion Notes List

- **Task 1**: Created `CachedConversation` and `CachedMessage` @Model classes following `CachedContextProfile` pattern. Both have `@Attribute(.unique)` on `remoteId` for upsert. Added both to `AppEnvironment.modelContainer` schema.
- **Task 2**: Created `OfflineCacheService` as `@MainActor` singleton with testing initializer accepting custom `ModelContext`. All methods use fetch-all-and-filter pattern for Swift 6 compliance. Includes bulk upsert, retrieval with sorting, cascade delete, and full wipe.
- **Task 3**: Added non-blocking `Task { ... }` cache writes in `ConversationService.fetchConversations()`, `ConversationService.fetchMessages()`, and `ChatViewModel.persistCurrentConversationCache()`. Cache writes never block the main data flow.
- **Task 4**: Added offline fallback in `ConversationListViewModel.loadConversations()` and `ChatViewModel.loadConversation()`. When `NetworkMonitor.shared.isConnected == false`, ViewModels load from SwiftData cache. Also falls back on remote fetch failure when no file-based cache exists.
- **Task 5**: Added `OfflineCacheService.deleteCachedConversation(id:)` call in `ConversationService.deleteConversation()`. Added `OfflineCacheService.clearAllCachedData()` in `AuthService.clearSession()`. Verified `ChatMessageCache.clearAll()` already called on sign-out.
- **Task 6**: Created 3 test files with 30+ test cases using in-memory `ModelContainer`. Tests cover CRUD, bulk upsert, sorting, cascade delete, clear all, unique constraints, round-trip conversions, and edge cases.

### Change Log

- 2026-02-09: Story 7.1 implementation complete — offline data caching with SwiftData for conversations and messages

### File List

**New files:**
- `CoachMe/CoachMe/Core/Data/Local/CachedConversation.swift`
- `CoachMe/CoachMe/Core/Data/Local/CachedMessage.swift`
- `CoachMe/CoachMe/Core/Services/OfflineCacheService.swift`
- `CoachMe/CoachMeTests/OfflineCacheServiceTests.swift`
- `CoachMe/CoachMeTests/CachedConversationTests.swift`
- `CoachMe/CoachMeTests/CachedMessageTests.swift`

**Modified files:**
- `CoachMe/CoachMe/App/Environment/AppEnvironment.swift` — Added CachedConversation, CachedMessage to schema
- `CoachMe/CoachMe/Core/Services/ConversationService.swift` — Cache conversations and messages after fetch, delete cache on conversation deletion
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — SwiftData cache in persistCurrentConversationCache(), offline fallback in loadConversation()
- `CoachMe/CoachMe/Features/History/ViewModels/ConversationListViewModel.swift` — Offline fallback in loadConversations()
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` — Clear SwiftData cache on sign-out
