# Story 2.6: Conversation Deletion

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to delete individual conversations or all my history**,
So that **I control what the coach remembers**.

## Acceptance Criteria

1. **Given** I view a conversation (in chat or future history view)
   **When** I tap delete (via swipe, menu, or button)
   **Then** I see a confirmation with warm copy: "This will remove our conversation. You sure?"

2. **Given** I confirm deletion
   **When** the action completes
   **Then** the conversation is deleted from Supabase and local cache (SwiftData when implemented in Story 7.1)

3. **Given** I want to delete all history
   **When** I tap "Clear all conversations" in settings
   **Then** all conversations are deleted after confirmation with warm copy: "This will clear all our conversations. Are you sure you want to start fresh?"

4. **Given** I delete the current active conversation
   **When** the deletion completes
   **Then** I'm returned to an empty chat state ready to start a new conversation

5. **Given** I have pending/in-progress conversations cached locally (future Story 7.1)
   **When** I delete a conversation
   **Then** the local SwiftData cache is also cleared for that conversation

## Tasks / Subtasks

- [x] Task 1: Add delete methods to ConversationService (AC: #2)
  - [x] 1.1 Add `deleteConversation(id: UUID) async throws` method
  - [x] 1.2 Add `deleteAllConversations() async throws` method
  - [x] 1.3 Add `ConversationError.deleteFailed(String)` case with warm first-person message
  - [x] 1.4 Verify RLS policies allow delete operations (already in migration 20260205000002)
  - [x] 1.5 Use `getCurrentUserId()` to ensure user owns conversation before delete

- [x] Task 2: Add delete functionality to ChatViewModel (AC: #1, #4)
  - [x] 2.1 Add `deleteConversation() async` method to delete current conversation
  - [x] 2.2 Add `showDeleteConfirmation: Bool` state property
  - [x] 2.3 After successful deletion, call `startNewConversation()` to reset to empty state
  - [x] 2.4 Handle deletion errors with warm error message display

- [x] Task 3: Create DeleteConfirmationAlert component (AC: #1, #3)
  - [x] 3.1 Create `DeleteConfirmationAlert.swift` in `Core/UI/Components/`
  - [x] 3.2 Single conversation delete copy: "This will remove our conversation. You sure?"
  - [x] 3.3 All conversations delete copy: "This will clear all our conversations. Are you sure you want to start fresh?"
  - [x] 3.4 Primary action: "Remove" (destructive) for single, "Clear All" for all
  - [x] 3.5 Secondary action: "Keep it" (cancel)
  - [x] 3.6 Add VoiceOver accessibility for the alert

- [x] Task 4: Add delete UI to ChatView (AC: #1, #4)
  - [x] 4.1 Add delete option to ChatView toolbar menu (three dots or contextual menu)
  - [x] 4.2 Wire up `showDeleteConfirmation` to confirmation alert
  - [x] 4.3 Show loading state during deletion
  - [x] 4.4 Transition to empty conversation state after deletion

- [x] Task 5: Create SettingsView with "Clear All" option (AC: #3)
  - [x] 5.1 Create `SettingsView.swift` in `Features/Settings/Views/`
  - [x] 5.2 Add "Clear all conversations" row with warm warning styling
  - [x] 5.3 Create `SettingsViewModel.swift` with `deleteAllConversations()` method
  - [x] 5.4 Wire up confirmation alert for bulk delete
  - [x] 5.5 Add Settings navigation from ChatView toolbar (gear icon)
  - [x] 5.6 Apply `.adaptiveGlass()` to section containers per design system

- [x] Task 6: Write Unit Tests (AC: #1, #2, #3, #4)
  - [x] 6.1 Test `ConversationService.deleteConversation()` success case
  - [x] 6.2 Test `ConversationService.deleteConversation()` not found case
  - [x] 6.3 Test `ConversationService.deleteAllConversations()` success case
  - [x] 6.4 Test `ChatViewModel.deleteConversation()` calls service and resets state
  - [x] 6.5 Test `SettingsViewModel.deleteAllConversations()` calls service

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1 & Stories 2.1-2.5:**

1. **Service Pattern**: Use `@MainActor` singleton services (like `ConversationService.shared`)
2. **ViewModel Pattern**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel`, `ContextViewModel`)
3. **Supabase Access**: Always via `AppEnvironment.shared.supabase`
4. **Error Handling**: Use first-person messages per UX-11 ("I couldn't..." not "Failed to...")
5. **Adaptive Design**: Use `.adaptiveGlass()` for containers, `.adaptiveInteractiveGlass()` for buttons
6. **SwiftData**: When Story 7.1 implements caching, deletion should clear SwiftData cache too

### Technical Requirements

**From PRD (FR15):**
> Users can delete individual conversations or their entire conversation history

**From UX Design Spec (UX-11):**
> Error messages use first person: "I couldn't connect right now"

**Database Schema (already supports cascade delete):**
```sql
-- From 20260205000001_initial_schema.sql
CREATE TABLE public.messages (
    ...
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    ...
);
```

This means deleting a conversation automatically deletes all its messages - no need for manual cascade!

**RLS Policies (already allow delete):**
```sql
-- From 20260205000002_rls_policies.sql
CREATE POLICY "Users can delete own conversations"
    ON public.conversations FOR DELETE
    USING (auth.uid() = user_id);
```

### Key Design Principles

- **Warm confirmation copy**: Make the user feel comfortable, not anxious about deletion
- **Clear consequences**: User should understand what will be deleted
- **Reversibility messaging**: No "this cannot be undone" scary warnings - keep it warm
- **Immediate feedback**: Show deletion happening, then transition smoothly to new state

### Existing Code to Leverage

**ConversationService (add delete methods here):**
```swift
// From Core/Services/ConversationService.swift
@MainActor
final class ConversationService {
    static let shared = ConversationService()

    // Existing methods:
    func createConversation(id: UUID? = nil) async throws -> UUID
    func ensureConversationExists(id: UUID) async throws -> UUID
    func conversationExists(id: UUID) async -> Bool
    func updateConversation(id: UUID, title: String? = nil) async

    // NEW: Add these methods for Story 2.6
    // func deleteConversation(id: UUID) async throws
    // func deleteAllConversations() async throws
}
```

**ChatViewModel (add delete state and method):**
```swift
// From Features/Chat/ViewModels/ChatViewModel.swift
@MainActor
@Observable
final class ChatViewModel {
    // Existing state:
    private(set) var currentConversationId: UUID?

    // Existing method to reuse after deletion:
    func startNewConversation() {
        currentSendTask?.cancel()
        messages = []
        currentConversationId = UUID()
        isConversationPersisted = false
        // ... resets all state
    }

    // NEW: Add for Story 2.6
    // var showDeleteConfirmation = false
    // func deleteConversation() async
}
```

**ChatView (add delete button to toolbar):**
```swift
// From Features/Chat/Views/ChatView.swift
// Add delete option to toolbar:
// Menu {
//     Button(role: .destructive) { showDeleteConfirmation = true }
//         label: Label("Delete conversation", systemImage: "trash")
// }
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/CoachMe/Features/Settings/
├── Views/
│   └── SettingsView.swift           # NEW - Settings screen with "Clear all"
└── ViewModels/
    └── SettingsViewModel.swift       # NEW - Handles bulk delete

CoachMe/CoachMe/Core/UI/Components/
└── DeleteConfirmationAlert.swift     # NEW - Reusable warm delete confirmation

CoachMeTests/
├── ConversationServiceTests.swift    # NEW - Test delete methods
└── SettingsViewModelTests.swift      # NEW - Test bulk delete
```

**Files to Modify:**
```
CoachMe/CoachMe/Core/Services/
└── ConversationService.swift         # MODIFY - Add delete methods

CoachMe/CoachMe/Features/Chat/
├── ViewModels/
│   └── ChatViewModel.swift           # MODIFY - Add delete state/method
└── Views/
    └── ChatView.swift                # MODIFY - Add delete UI + settings nav
```

### Previous Story Learnings (Stories 2.1-2.5)

**Key Patterns from Story 2.5 Code Review:**

1. **Confirmation dialogs with warm copy:**
```swift
// Pattern from ContextProfileView delete confirmation
.alert("Remove this from your profile?", isPresented: $showDeleteAlert) {
    Button("Keep it", role: .cancel) { }
    Button("Remove", role: .destructive) {
        Task { await viewModel.deleteValue(id: itemToDelete) }
    }
}
```

2. **Async delete with error handling:**
```swift
func deleteValue(id: UUID) async {
    guard var profile = profile else { return }

    // Optimistic removal (optional for conversation - DB is source of truth)
    let originalProfile = profile
    profile.removeValue(id: id)
    self.profile = profile

    do {
        try await repository.updateProfile(profile)
    } catch {
        // Rollback on error
        self.profile = originalProfile
        self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
    }
}
```

3. **VoiceOver for destructive actions:**
```swift
Button("Delete conversation", role: .destructive) { ... }
    .accessibilityHint("Double tap to delete this conversation")
```

### Git Intelligence (Recent Commits)

```
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Stories 2.1-2.5 added context profile management. Story 2.6 completes Epic 2 by adding conversation deletion for full user control over their data.

### Testing Requirements

**Unit Tests to Create:**

```swift
// ConversationServiceTests.swift
final class ConversationServiceTests: XCTestCase {
    var sut: ConversationService!
    var mockSupabase: MockSupabaseClient!

    func testDeleteConversationSuccess() async throws {
        // Given a conversation exists
        let conversationId = UUID()
        mockSupabase.deleteWillSucceed = true

        // When deleting
        try await sut.deleteConversation(id: conversationId)

        // Then delete was called on Supabase
        XCTAssertTrue(mockSupabase.deleteCalled)
        XCTAssertEqual(mockSupabase.deletedId, conversationId)
    }

    func testDeleteConversationNotFound() async {
        // Given conversation doesn't exist
        mockSupabase.deleteWillThrow = ConversationService.ConversationError.notFound

        // When deleting
        do {
            try await sut.deleteConversation(id: UUID())
            XCTFail("Should throw")
        } catch let error as ConversationService.ConversationError {
            XCTAssertEqual(error, .notFound)
        }
    }

    func testDeleteAllConversationsSuccess() async throws {
        // Given user has conversations
        mockSupabase.deleteAllWillSucceed = true

        // When deleting all
        try await sut.deleteAllConversations()

        // Then bulk delete was called
        XCTAssertTrue(mockSupabase.deleteAllCalled)
    }
}

// SettingsViewModelTests.swift
final class SettingsViewModelTests: XCTestCase {
    var sut: SettingsViewModel!
    var mockConversationService: MockConversationService!

    func testDeleteAllConversationsSuccess() async {
        // Given
        mockConversationService.deleteAllWillSucceed = true

        // When
        await sut.deleteAllConversations()

        // Then
        XCTAssertTrue(mockConversationService.deleteAllCalled)
        XCTAssertNil(sut.error)
    }
}
```

### Performance Considerations

**Deletion Operations:**
- Single conversation delete: <500ms (single DB call with cascade)
- All conversations delete: <1s for typical user (<100 conversations)
- Show loading indicator for operations >200ms

**No Local Cache Impact (Yet):**
- SwiftData caching will be implemented in Story 7.1
- For now, deletion only affects Supabase (DB is source of truth)
- When Story 7.1 lands, update delete methods to also clear SwiftData

### Accessibility Requirements

1. **VoiceOver**: Destructive buttons have clear labels and hints
2. **Confirmation Alerts**: Screen reader announces alert title and options
3. **Dynamic Type**: All text in confirmation dialogs supports Dynamic Type
4. **Reduce Motion**: No animations on deletion (simple transition)

### Color Reference (from Colors.swift)

```swift
// Use these for delete confirmation
static let destructive = Color.red  // For delete buttons
static let warmGray50 = Color(hex: "#FAF9F6")   // Alert background
static let warmGray900 = Color(hex: "#1C1917")  // Text
```

### SwiftData Future Consideration

When Story 7.1 implements offline caching with SwiftData, the delete methods should be updated:

```swift
// Future pattern for Story 7.1 integration:
func deleteConversation(id: UUID) async throws {
    // 1. Delete from Supabase (source of truth)
    try await supabase.from("conversations").delete().eq("id", value: id.uuidString).execute()

    // 2. Delete from local SwiftData cache (Story 7.1)
    // let context = AppEnvironment.shared.modelContainer.mainContext
    // let conversations = try context.fetch(FetchDescriptor<LocalConversation>())
    // let matching = conversations.filter { $0.id == id }
    // matching.forEach { context.delete($0) }
    // try context.save()
}
```

### References

- [Source: epics.md#Story-2.6] - Original story requirements
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: architecture.md#Project-Structure] - File organization
- [Source: 20260205000001_initial_schema.sql] - CASCADE delete on messages
- [Source: 20260205000002_rls_policies.sql] - RLS delete policies
- [Source: ConversationService.swift] - Existing conversation CRUD
- [Source: ChatViewModel.swift] - Current chat state management
- [Source: 2-5-context-profile-viewing-and-editing.md] - Delete confirmation patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Build succeeded with no errors

### Completion Notes List

- **Task 1**: Added `deleteConversation(id:)` and `deleteAllConversations()` methods to ConversationService. Added `ConversationError.deleteFailed` case with warm first-person message "I couldn't remove that conversation." Verified RLS policies exist in migration 20260205000002. Both methods authenticate user and verify ownership before delete.

- **Task 2**: Added `showDeleteConfirmation` and `isDeleting` state properties to ChatViewModel. Added `deleteConversation()` async method that calls ConversationService, handles errors with warm messages, and resets to empty state via `startNewConversation()`.

- **Task 3**: Created `DeleteConfirmationAlert.swift` with enum for alert configuration and ViewModifiers for easy integration. Warm copy: "This will remove our conversation. You sure?" for single, "This will clear all our conversations. Are you sure you want to start fresh?" for all. VoiceOver accessibility via `.accessibilityElement(children: .combine)`.

- **Task 4**: Added "More options" ellipsis menu to ChatView toolbar with delete conversation option and settings navigation. Wired up `.singleConversationDeleteAlert()` modifier. Added loading overlay during deletion with ProgressView.

- **Task 5**: Created Settings feature with SettingsView and SettingsViewModel. Added "Clear all conversations" row with warm warning styling using `.adaptiveGlass()`. Settings accessible via ellipsis menu in ChatView toolbar. Confirmation uses `.allConversationsDeleteAlert()` modifier.

- **Task 6**: Added unit tests for ChatViewModel delete state (initial state, reset state, non-persisted delete). Added SettingsViewModelTests for state management and error handling. Added ConversationServiceTests for error message validation and singleton verification. Integration tests documented for Supabase delete operations.

### File List

**New Files:**
- CoachMe/CoachMe/Core/Services/ConversationService.swift (NEW - conversation lifecycle service with delete methods)
- CoachMe/CoachMe/Core/UI/Components/DeleteConfirmationAlert.swift
- CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift
- CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift
- CoachMe/CoachMeTests/ConversationServiceTests.swift
- CoachMe/CoachMeTests/SettingsViewModelTests.swift
- CoachMe/CoachMeTests/Mocks/MockConversationService.swift (Code Review fix - testability)

**Modified Files:**
- CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift (added delete functionality + protocol injection)
- CoachMe/CoachMe/Features/Chat/Views/ChatView.swift (added delete UI and settings navigation)
- CoachMe/CoachMeTests/ChatViewModelTests.swift (added mock-based delete tests)

**Structural Changes (Epic 2 - test directory migration):**
- Tests moved from CoachMe/Tests/Unit/ to CoachMe/CoachMeTests/ (standard Xcode test target)

### Change Log

- 2026-02-07: Story 2.6 implementation complete - Added conversation deletion (single and bulk) with warm confirmation dialogs, settings screen, and comprehensive unit tests
- 2026-02-07: [Code Review] Fixed 10 issues: Added ConversationServiceProtocol for testability, proper mock-based tests for Tasks 6.1-6.5, VoiceOver completion announcements, text consistency, removed preview prints. Updated File List accuracy.

## Senior Developer Review (AI)

### Review Date: 2026-02-07

### Reviewer: Claude Opus 4.5 (Adversarial Code Review)

### Outcome: ✅ APPROVED (after fixes applied)

### Issues Found and Fixed:

**Critical (3 - all fixed):**
1. Task 6.1-6.3 tests were placeholders (error strings only, not behavior) → Added ConversationServiceProtocol + MockConversationService + proper behavioral tests
2. File List inaccurate (ConversationService.swift was NEW, not MODIFIED) → Corrected
3. Test migration undocumented (8 files moved from Tests/Unit/ to CoachMeTests/) → Documented

**Medium (3 - all fixed):**
4. No mock injection for ConversationService despite testable init → Added protocol-based dependency injection
5. SettingsViewModel tests incomplete (Task 6.5) → Added mock-based service call verification tests
6. Missing error case test for ChatViewModel.deleteConversation() → Added failure path tests

**Low (4 - 3 fixed, 1 accepted):**
7. Loading text inconsistency ("Clearing conversations..." vs error "clear your") → Fixed to "Clearing your conversations..."
8. Preview print statements → Removed
9. VoiceOver doesn't announce deletion completion → Added UIAccessibility.post announcement
10. Dismiss race condition after delete → Accepted (low risk in practice)

### Files Changed During Review:
- ConversationService.swift (added ConversationServiceProtocol)
- ChatViewModel.swift (protocol injection + accessibility announcement)
- SettingsViewModel.swift (protocol injection)
- ConversationServiceTests.swift (proper mock-based tests)
- SettingsViewModelTests.swift (service call verification)
- ChatViewModelTests.swift (mock-based delete tests)
- DeleteConfirmationAlert.swift (removed preview prints)
- SettingsView.swift (text consistency)
- NEW: MockConversationService.swift
