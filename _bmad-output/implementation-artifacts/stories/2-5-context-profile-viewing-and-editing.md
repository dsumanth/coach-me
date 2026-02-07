# Story 2.5: Context Profile Viewing & Editing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to see and edit what the coach knows about me**,
So that **I have full control over my data**.

## Acceptance Criteria

1. **Given** I tap my profile (or navigate to Profile tab)
   **When** the profile view opens
   **Then** I see my values, goals, and situation in an organized layout with warm framing

2. **Given** I want to edit a value
   **When** I tap the item or edit icon
   **Then** an adaptive inline editor or sheet allows me to modify the text

3. **Given** I want to remove something
   **When** I tap delete on an item
   **Then** a warm confirmation appears and it's removed after I confirm

4. **Given** I have no context yet
   **When** I view my profile
   **Then** I see a warm empty state with personality that invites me to add context

5. **Given** I edit or delete context
   **When** the action completes
   **Then** changes sync to Supabase and update the local SwiftData cache

## Tasks / Subtasks

- [x] Task 1: Create ContextProfileView.swift (AC: #1, #4)
  - [x] 1.1 Create `ContextProfileView.swift` in `Features/Context/Views/`
  - [x] 1.2 Display values section with `ContextCard` styling per UX spec
  - [x] 1.3 Display goals section with active/completed grouping if applicable
  - [x] 1.4 Display life situation section (freeform text)
  - [x] 1.5 Use "Here's how I see you" warm framing header per UX-spec
  - [x] 1.6 Add warm empty state with personality when no context exists
  - [x] 1.7 Apply `.adaptiveGlass()` to section containers (not content)
  - [x] 1.8 Add VoiceOver accessibility labels on all interactive elements
  - [x] 1.9 Test on both iOS 18 and iOS 26 simulators

- [x] Task 2: Create ContextViewModel.swift (AC: #2, #3, #5)
  - [x] 2.1 Create `ContextViewModel.swift` in `Features/Context/ViewModels/`
  - [x] 2.2 Use `@Observable` pattern (not @ObservableObject) per architecture
  - [x] 2.3 Add `loadProfile(userId:)` method that calls ContextRepository
  - [x] 2.4 Add state properties: `profile: ContextProfile?`, `isLoading`, `error: ContextError?`
  - [x] 2.5 Add `updateValue(id:, newContent:)` method
  - [x] 2.6 Add `deleteValue(id:)` method with confirmation handling
  - [x] 2.7 Add `updateGoal(id:, newContent:)` method
  - [x] 2.8 Add `deleteGoal(id:)` method with confirmation handling
  - [x] 2.9 Add `updateSituation(newContent:)` method
  - [x] 2.10 Handle optimistic UI updates with rollback on error

- [x] Task 3: Create ContextEditorSheet.swift (AC: #2)
  - [x] 3.1 Create `ContextEditorSheet.swift` in `Features/Context/Views/`
  - [x] 3.2 Use `.adaptiveGlassSheet()` modifier for presentation
  - [x] 3.3 Create editor for value items (single text field)
  - [x] 3.4 Create editor for goal items (content + optional status toggle)
  - [x] 3.5 Create editor for situation (multiline text)
  - [x] 3.6 Add "Save" and "Cancel" buttons with warm styling
  - [x] 3.7 Auto-focus text field on sheet appear
  - [x] 3.8 Add `.accessibilityAddTraits(.isModal)` for accessibility

- [x] Task 4: Create ContextItemRow.swift component (AC: #1, #2, #3)
  - [x] 4.1 Create `ContextItemRow.swift` in `Features/Context/Views/`
  - [x] 4.2 Display item content with edit and delete actions
  - [x] 4.3 Use swipe-to-delete gesture as alternative to button
  - [x] 4.4 Add subtle edit icon that appears on tap (or always visible)
  - [x] 4.5 Apply warm color palette (warmGray text, warmGold accents)
  - [x] 4.6 VoiceOver: "Value: [content]. Double tap to edit. Swipe left to delete."

- [x] Task 5: Create DeleteConfirmationAlert (AC: #3)
  - [x] 5.1 Create warm confirmation alert for deletion
  - [x] 5.2 Use first-person copy per UX-11: "Remove this from your profile?"
  - [x] 5.3 Primary action: "Remove" (destructive)
  - [x] 5.4 Secondary action: "Keep it" (cancel)

- [x] Task 6: Wire up navigation and profile access
  - [x] 6.1 Add Profile tab or navigation entry point (if not existing)
  - [x] 6.2 Pass authenticated userId to ContextProfileView
  - [x] 6.3 Ensure profile loads on view appear
  - [x] 6.4 Handle loading state with skeleton or spinner

- [x] Task 7: Write Unit Tests
  - [x] 7.1 Test ContextViewModel.loadProfile() success and failure
  - [x] 7.2 Test ContextViewModel.updateValue() updates profile and syncs
  - [x] 7.3 Test ContextViewModel.deleteValue() removes item and syncs
  - [x] 7.4 Test ContextViewModel.updateGoal() updates profile and syncs
  - [x] 7.5 Test ContextViewModel.deleteGoal() removes item and syncs
  - [x] 7.6 Test ContextViewModel.updateSituation() updates and syncs
  - [x] 7.7 Test optimistic update rollback on error
  - [x] 7.8 Test empty profile state handling

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1 & Stories 2.1-2.4:**

1. **ViewModel Pattern**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel.swift`, `ContextPromptViewModel.swift`)
2. **Service Pattern**: Use singleton `@MainActor` services and repositories
3. **Repository Access**: Use `ContextRepository.shared` for all profile operations
4. **Supabase Access**: Always via `AppEnvironment.shared.supabase` (already in ContextRepository)
5. **Adaptive Design**: Use `.adaptiveGlass()` for containers, `.adaptiveInteractiveGlass()` for buttons
6. **Error Handling**: Use `ContextError` enum with first-person messages per UX-11
7. **SwiftData**: Use fetch-all-and-filter pattern for predicates (Swift 6 Sendable compliance)

### Technical Requirements

**From PRD (FR14):**
> Users can view, edit, and delete any part of their context profile

**From UX Design Spec:**
> Profile editing is inline and warm — edit values/goals in place, not in a buried settings screen
> The context profile screen feels like a mirror, not a dossier — warm framing, editable, transparent
> Frame it as "here's how I see you — correct me anytime" rather than "here's what I've collected"

**From UX - ContextCard Component Spec:**
```
Purpose: Display and edit context profile sections (values, goals, situation)

Visual:
- Surface-elevated background
- Rounded-xl
- Section header: text-sm, text-muted, uppercase, letter-spacing
- Items: flex row, label + value, editable on tap

States: View mode, Edit mode (inline input appears)
Sections: Values, Goals, Current Focus, Life Situation
Behavior: Tap item → inline edit → save on blur or enter
```

**From UX - Inline Editing Pattern:**
```
Pattern: Tap to edit, auto-save on blur

| State    | Behavior                                    |
|----------|---------------------------------------------|
| View     | Value displayed as text, edit icon subtle   |
| Edit     | Input appears in place, keyboard opens      |
| Saving   | Brief loading indicator, input disabled     |
| Saved    | Checkmark flash, return to view state       |
| Error    | Shake animation, error message below        |

Implementation:
- No "Edit" / "Save" button flow — tap the value itself
- Auto-save after 500ms of inactivity or on blur
- Optimistic UI — show change immediately, revert on error
```

### Key Design Principles

- Profile view feels like a **mirror**, not a dossier
- **Warm framing**: "Here's how I see you — correct me anytime"
- **Inline editing** preferred, with adaptive sheet as fallback for complex edits
- **Optimistic UI**: Show changes immediately, revert on error
- **Transparent**: User knows exactly what's stored and can edit/delete anything

### Existing Code to Leverage

**ContextProfile Model (already has mutation helpers):**
```swift
// From Features/Context/Models/ContextProfile.swift
struct ContextProfile: Identifiable, Codable, Sendable, Equatable {
    var values: [ContextValue]
    var goals: [ContextGoal]
    var situation: ContextSituation
    var extractedInsights: [ExtractedInsight]

    // Already has these mutation helpers:
    mutating func addValue(_ value: ContextValue)
    mutating func addGoal(_ goal: ContextGoal)
    mutating func removeValue(id: UUID)
    mutating func removeGoal(id: UUID)

    var hasContext: Bool  // Check if profile has any content
    var activeGoals: [ContextGoal]  // Filter active goals
}
```

**ContextRepository (already has full CRUD):**
```swift
// From Core/Data/Repositories/ContextRepository.swift
@MainActor
protocol ContextRepositoryProtocol {
    func fetchProfile(userId: UUID) async throws -> ContextProfile
    func updateProfile(_ profile: ContextProfile) async throws
    func deleteProfile(userId: UUID) async throws
    // ... plus insight methods from Story 2.3
}
```

**ContextValue Model:**
```swift
// From Features/Context/Models/ContextValue.swift
struct ContextValue: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var content: String
    let source: ContextSource  // .user or .extracted
    var createdAt: Date

    static func userValue(_ content: String) -> ContextValue
}
```

**ContextGoal Model:**
```swift
// From Features/Context/Models/ContextGoal.swift
struct ContextGoal: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var content: String
    var status: GoalStatus  // .active, .completed, .paused
    let source: ContextSource
    var createdAt: Date

    static func userGoal(_ content: String) -> ContextGoal
}
```

**ContextSituation Model:**
```swift
// From Features/Context/Models/ContextSituation.swift
struct ContextSituation: Codable, Sendable, Equatable {
    var freeform: String?
    var hasContent: Bool { freeform != nil && !freeform!.isEmpty }
    static var empty: ContextSituation
}
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/CoachMe/Features/Context/
├── Views/
│   ├── ContextProfileView.swift      # NEW - Main profile display
│   ├── ContextEditorSheet.swift      # NEW - Adaptive editor sheet
│   └── ContextItemRow.swift          # NEW - Reusable item row with edit/delete
└── ViewModels/
    └── ContextViewModel.swift        # NEW - Profile view/edit state management

CoachMeTests/
└── ContextViewModelTests.swift       # NEW - Unit tests for ViewModel
```

**Files to Reference (already exist):**
```
CoachMe/CoachMe/Features/Context/
├── Models/
│   ├── ContextProfile.swift          # EXISTING - Has mutation helpers
│   ├── ContextValue.swift            # EXISTING
│   ├── ContextGoal.swift             # EXISTING
│   ├── ContextSituation.swift        # EXISTING
│   └── ExtractedInsight.swift        # EXISTING
├── ViewModels/
│   └── ContextPromptViewModel.swift  # EXISTING - Reference for patterns
└── Views/
    ├── ContextPromptSheet.swift      # EXISTING - Reference adaptive sheet
    ├── ContextSetupForm.swift        # EXISTING - Reference form patterns
    └── InsightSuggestionCard.swift   # EXISTING - Reference card patterns

CoachMe/CoachMe/Core/Data/Repositories/
└── ContextRepository.swift           # EXISTING - Full CRUD operations
```

### Previous Story Learnings (Stories 2.1-2.4)

**Key Patterns from Story 2.4 Code Review:**

1. **@Observable ViewModel pattern:**
```swift
@Observable
@MainActor
final class ContextViewModel {
    var profile: ContextProfile?
    var isLoading = false
    var error: ContextError?

    private let repository: ContextRepositoryProtocol

    init(repository: ContextRepositoryProtocol = ContextRepository.shared) {
        self.repository = repository
    }
}
```

2. **Optimistic UI with rollback:**
```swift
func updateValue(id: UUID, newContent: String) async {
    guard var profile = profile else { return }

    // Optimistic update
    let originalProfile = profile
    if let index = profile.values.firstIndex(where: { $0.id == id }) {
        profile.values[index].content = newContent
        self.profile = profile
    }

    do {
        try await repository.updateProfile(profile)
    } catch {
        // Rollback on error
        self.profile = originalProfile
        self.error = error as? ContextError ?? .saveFailed(error.localizedDescription)
    }
}
```

3. **Adaptive sheet presentation:**
```swift
.sheet(isPresented: $showEditor) {
    ContextEditorSheet(item: selectedItem, onSave: handleSave)
        .adaptiveGlassSheet()
        .accessibilityAddTraits(.isModal)
}
```

4. **Warm error messages (UX-11):**
```swift
// Already in ContextError enum:
case saveFailed(let reason):
    return "I couldn't save your context. \(reason)"
```

5. **VoiceOver accessibility:**
```swift
.accessibilityLabel("Value: \(value.content)")
.accessibilityHint("Double tap to edit. Swipe left to delete.")
```

### Git Intelligence (Recent Commits)

```
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Stories 2.1-2.4 added context profile data model, storage, progressive extraction, and context injection. Story 2.5 builds the user-facing view/edit UI.

### Testing Requirements

**Unit Tests to Create (CoachMeTests/ContextViewModelTests.swift):**

```swift
final class ContextViewModelTests: XCTestCase {
    var sut: ContextViewModel!
    var mockRepository: MockContextRepository!

    override func setUp() {
        mockRepository = MockContextRepository()
        sut = ContextViewModel(repository: mockRepository)
    }

    // MARK: - Load Profile Tests

    func testLoadProfileSuccess() async {
        // Given a profile exists
        mockRepository.profileToReturn = .testProfile()

        // When loading
        await sut.loadProfile(userId: UUID())

        // Then profile is set and not loading
        XCTAssertNotNil(sut.profile)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testLoadProfileFailure() async {
        // Given repository throws error
        mockRepository.errorToThrow = .notFound

        // When loading
        await sut.loadProfile(userId: UUID())

        // Then error is set
        XCTAssertNil(sut.profile)
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Update Value Tests

    func testUpdateValueSuccess() async {
        // Given profile with values
        sut.profile = .testProfile(values: [.testValue(id: testId)])

        // When updating value
        await sut.updateValue(id: testId, newContent: "Updated")

        // Then value is updated and repository called
        XCTAssertEqual(sut.profile?.values.first?.content, "Updated")
        XCTAssertTrue(mockRepository.updateProfileCalled)
    }

    func testUpdateValueRollbackOnError() async {
        // Given profile and repository will fail
        sut.profile = .testProfile(values: [.testValue(content: "Original")])
        mockRepository.errorToThrow = .saveFailed("Network error")

        // When updating value
        await sut.updateValue(id: testId, newContent: "New")

        // Then original value restored
        XCTAssertEqual(sut.profile?.values.first?.content, "Original")
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Delete Tests

    func testDeleteValueSuccess() async {
        // Given profile with values
        let valueId = UUID()
        sut.profile = .testProfile(values: [.testValue(id: valueId)])

        // When deleting
        await sut.deleteValue(id: valueId)

        // Then value removed
        XCTAssertTrue(sut.profile?.values.isEmpty ?? false)
        XCTAssertTrue(mockRepository.updateProfileCalled)
    }

    // ... similar tests for goals and situation
}
```

### Performance Considerations

**Profile Loading:**
- Target: <500ms for profile load and display
- Use existing ContextRepository caching (SwiftData local cache)
- Show skeleton loading state during fetch

**Edit Operations:**
- Optimistic UI: Show changes immediately
- Debounce auto-save by 500ms per UX spec
- Rollback on error with shake animation

### Color Reference (from Colors.swift)

```swift
// Use these for profile view
static let warmGray50 = Color(hex: "#FAF9F6")   // Background
static let warmGray900 = Color(hex: "#1C1917")  // Primary text
static let warmGold = Color(hex: "#B8860B")     // Accents, edit icons
static let coachOlive = Color(hex: "#808000")   // Section headers
```

### Accessibility Requirements

1. **VoiceOver**: All items have descriptive labels and hints
2. **Dynamic Type**: Support all text sizes
3. **Reduce Motion**: No decorative animations when enabled
4. **High Contrast**: Ensure sufficient contrast ratios
5. **Delete Confirmation**: Alert is screen reader accessible

### References

- [Source: epics.md#Story-2.5] - Original story requirements
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: architecture.md#Project-Structure] - File organization
- [Source: ux-design-specification.md#ContextCard] - Component design spec
- [Source: ux-design-specification.md#Inline-Editing] - Edit pattern spec
- [Source: ContextProfile.swift] - Existing model with mutation helpers
- [Source: ContextRepository.swift] - Existing CRUD operations
- [Source: 2-4-context-injection-into-coaching-responses.md] - Previous story patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

None - implementation proceeded without blocking issues.

### Completion Notes List

1. **ContextViewModel.swift** - Created with full CRUD operations using `@Observable` pattern, optimistic UI with rollback on error
2. **ContextItemRow.swift** - Reusable row component with swipe-to-delete, tap-to-edit, VoiceOver accessibility
3. **ContextEditorSheet.swift** - Adaptive editor sheet with auto-focus, supports values/goals/situation
4. **ContextProfileView.swift** - Main profile view with warm framing, empty states, sections for values/goals/situation
5. **ChatView.swift** - Added profile button to toolbar and sheet navigation to ContextProfileView
6. **ContextPromptViewModel.swift** - Exposed userId as `private(set)` for navigation
7. **ContextViewModelTests.swift** - Comprehensive unit tests for all ViewModel operations

### File List

**Created:**
- `CoachMe/CoachMe/Features/Context/ViewModels/ContextViewModel.swift`
- `CoachMe/CoachMe/Features/Context/Views/ContextProfileView.swift`
- `CoachMe/CoachMe/Features/Context/Views/ContextItemRow.swift`
- `CoachMe/CoachMe/Features/Context/Views/ContextEditorSheet.swift`
- `CoachMe/CoachMeTests/ContextViewModelTests.swift`

**Modified:**
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` (added profile button and navigation)
- `CoachMe/CoachMe/Features/Context/ViewModels/ContextPromptViewModel.swift` (exposed userId)
