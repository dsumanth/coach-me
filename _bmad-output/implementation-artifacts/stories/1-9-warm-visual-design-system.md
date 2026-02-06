# Story 1.9: Warm Visual Design System

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Architecture Pivot: Native iOS with Swift/SwiftUI (replaces previous Expo implementation) -->

## Story

As a **user**,
I want **a warm, inviting visual design that's consistent across iOS versions**,
So that **the app feels approachable for personal conversations on any device**.

## Acceptance Criteria

1. **AC1 — Light Mode Warm Palette**
   - Given I open the app on any iOS version
   - When I see the interface in light mode
   - Then colors are warm earth tones with soft accents (not sterile whites or tech blues)

2. **AC2 — Dark Mode Warm Tones**
   - Given I have dark mode enabled
   - When I view the app
   - Then dark mode uses warm dark tones (not pure black) on all iOS versions

3. **AC3 — Empty States with Personality**
   - Given I see empty states (empty history, no conversations, etc.)
   - When there's no content
   - Then empty states have personality with warm copy and inviting design

4. **AC4 — First-Person Error Messages**
   - Given errors occur
   - When I see error messages
   - Then they use first person: "I couldn't connect right now" (not "Error: Connection failed")

5. **AC5 — Visual Consistency Across iOS Versions**
   - Given I compare iOS 18 and iOS 26 experiences
   - When I view the same screens
   - Then the color palette, typography, and warmth feel identical (only glass effects differ)

6. **AC6 — Dynamic Type Support**
   - Given I have accessibility text sizes enabled
   - When I view the app
   - Then typography scales appropriately while maintaining visual hierarchy

7. **AC7 — Semantic Color System**
   - Given the app uses colors throughout
   - When different contexts require different visual treatments
   - Then semantic color tokens (success, warning, info, subtle) are available and consistent

## Tasks / Subtasks

