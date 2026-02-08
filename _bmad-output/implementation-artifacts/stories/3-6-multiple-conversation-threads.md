# Story 3.6: Multiple Conversation Threads

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to have separate conversations for different topics**,
so that **I can keep threads organized and return to past coaching sessions**.

## Acceptance Criteria

1. **Given** I am in a conversation, **When** I tap "New conversation" in the toolbar, **Then** a new thread starts with a fresh conversation ID and empty message list, and the previous conversation is preserved in the database.

2. **Given** I have multiple conversations, **When** I tap the history/clock button in the toolbar, **Then** I see a conversation list view showing all my conversations organized by recency, with domain badges and last message preview.

3. **Given** I am viewing the conversation list, **When** I tap a past conversation, **Then** ChatView loads that conversation's messages and I can continue chatting in that thread.

4. **Given** I am viewing the conversation list, **When** I swipe to delete a conversation, **Then** I see a warm confirmation ("This will remove our conversation. You sure?") and on confirm, the conversation and its messages are deleted from Supabase.

5. **Given** I have conversations across different domains, **When** I view the conversation list, **Then** each conversation shows a domain badge (e.g., "Career", "Relationships") based on the `domain` field, along with a title or first-message preview and relative timestamp.

## Tasks / Subtasks

- [x] Task 1: Add fetch and delete methods to ConversationService (AC: #2, #3, #4)
  - [x] 1.1 Add `fetchConversations() async throws -> [Conversation]` to `ConversationServiceProtocol` — fetch all conversations for the current user, ordered by `last_message_at DESC`
  - [x] 1.2 Add `fetchMessages(conversationId: UUID) async throws -> [ChatMessage]` — fetch all messages for a given conversation
  - [x] 1.3 Add `deleteConversation(id: UUID) async throws` to `ConversationServiceProtocol` — delete a conversation and its messages (AC: #4)
  - [x] 1.4 Implement all methods in `ConversationService` using Supabase REST queries with RLS (DELETE with cascade for deletion)

- [x] Task 2: Create ConversationListViewModel (AC: #2, #4, #5)
  - [x] 2.1 Create `Features/History/ViewModels/ConversationListViewModel.swift` — `@MainActor @Observable` class
  - [x] 2.2 Properties: `conversations: [Conversation]`, `isLoading: Bool`, `error: ConversationError?`
  - [x] 2.3 Methods: `loadConversations()`, `deleteConversation(id:)`, `refreshConversations()`
  - [x] 2.4 Call `ConversationService.shared.fetchConversations()` for data

- [x] Task 3: Create ConversationListView (AC: #2, #4, #5)
  - [x] 3.1 Create `Features/History/Views/ConversationListView.swift` — SwiftUI List with adaptive styling
  - [x] 3.2 Create `Features/History/Views/ConversationRow.swift` — row component showing domain badge, title/preview, relative timestamp, message count
  - [x] 3.3 Add swipe-to-delete with warm confirmation alert (UX-11: "This will remove our conversation. You sure?")
  - [x] 3.4 Add empty state when no conversations exist ("No conversations yet. Start one!")
  - [x] 3.5 Apply `.adaptiveGlass()` to navigation elements, NOT to content rows
  - [x] 3.6 Ensure VoiceOver accessibility labels on all interactive elements

- [x] Task 4: Create domain badge component (AC: #5)
  - [x] 4.1 Create a `DomainBadge.swift` component in `Core/UI/Components/` — small pill/tag showing domain name with domain-specific color
  - [x] 4.2 Define a `CoachingDomain` enum (or constants) in `Core/Models/` centralizing the 7 known domains ("life", "career", "relationships", "mindset", "creativity", "fitness", "leadership") with display names and colors from `Colors.swift`
  - [x] 4.3 Handle nil domain: show no badge (omit entirely). Handle unknown-but-not-nil domain: show raw domain string capitalized with a neutral/default color

- [x] Task 5: Update Router for conversation list navigation (AC: #2, #3)
  - [x] 5.1 Add `.conversationList` case to `Router.Screen` enum
  - [x] 5.2 Add `navigateToConversationList()` and `navigateToChat(conversationId: UUID?)` methods
  - [x] 5.3 Update `RootView.swift` to handle `.conversationList` screen rendering

- [x] Task 6: Update ChatViewModel for conversation switching (AC: #1, #3)
  - [x] 6.1 Add `loadConversation(id: UUID) async` method — fetches messages for an existing conversation via `ConversationService.fetchMessages(conversationId:)` and sets `currentConversationId`
  - [x] 6.2 Modify `startNewConversation()` to properly reset state (clear messages, generate new UUID, set `isConversationPersisted = false`)
  - [x] 6.3 Ensure `sendMessage()` still calls `ensureConversationExists()` before first message in a new thread

- [x] Task 7: Wire up ChatView toolbar actions (AC: #1, #2)
  - [x] 7.1 Replace the "History coming soon" toast with actual navigation to `ConversationListView` via Router
  - [x] 7.2 Ensure "New Conversation" button calls `startNewConversation()` and stays on ChatView with empty state
  - [x] 7.3 Handle back navigation from ConversationListView → ChatView when a conversation is selected

- [x] Task 8: Write unit tests (All ACs)
  - [x] 8.1 `ConversationListViewModelTests` — test load, delete, error handling
  - [x] 8.2 `ChatViewModelTests` — test `loadConversation(id:)`, test `startNewConversation()` preserves previous conversation
  - [x] 8.3 `ConversationServiceTests` — test `fetchConversations()`, `fetchMessages(conversationId:)`

## Dev Notes

### Architecture Compliance

- **Pattern**: MVVM + Repository. ConversationListViewModel calls ConversationService (which is the repository/service layer). Views observe @Observable ViewModels.
- **State Management**: Use `@Observable` for ConversationListViewModel (NOT `@ObservableObject`).
- **Adaptive Design**: Apply `.adaptiveGlass()` to toolbar/navigation elements in ConversationListView. Do NOT apply glass to conversation rows or content — only navigation/control elements get glass treatment.
- **Error Messages**: Use warm, first-person copy per UX-11 (e.g., "I couldn't load your conversations right now").
- **Swift 6 Concurrency**: Mark ConversationListViewModel with `@MainActor`. Use `async/await` for all service calls.
- **Accessibility**: VoiceOver labels on every interactive element. Dynamic Type support. Ensure conversation rows have meaningful accessibility descriptions.

### Technical Requirements

- **Supabase Queries**: Use `AppEnvironment.shared.supabase` for all Supabase calls. Queries use RLS so filtering by `user_id` is automatic. Order conversations by `last_message_at DESC`.
- **CodingKeys**: The `Conversation` model already uses `snake_case` CodingKeys. `ChatMessage` also has CodingKeys. No changes needed to models.
- **No new database migrations**: The `conversations` and `messages` tables already exist with all needed columns (`title`, `domain`, `last_message_at`, `message_count`). Indexes `idx_conversations_user_id` and `idx_conversations_last_message_at` already exist.
- **Router Integration**: Router is `@Observable` and injected via `@Environment`. Navigation uses `router.currentScreen` pattern. Add a new `.conversationList` screen case.

### Library & Framework Requirements

- **SwiftUI**: Use `List` with `.listStyle(.plain)` for conversation list. Use `.swipeActions` for delete.
- **Supabase Swift SDK**: Use `.from("conversations").select().order("last_message_at", ascending: false)` for fetching conversations. Use `.from("messages").select().eq("conversation_id", value: id).order("created_at")` for fetching messages.
- **No new dependencies required** — everything uses existing Supabase SDK and SwiftUI.

### File Structure Requirements

**New Files:**
```
Features/History/
├── Views/
│   ├── ConversationListView.swift
│   └── ConversationRow.swift
└── ViewModels/
    └── ConversationListViewModel.swift

Core/UI/Components/
└── DomainBadge.swift
```

**Modified Files:**
```
Core/Services/ConversationService.swift          — Add fetch methods
Features/Chat/ViewModels/ChatViewModel.swift     — Add loadConversation(), update startNewConversation()
Features/Chat/Views/ChatView.swift               — Wire toolbar to real navigation
App/Navigation/Router.swift                      — Add .conversationList screen
App/Navigation/RootView.swift                    — Render ConversationListView
```

### Testing Requirements

- **Framework**: XCTest (existing test framework in CoachMeTests target)
- **Simulator**: iPhone 17 (iOS 26.2) — ID: `8111EC8A-2D7C-43F6-B603-9803D4A60683`
- **Patterns**: Use mock implementations of `ConversationServiceProtocol` for ViewModel tests
- **Coverage**: All ViewModel methods, all service fetch methods, error paths
- **Run command**: `xcodebuild test -scheme CoachMe -destination 'platform=iOS Simulator,id=8111EC8A-2D7C-43F6-B603-9803D4A60683' -only-testing:CoachMeTests`

### Previous Story Intelligence

No previous Epic 3 stories have been implemented yet (all in backlog). However, from Epic 2 implementation:
- **ConversationService** is a `@MainActor` singleton with `shared` instance — follow this pattern for new methods
- **ChatViewModel** uses dependency injection via init parameters (optional services) — maintain this for testability
- **SwiftData fetch pattern**: For `Sendable` issues with KeyPath predicates, use fetch-all-and-filter: `let results = try modelContext.fetch(FetchDescriptor<T>()); let matching = results.filter { ... }`
- **Error handling pattern**: `ConversationError` enum with `LocalizedError` conformance and warm messages

### Git Intelligence

Recent commits (4 total):
- `ad8abd3` — checkpoint (Epic 2 complete)
- `f6da5f5` — Fix message input text box colors for light mode
- `1aa8476` — Redesign message input to match iMessage style
- `4f9cc33` — Initial commit: Coach App iOS with Epic 1 complete

**Patterns established**: Inline retry for failed messages (iMessage-style), warm error messaging, `@MainActor` on all services/VMs, factory methods for model creation.

### Project Structure Notes

- All paths follow the architecture's feature-module pattern: `Features/{FeatureName}/Views/`, `Features/{FeatureName}/ViewModels/`
- The `Features/History/` directory already exists as a placeholder — use it for new views and viewmodels
- `DomainBadge.swift` goes in `Core/UI/Components/` since it's a reusable component (may be used in future stories like 3.7 Conversation History View)
- No conflicts with existing structure detected

### Cross-Story Context

- **Story 3.7 (Conversation History View)** will build on this story's ConversationListView. Design the list view and ConversationRow to be extensible — 3.7 may add "Continue this conversation" for read-only past conversations and more detailed history browsing.
- **Story 3.1 (Invisible Domain Routing)** will populate the `domain` field on conversations. Until that's implemented, most conversations will have `domain: nil`. DomainBadge should gracefully handle nil domains.
- **Story 3.3 (Cross-Session Memory References)** and **3.4 (Pattern Recognition)** may need to query across conversations — the `fetchConversations()` method provides the foundation.
- **Story 2.6 (Conversation Deletion)** already exists in SettingsView ("Clear all conversations"). This story adds per-conversation deletion from the list view — ensure both deletion paths use the same `ConversationService.deleteConversation(id:)`.

### References

- [Source: architecture.md#Project-Structure] — Feature module pattern, file naming conventions
- [Source: architecture.md#Implementation-Patterns] — MVVM + Repository, @Observable ViewModels, CodingKeys
- [Source: architecture.md#Frontend-Architecture] — Adaptive design system, AdaptiveGlassContainer usage rules
- [Source: architecture.md#API-Communication] — Supabase REST API for CRUD operations
- [Source: epics.md#Story-3.6] — Original story definition and acceptance criteria
- [Source: epics.md#Story-3.7] — Next story context (Conversation History View)
- [Source: ux-design-specification.md#Effortless-Interactions] — Conversation history accessible in one tap
- [Source: ux-design-specification.md#Experience-Principles] — Warm Over Cold, Every Interaction Matters

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build succeeded with all new files auto-discovered via PBXFileSystemSynchronizedRootGroup
- Resolved naming conflict: removed duplicate CoachingDomain.swift from Core/Models/ — existing one in Core/Constants/ already had all needed properties

### Completion Notes List

- Task 1: Added `fetchConversations()` and `fetchMessages(conversationId:)` to ConversationServiceProtocol and ConversationService. Added `fetchFailed` error case with warm UX-11 messaging.
- Task 2: Created ConversationListViewModel with @MainActor @Observable, load/refresh/delete operations, and error handling via mock-injectable ConversationServiceProtocol.
- Task 3: Created ConversationListView with navigation bar, conversation list, swipe-to-delete with warm confirmation ("This will remove our conversation. You sure?"), empty state, and loading state. Created ConversationRow with domain indicator dot, title, relative timestamp, domain badge, and message count.
- Task 4: Created DomainBadge reusable component using existing CoachingDomain enum. Handles known domains (with color), unknown non-nil domains (capitalized, neutral color), and nil domains (renders nothing).
- Task 5: Added `.conversationList` screen case to Router. Added `selectedConversationId` property and `navigateToChat(conversationId:)` / `navigateToConversationList()` methods. Updated RootView to render ConversationListView.
- Task 6: Added `loadConversation(id:)` to ChatViewModel — fetches messages, sets conversation as persisted, resets all UI state. Updated `startNewConversation()` unchanged (already generates new UUID).
- Task 7: Replaced "History coming soon" toast with actual Router navigation to ConversationListView. Added `.task` handler to load selected conversation from router when returning from list. Removed dead toast code.
- Task 8: Created ConversationListViewModelTests (15 tests). Extended ChatViewModelTests with 5 conversation switching tests. Extended ConversationServiceTests with fetchFailed error test and 4 mock-based fetch tests. Updated MockConversationService with fetch method support.

### Change Log

- 2026-02-07: Story 3.6 implementation complete — all 8 tasks, all ACs addressed

### File List

**New Files:**
- CoachMe/Features/History/ViewModels/ConversationListViewModel.swift
- CoachMe/Features/History/Views/ConversationListView.swift
- CoachMe/Features/History/Views/ConversationRow.swift
- CoachMe/Core/UI/Components/DomainBadge.swift
- CoachMeTests/ConversationListViewModelTests.swift

**Modified Files:**
- CoachMe/Core/Services/ConversationService.swift — Added fetchConversations(), fetchMessages(), fetchFailed error case
- CoachMe/Features/Chat/ViewModels/ChatViewModel.swift — Added loadConversation(id:)
- CoachMe/Features/Chat/Views/ChatView.swift — Replaced history toast with real navigation, added conversation loading from router
- CoachMe/App/Navigation/Router.swift — Added .conversationList screen, selectedConversationId, navigation methods
- CoachMe/App/Navigation/RootView.swift — Added .conversationList case rendering
- CoachMeTests/Mocks/MockConversationService.swift — Added fetch method support
- CoachMeTests/ChatViewModelTests.swift — Added 5 conversation switching tests
- CoachMeTests/ConversationServiceTests.swift — Added fetchFailed error test and 4 fetch mock tests

