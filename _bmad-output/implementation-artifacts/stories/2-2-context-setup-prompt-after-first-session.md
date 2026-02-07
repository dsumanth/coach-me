# Story 2.2: Context Setup Prompt After First Session

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to be asked if I want the coach to remember me after my first conversation**,
So that **I understand the value and can opt in**.

## Acceptance Criteria

1. **Given** I complete my first coaching exchange
   **When** the coach's response ends
   **Then** an adaptive sheet slides up asking "Want me to remember what matters to you?"

2. **Given** I tap "Yes, remember me"
   **When** the sheet transitions
   **Then** I see fields to add values, goals, and life situation

3. **Given** I tap "Not now"
   **When** I dismiss the sheet
   **Then** I continue chatting and am prompted again after session 3

## Tasks / Subtasks

- [x] Task 1: Create ContextPromptSheet View (AC: #1)
  - [x] 1.1 Create `ContextPromptSheet.swift` in `Features/Context/Views/`
  - [x] 1.2 Use `AdaptiveGlassContainer` for sheet background
  - [x] 1.3 Display warm prompt: "Want me to remember what matters to you?"
  - [x] 1.4 Add "Yes, remember me" primary button with `.adaptiveInteractiveGlass()`
  - [x] 1.5 Add "Not now" secondary button
  - [x] 1.6 Ensure VoiceOver accessibility labels on all interactive elements

- [x] Task 2: Create ContextSetupForm View (AC: #2)
  - [x] 2.1 Create `ContextSetupForm.swift` in `Features/Context/Views/`
  - [x] 2.2 Add text fields for values (what's important to you)
  - [x] 2.3 Add text fields for goals (what are you working toward)
  - [x] 2.4 Add text field for life situation (freeform description)
  - [x] 2.5 Add "Save" button to persist context profile
  - [x] 2.6 Add "Skip for now" to close without saving
  - [x] 2.7 Use warm, first-person placeholder text

- [x] Task 3: Create ContextPromptViewModel (AC: #1, #2, #3)
  - [x] 3.1 Create `ContextPromptViewModel.swift` in `Features/Context/ViewModels/`
  - [x] 3.2 Use `@Observable` pattern per architecture.md
  - [x] 3.3 Implement `shouldShowPrompt(profile:)` logic checking `firstSessionComplete` and `promptDismissedCount`
  - [x] 3.4 Implement `dismissPrompt()` to increment `promptDismissedCount`
  - [x] 3.5 Implement `saveInitialContext(values:goals:situation:)` method
  - [x] 3.6 Mark `firstSessionComplete = true` after first AI response

- [x] Task 4: Extend ContextRepository (AC: #1, #3)
  - [x] 4.1 Add `markFirstSessionComplete(userId:)` method
  - [x] 4.2 Add `incrementPromptDismissedCount(userId:)` method
  - [x] 4.3 Add `addInitialContext(userId:values:goals:situation:)` method
  - [x] 4.4 Update local cache after remote updates

- [x] Task 5: Integrate with ChatView (AC: #1, #3)
  - [x] 5.1 Add `@State private var showContextPrompt = false` to ChatView
  - [x] 5.2 After first AI response completes, check if prompt should show
  - [x] 5.3 Present `ContextPromptSheet` as `.sheet` modifier
  - [x] 5.4 Use smooth transition animation for sheet presentation
  - [x] 5.5 Handle sheet dismissal and state updates

- [x] Task 6: Write Unit Tests
  - [x] 6.1 Test `shouldShowPrompt` logic (first session, dismissal count)
  - [x] 6.2 Test prompt shows after first AI response
  - [x] 6.3 Test "Not now" increments `promptDismissedCount`
  - [x] 6.4 Test re-prompt after session 3 (dismissedCount >= 1 && messageCount >= threshold)
  - [x] 6.5 Test context save flow updates profile correctly
  - [x] 6.6 Test sheet transition from prompt to form

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1 & Story 2.1:**

1. **ViewModel Pattern**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel.swift`)
2. **Service Pattern**: Use singleton `@MainActor` services (like `ContextRepository.swift`)
3. **Supabase Access**: Always via `AppEnvironment.shared.supabase`
4. **Adaptive Design**: Use `.adaptiveGlass()` and `.adaptiveInteractiveGlass()` modifiers
5. **Error Handling**: Custom `LocalizedError` enums with first-person messages per UX-11

### Technical Requirements

**From UX Specification (UX-8):**
- Prompt copy: "Want me to remember what matters to you?"
- Warm, inviting tone throughout
- Sheet should feel like a natural pause, not an interruption

**Prompt Display Logic:**
```swift
// Show prompt when:
// 1. First AI response just completed (stream finished)
// 2. firstSessionComplete == false (never shown before)
// 3. OR promptDismissedCount >= 1 AND this is session 3+

func shouldShowPrompt(profile: ContextProfile, sessionCount: Int) -> Bool {
    if !profile.firstSessionComplete {
        return true  // First time ever
    }
    if profile.promptDismissedCount >= 1 && sessionCount >= 3 {
        return true  // Re-prompt after session 3
    }
    return false
}
```

**Existing Model Fields (from Story 2.1):**
```swift
// ContextProfile.swift already has:
var firstSessionComplete: Bool
var promptDismissedCount: Int
```

**Sheet Animation Pattern:**
```swift
// Use SwiftUI sheet with transition
.sheet(isPresented: $showContextPrompt) {
    ContextPromptSheet(
        onAccept: { showContextForm = true },
        onDismiss: {
            viewModel.dismissPrompt()
            showContextPrompt = false
        }
    )
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
}
```

**Adaptive Design for Sheet:**
```swift
struct ContextPromptSheet: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Want me to remember what matters to you?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("I can give you better coaching when I know what's important to you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("Yes, remember me") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .adaptiveInteractiveGlass()

                Button("Not now") {
                    onDismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .adaptiveGlass()
    }
}
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/CoachMe/Features/Context/
├── Views/
│   ├── ContextPromptSheet.swift      # NEW - Initial prompt sheet
│   └── ContextSetupForm.swift        # NEW - Values/goals/situation form
└── ViewModels/
    └── ContextPromptViewModel.swift  # NEW - Prompt display logic
```

**Files to Modify:**
```
CoachMe/CoachMe/Features/Chat/Views/ChatView.swift
  - Add sheet presentation for context prompt
  - Trigger after first AI response completion

CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift
  - Add callback/delegate for first response completion
  - Track session count for re-prompt logic

CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift
  - Add helper methods for prompt state management
```

### Previous Story Learnings (Story 2.1)

**Key Patterns Established:**
1. Use `@MainActor` for all services and ViewModels
2. Access Supabase via `AppEnvironment.shared.supabase`
3. Use `ContextProfileInsert` for minimal inserts (let server generate defaults)
4. Use `upsert()` for atomic race-safe operations
5. Fetch-all-and-filter pattern for SwiftData queries (Swift 6 Sendable compliance)
6. Error messages are warm, first-person (per UX-11)

**Code Review Fixes Applied:**
- Single ModelContainer in AppEnvironment (no duplication)
- Upsert pattern for profile creation (race-safe)
- Fetch after insert to get server-assigned values

### Testing Requirements

**Unit Tests to Create:**
```swift
// CoachMeTests/Features/Context/ContextPromptViewModelTests.swift
final class ContextPromptViewModelTests: XCTestCase {
    func testShouldShowPromptFirstSession()
    func testShouldShowPromptAfterDismissal()
    func testShouldNotShowPromptIfContextExists()
    func testDismissIncrementsCount()
    func testAcceptMarksSessionComplete()
}

// CoachMeTests/Features/Context/ContextPromptSheetTests.swift
final class ContextPromptSheetTests: XCTestCase {
    func testSheetAccessibilityLabels()
    func testYesButtonCallsOnAccept()
    func testNotNowButtonCallsOnDismiss()
}
```

### References

- [Source: epics.md#Story-2.2] - Original story requirements
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: architecture.md#Adaptive-Design-System] - Glass effect modifiers
- [Source: ux-design-specification.md#UX-8] - Context prompt copy and timing
- [Source: 2-1-context-profile-data-model-and-storage.md] - Previous story learnings
- [Source: ContextProfile.swift] - Existing model with firstSessionComplete, promptDismissedCount
- [Source: ContextRepository.swift] - Repository pattern reference

### Web Research Notes

**SwiftUI Sheet Presentation (iOS 18+):**
- Use `.presentationDetents([.medium, .large])` for partial sheet heights
- Use `.presentationDragIndicator(.visible)` for swipe-to-dismiss affordance
- Use `.interactiveDismissDisabled()` if user must make a choice
- SwiftUI automatically handles keyboard avoidance in sheets

**Adaptive Glass in Sheets:**
- Sheets already have translucent background on iOS 26+
- Use `.adaptiveGlass()` on content container, not sheet itself
- Test on both iOS 18 (material fallback) and iOS 26 (Liquid Glass)

**Accessibility for Modal Sheets:**
- Announce sheet presentation with `.accessibilityAddTraits(.isModal)`
- Focus first interactive element on presentation
- Provide clear dismiss affordance (button or swipe indicator)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- Implemented ContextPromptSheet with warm prompt copy per UX-8
- Implemented ContextSetupForm with values/goals/situation fields
- Created ContextPromptViewModel with @Observable pattern
- Extended ContextRepository with Story 2.2 methods
- Integrated with ChatView using .onChange(of: viewModel.isStreaming)
- Added comprehensive unit tests (18 tests across 2 test files)
- Added VoiceOver accessibility labels on all interactive elements

### File List

**Created:**
- `CoachMe/CoachMe/Features/Context/Views/ContextPromptSheet.swift` - Initial context prompt sheet
- `CoachMe/CoachMe/Features/Context/Views/ContextSetupForm.swift` - Values/goals/situation form
- `CoachMe/CoachMe/Features/Context/ViewModels/ContextPromptViewModel.swift` - Prompt display logic
- `CoachMe/CoachMeTests/ContextPromptViewModelTests.swift` - ViewModel unit tests
- `CoachMe/CoachMeTests/ContextPromptAccessibilityTests.swift` - Accessibility tests

**Modified:**
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` - Added sheet presentations and onChange trigger
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` - Added Story 2.2 methods