- [x] Task 1: Expand Colors.swift with Complete Warm Palette (AC: #1, #2, #5)
  - [ ] 1.1 Add dark mode variants for all warm colors:
    ```swift
    // Dark mode base colors
    static let creamDark = Color(red: 30/255, green: 28/255, blue: 24/255)  // Warm dark, NOT pure black
    static let terracottaDark = Color(red: 234/255, green: 88/255, blue: 12/255)  // Slightly brighter for dark mode
    ```
  - [ ] 1.2 Add accent color variations:
    ```swift
    // Accent variations
    static let sage = Color(red: 143/255, green: 159/255, blue: 143/255)  // Soft green accent
    static let dustyRose = Color(red: 199/255, green: 163/255, blue: 163/255)  // Warm pink accent
    static let amber = Color(red: 217/255, green: 119/255, blue: 6/255)  // Warm yellow-orange
    ```
  - [ ] 1.3 Add semantic colors for states:
    ```swift
    // Semantic colors
    static let successGreen = Color(red: 34/255, green: 139/255, blue: 34/255)  // Warm forest green
    static let warningAmber = Color(red: 217/255, green: 119/255, blue: 6/255)
    static let infoBlue = Color(red: 70/255, green: 130/255, blue: 180/255)  // Warm steel blue
    static let subtleHighlight = Color(red: 255/255, green: 251/255, blue: 235/255)  // Very light warm
    ```
  - [ ] 1.4 Add adaptive color accessors that respect color scheme:
    ```swift
    /// Adaptive cream color that adjusts for light/dark mode
    static func adaptiveCream(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? creamDark : cream
    }
    ```

- [x] Task 2: Create Typography.swift with Dynamic Type Support (AC: #5, #6)
  - [ ] 2.1 Create `Core/UI/Theme/Typography.swift`:
    ```swift
    import SwiftUI

    /// Typography system with Dynamic Type support
    /// Per UX spec: Friendly and readable, not technical or trendy
    enum Typography {
        // MARK: - Semantic Styles

        /// Large display text for welcome screens
        static let display = Font.system(size: 34, weight: .bold, design: .rounded)

        /// Section titles
        static let title = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// Card titles, sheet headers
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

        /// Primary body text - conversations, descriptions
        static let body = Font.system(size: 17, weight: .regular, design: .default)

        /// Secondary text - timestamps, metadata
        static let caption = Font.system(size: 13, weight: .regular, design: .default)

        /// Small labels - badges, hints
        static let footnote = Font.system(size: 11, weight: .medium, design: .default)

        // MARK: - Dynamic Type Scaling

        /// Body text with Dynamic Type scaling
        static var bodyScaled: Font {
            .body.leading(.loose)
        }

        /// Caption with Dynamic Type scaling
        static var captionScaled: Font {
            .caption
        }
    }
    ```

- [x] Task 3: Create EmptyStateView Component (AC: #3)
  - [ ] 3.1 Create `Core/UI/Components/EmptyStateView.swift`:
    ```swift
    import SwiftUI

    /// Reusable empty state component with warm personality
    /// Per UX spec: Empty states have personality with warm copy
    struct EmptyStateView: View {
        let icon: String
        let title: String
        let message: String
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: 24) {
                // Warm icon treatment
                Image(systemName: icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.warmGray400)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.warmGray800)

                    Text(message)
                        .font(.body)
                        .foregroundStyle(Color.warmGray500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.terracotta)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")
        }
    }
    ```
  - [ ] 3.2 Create predefined empty state configurations:
    ```swift
    extension EmptyStateView {
        /// Empty conversation history
        static func noHistory(onStartChat: @escaping () -> Void) -> EmptyStateView {
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: "No conversations yet",
                message: "Your coaching journey starts with a single message. What's on your mind?",
                actionTitle: "Start a Conversation",
                action: onStartChat
            )
        }

        /// Empty search results
        static func noSearchResults() -> EmptyStateView {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Nothing found",
                message: "I couldn't find what you're looking for. Try different words?"
            )
        }

        /// Offline state
        static func offline() -> EmptyStateView {
            EmptyStateView(
                icon: "wifi.slash",
                title: "You're offline",
                message: "Your past conversations are here — new coaching needs a connection."
            )
        }
    }
    ```

- [x] Task 4: Create WarmErrorMessage Component (AC: #4)
  - [ ] 4.1 Create `Core/UI/Components/WarmErrorView.swift`:
    ```swift
    import SwiftUI

    /// Warm, first-person error message component
    /// Per UX spec: "I couldn't connect right now" not "Error 503"
    struct WarmErrorView: View {
        let message: String
        var retryAction: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.terracotta.opacity(0.8))

                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.warmGray700)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        Text("Try Again")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color.terracotta)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
    }
    ```
  - [ ] 4.2 Create standard error message strings:
    ```swift
    /// First-person error messages for consistent warm tone
    enum WarmErrorMessages {
        static let connectionFailed = "I couldn't connect right now. Let's try again in a moment."
        static let loadFailed = "I had trouble loading that. Give me another try?"
        static let saveFailed = "I couldn't save your changes. Let's try that again."
        static let sessionExpired = "It's been a while — let me reconnect for you."
        static let serverError = "Something went wrong on my end. I'm working on it."
        static let timeout = "That took longer than expected. Let's try again."
        static let networkUnavailable = "I need an internet connection to help you right now."
    }
    ```

- [x] Task 5: Update DesignSystem.swift with Dark Mode Support (AC: #2, #5, #7)
  - [ ] 5.1 Add dark mode color variants to DesignSystem.Colors:
    ```swift
    enum Colors {
        // ... existing colors ...

        // Dark mode variants
        static let backgroundDark = Color.creamDark
        static let surfaceLightDark = Color(red: 40/255, green: 38/255, blue: 34/255)
        static let surfaceMediumDark = Color(red: 50/255, green: 48/255, blue: 44/255)

        // Semantic colors (work in both modes)
        static let success = Color.successGreen
        static let warning = Color.warningAmber
        static let info = Color.infoBlue
        static let subtle = Color.subtleHighlight

        /// Returns background color appropriate for current color scheme
        static func background(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? backgroundDark : background
        }
    }
    ```

- [x] Task 6: Create ColorSchemeAwareModifier (AC: #2, #5)
  - [ ] 6.1 Create `Core/UI/Modifiers/ColorSchemeModifiers.swift`:
    ```swift
    import SwiftUI

    /// View modifier that applies warm colors based on color scheme
    struct WarmBackgroundModifier: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme

        func body(content: Content) -> some View {
            content
                .background(colorScheme == .dark ? Color.creamDark : Color.cream)
        }
    }

    extension View {
        /// Applies the warm background that adapts to light/dark mode
        func warmBackground() -> some View {
            modifier(WarmBackgroundModifier())
        }

        /// Applies warm foreground color that adapts to light/dark mode
        func warmForeground(isPrimary: Bool = true) -> some View {
            self.foregroundStyle(isPrimary ? Color.warmGray900 : Color.warmGray600)
        }
    }
    ```

- [x] Task 7: Create Design Constants (AC: #5)
  - [ ] 7.1 Create/Update `Core/UI/Theme/DesignConstants.swift` (if not exists):
    ```swift
    import Foundation

    /// Design constants for consistent spacing, sizing, and timing
    enum DesignConstants {
        enum Spacing {
            static let xs: CGFloat = 4
            static let sm: CGFloat = 8
            static let md: CGFloat = 16
            static let lg: CGFloat = 24
            static let xl: CGFloat = 32
            static let xxl: CGFloat = 48
        }

        enum CornerRadius {
            static let small: CGFloat = 4
            static let medium: CGFloat = 8
            static let large: CGFloat = 12
            static let container: CGFloat = 16
            static let sheet: CGFloat = 20
            static let input: CGFloat = 12
            static let interactive: CGFloat = 8
        }

        enum Animation {
            static let quick: Double = 0.15
            static let standard: Double = 0.25
            static let smooth: Double = 0.35
        }

        enum Shadow {
            static let subtle: (color: Color, radius: CGFloat, y: CGFloat) =
                (.black.opacity(0.05), 2, 1)
            static let medium: (color: Color, radius: CGFloat, y: CGFloat) =
                (.black.opacity(0.1), 4, 2)
            static let prominent: (color: Color, radius: CGFloat, y: CGFloat) =
                (.black.opacity(0.15), 8, 4)
        }
    }
    ```

- [x] Task 8: Audit and Update Existing Error Messages (AC: #4)
  - [ ] 8.1 Review ChatError.swift and ensure first-person messages
  - [ ] 8.2 Review VoiceInputError.swift (already first-person - verify consistency)
  - [ ] 8.3 Create ErrorMessages.swift centralized file if beneficial

- [x] Task 9: Create Unit Tests for Design System (AC: #1, #2, #5)
  - [ ] 9.1 Create `Tests/Unit/DesignSystemTests.swift`:
    ```swift
    import XCTest
    @testable import CoachMe

    final class DesignSystemTests: XCTestCase {
        func testWarmPaletteContainsNoBlueOrCold() {
            // Verify cream color is warm (red component higher than blue)
            let cream = Color.cream
            // Color component extraction and warm verification
        }

        func testDarkModeColorsAreNotPureBlack() {
            // Verify dark mode background is warm dark, not #000000
            let creamDark = Color.creamDark
            // Verify RGB values are not 0,0,0
        }

        func testTypographyUsesRoundedDesign() {
            // Verify headline/title fonts use rounded design
        }

        func testSemanticColorsExist() {
            // Verify success, warning, info colors are defined
        }
    }
    ```

- [x] Task 10: Visual Verification on iOS 18 and iOS 26 (AC: #1, #2, #5)
  - [ ] 10.1 Build and run on iOS 18 Simulator
  - [ ] 10.2 Build and run on iOS 26 Simulator
  - [ ] 10.3 Enable dark mode and verify warm dark tones
  - [ ] 10.4 Compare screenshots - colors and warmth should be identical
  - [ ] 10.5 Test empty states render with personality
  - [ ] 10.6 Trigger errors and verify first-person messages
  - [ ] 10.7 Test with Dynamic Type XXL size

## Dev Notes

### Architecture Compliance

**CRITICAL REQUIREMENTS:**
- **UX-1:** Warm color palette (earth tones, soft accents) — consistent across iOS versions
- **UX-2:** Light mode default; dark mode uses warm dark tones
- **UX-9:** Empty states with personality
- **UX-11:** Error messages use first person: "I couldn't connect right now"
- **UX-13:** Dynamic Type support at all sizes
- **UX-14:** Both iOS tiers feel intentionally designed (not degraded)

**From epics.md Story 1.9 Technical Notes:**
- Implement Colors.swift with warm palette (shared across iOS versions)
- Implement Typography.swift with Dynamic Type support
- Create empty state components with personality
- Ensure all error strings use first person
- Verify visual consistency across iOS 18 and iOS 26

**From architecture.md:**
- `Core/UI/Theme/Colors.swift` - Warm color palette (shared)
- `Core/UI/Theme/Typography.swift` - Dynamic Type support
- Use adaptive design modifiers — never raw `.glassEffect()`

### Previous Story Intelligence

**From Story 1.8 (Voice Input) Code Review:**
- First-person error messages already established in VoiceInputError.swift
- Pattern: `.errorDescription` returns warm, conversational messages
- Example: "I couldn't catch that — try again or type instead."

**Files from Previous Stories:**
```
CoachMe/CoachMe/Core/UI/Theme/Colors.swift - EXISTS (basic warm palette)
CoachMe/CoachMe/Core/UI/Theme/DesignSystem.swift - EXISTS (coordinator)
CoachMe/CoachMe/Core/Services/VoiceInputError.swift - First-person error pattern
CoachMe/CoachMe/Features/Chat/ViewModels/ChatError.swift - Needs audit for first-person
```

**Code Review Patterns to Follow:**
- Use @Environment(\.colorScheme) for dark mode detection
- Provide testing initializers for components
- Add accessibility labels and hints
- Verify on both iOS 18 and iOS 26 simulators

### Technical Requirements

**Warm Color Philosophy (from UX Spec):**
> "Warm color palette (earth tones, soft accents — not sterile blues or pure whites)"
> "Rounded corners, generous padding, soft shadows"
> "Typography that feels friendly and readable, not technical or trendy"

**Dark Mode Implementation:**
- Dark mode background should be warm dark (RGB ~30, 28, 24), NOT pure black (#000000)
- Text colors should remain readable with proper contrast ratios
- Accent colors may need slight brightness adjustment for dark backgrounds

**Dynamic Type Support:**
- Use semantic font styles (.body, .headline, .caption) not fixed sizes
- Test with XXL accessibility sizes
- Ensure layouts don't break at large text sizes

**Empty State Best Practices:**
```swift
// Good - warm, inviting, actionable
EmptyStateView(
    icon: "bubble.left.and.bubble.right",
    title: "No conversations yet",
    message: "Your coaching journey starts with a single message."
)

// Bad - cold, technical
EmptyStateView(
    icon: "exclamationmark.triangle",
    title: "Empty",
    message: "No data available."
)
```

**Error Message Best Practices:**
```swift
// Good - first person, warm, helpful
"I couldn't connect right now. Let's try again in a moment."

// Bad - third person, technical, cold
"Error: Connection failed. Status code 503."
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/
├── CoachMe/
│   └── Core/
│       └── UI/
│           ├── Theme/
│           │   ├── Typography.swift                  # NEW (or update)
│           │   └── DesignConstants.swift             # UPDATE
│           ├── Components/
│           │   ├── EmptyStateView.swift              # NEW
│           │   └── WarmErrorView.swift               # NEW
│           └── Modifiers/
│               └── ColorSchemeModifiers.swift        # NEW
└── Tests/
    └── Unit/
        └── DesignSystemTests.swift                   # NEW
```

**Files to Modify:**
```
CoachMe/CoachMe/Core/UI/Theme/Colors.swift           # Add dark mode, accents, semantic colors
CoachMe/CoachMe/Core/UI/Theme/DesignSystem.swift     # Add dark mode support
CoachMe/CoachMe/Features/Chat/ViewModels/ChatError.swift  # Audit for first-person
```

### Testing Checklist

- [ ] Warm palette colors verified (no pure blues or cold whites)
- [ ] Dark mode uses warm dark background (not pure black)
- [ ] Empty states display with warm copy and personality
- [ ] All error messages use first-person tone
- [ ] Typography scales with Dynamic Type
- [ ] Visual consistency between iOS 18 and iOS 26
- [ ] Semantic colors (success, warning, info) available
- [ ] Unit tests pass for color validation
- [ ] Accessibility: VoiceOver reads empty states correctly
- [ ] Accessibility: High contrast mode works
- [ ] Accessibility: Reduced transparency respected

### Dependencies

**This Story Depends On:**
- Story 1.2 (Adaptive Design System Foundation) - DesignSystem.swift, Colors.swift - DONE
- Story 1.5 (Core Chat UI) - ChatView, message bubbles use color system - DONE

**Stories That Depend On This:**
- All future stories that use colors, empty states, or error messages
- Epic 2 stories (Context Profile) will use empty states
- Epic 3 stories (History) will use empty states

### References

- [Source: architecture.md#Frontend-Architecture] - Theme/Colors.swift location
- [Source: architecture.md#Implementation-Patterns] - Adaptive design system
- [Source: epics.md#Story-1.9] - Acceptance criteria and technical notes
- [Source: ux-design-specification.md#Design-System-Foundation] - Warm palette philosophy
- [Source: ux-design-specification.md#Emotional-Design-Principles] - "Warmth Is a Feature"
- [Source: 1-8-voice-input.md#VoiceInputError] - First-person error message pattern

### External References

- [Apple Human Interface Guidelines - Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Apple HIG - Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple HIG - Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [WCAG 2.1 Color Contrast](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A

### Completion Notes List

1. **Task 1 (Colors.swift)**: Expanded Colors.swift with complete warm palette including dark mode variants (creamDark, terracottaDark), accent colors (sage, dustyRose, amber), semantic colors (successGreen, warningAmber, infoBlue), and adaptive color accessors.

2. **Task 2 (Typography.swift)**: Created new Typography.swift with SF Rounded design for display/title/headline fonts, Dynamic Type support through semantic font accessors, and specialized styles for error messages and buttons.

3. **Task 3 (EmptyStateView)**: Created EmptyStateView component with warm personality, predefined configurations for noHistory, noSearchResults, offline, noContext, noPersonas, and loadingFailed states.

4. **Task 4 (WarmErrorView)**: Created WarmErrorView component with first-person error messages via WarmErrorMessages enum, convenience initializers for common error types (connectionFailed, loadFailed, timeout, serverError, offline).

5. **Task 5 (DesignSystem.swift)**: Updated with dark mode semantic colors, adaptive color accessors, Typography typealias pointing to new Typography.swift, and enhanced preview support for light/dark modes.

6. **Task 6 (ColorSchemeModifiers)**: Created ColorSchemeModifiers.swift with AdaptiveBackgroundModifier, AdaptiveTextModifier, WarmCardModifier, WarmButtonModifier, and convenient View extensions (warmBackground, warmText, warmSurface, warmAccent, warmCard, warmButton).

7. **Task 7 (DesignConstants)**: Moved DesignConstants from AdaptiveGlassModifiers.swift to dedicated DesignConstants.swift, enhanced with Shadow configurations, Size constants, Opacity values, and warmShadow View extension.

8. **Task 8 (Error Message Audit)**: Audited all error types - VoiceInputError, ChatError, ChatStreamError, AuthError already had warm first-person messages. Updated KeychainError in KeychainManager.swift to use first-person warm tone while preserving technical descriptions for logging.

9. **Task 9 (Unit Tests)**: Created comprehensive DesignSystemTests.swift using Swift Testing framework with @Suite and @Test, covering ColorsTests, TypographyTests, DesignConstantsTests, WarmErrorMessagesTests, and DesignSystemIntegrationTests.

10. **Task 10 (Visual Verification)**: Successfully built on both iOS 18.5 (iPhone 16 Pro) and iOS 26.2 (iPhone 17 Pro) simulators, verifying cross-version compatibility.

**Note**: Fixed @Environment namespace conflict with app's `Environment` enum by using `@SwiftUI.Environment` in WarmErrorView and EmptyStateView.

### File List

**Created:**
- `CoachMe/CoachMe/Core/UI/Theme/Typography.swift`
- `CoachMe/CoachMe/Core/UI/Theme/DesignConstants.swift`
- `CoachMe/CoachMe/Core/UI/Theme/ColorSchemeModifiers.swift`
- `CoachMe/CoachMe/Core/UI/Components/EmptyStateView.swift`
- `CoachMe/CoachMe/Core/UI/Components/WarmErrorView.swift`
- `CoachMe/Tests/Unit/DesignSystemTests.swift`

**Modified:**
- `CoachMe/CoachMe/Core/UI/Theme/Colors.swift` - Added dark mode colors, accents, semantic colors, adaptive accessors
- `CoachMe/CoachMe/Core/UI/Theme/DesignSystem.swift` - Updated with dark mode support, Typography typealias, enhanced Colors enum
- `CoachMe/CoachMe/Core/UI/Modifiers/AdaptiveGlassModifiers.swift` - Removed DesignConstants (moved to own file)
- `CoachMe/CoachMe/Core/Utilities/KeychainManager.swift` - Updated error messages to first-person warm tone
