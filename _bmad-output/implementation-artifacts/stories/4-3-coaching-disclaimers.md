# Story 4.3: Coaching Disclaimers

Status: done

## Story

As a **user**,
I want **to understand that this is AI coaching, not therapy**,
so that **I have appropriate expectations and the product maintains proper liability boundaries**.

## Acceptance Criteria

1. **Given** I first open the app **When** I see the welcome screen **Then** there's a brief disclaimer: "AI coaching, not therapy or mental health treatment"
2. **Given** I review terms of service **When** I read the terms **Then** the therapeutic disclaimer is clearly stated
3. **Given** I open Settings **When** I scroll to the legal/about section **Then** I see a Terms of Service link and the coaching disclaimer text
4. **Given** I tap "Terms of Service" from Settings or WelcomeView **When** the link opens **Then** I am taken to the terms page in Safari
5. **Given** I use VoiceOver **When** navigating disclaimer content **Then** all text and links have proper accessibility labels and hints

## Tasks / Subtasks

- [x] Task 1: Create Features/Safety/ directory structure (AC: #1, #3)
  - [x] 1.1 Create `Features/Safety/Views/` directory
  - [x] 1.2 Create `DisclaimerView.swift` — reusable disclaimer component showing "AI coaching, not therapy or mental health treatment" text with Terms of Service link
  - [x] 1.3 Include full accessibility labels (`accessibilityLabel`, `accessibilityHint` on link)
- [x] Task 2: Add Legal/About section to SettingsView (AC: #3, #4)
  - [x] 2.1 Add a new "About" or "Legal" section below the Account section in `SettingsView.swift`
  - [x] 2.2 Include inline disclaimer text: "AI coaching, not therapy or mental health treatment"
  - [x] 2.3 Add "Terms of Service" row that opens `https://coachme.app/terms` via `Link` (same URL as WelcomeView)
  - [x] 2.4 Add "Privacy Policy" row that opens `https://coachme.app/privacy` via `Link`
  - [x] 2.5 Apply `.adaptiveGlass()` styling consistent with existing sections
  - [x] 2.6 Use `Color.adaptiveTerracotta(colorScheme)` for link text (adaptive version, consistent with SettingsView pattern)
- [x] Task 3: Verify WelcomeView disclaimer completeness (AC: #1, #2)
  - [x] 3.1 Confirm existing `disclaimerSection` in WelcomeView.swift meets FR19 requirements — already has "AI coaching, not therapy or mental health treatment" text + Terms of Service link (lines 117-133)
  - [x] 3.2 No changes needed; documented as pre-existing from Epic 1. Updated URL to use shared AppURLs constant.
- [x] Task 4: Write tests (AC: #1-#5)
  - [x] 4.1 Test DisclaimerView renders disclaimer text and link
  - [x] 4.2 Test SettingsView contains legal section with Terms of Service and Privacy Policy links
  - [x] 4.3 Test accessibility labels present on all disclaimer content

## Dev Notes

### What Already Exists (CRITICAL — Do NOT Recreate)

The welcome screen disclaimer is **already fully implemented** from Epic 1 (Story 1.9). The following code in `WelcomeView.swift` (lines 117-133) satisfies AC #1:

```swift
// In Features/Auth/Views/WelcomeView.swift
private var disclaimerSection: some View {
    VStack(spacing: 8) {
        Text("AI coaching, not therapy or mental health treatment")
            .font(.caption)
            .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.88))
            .multilineTextAlignment(.center)
        Link(destination: Self.termsOfServiceURL) {
            Text("View Terms of Service")
                .font(.caption)
                .foregroundColor(Color.terracotta)
        }
    }
}
```

The Terms of Service URL is defined as a static constant:
```swift
private static let termsOfServiceURL = URL(string: "https://coachme.app/terms")!
```

**The system prompt** in `prompt-builder.ts` already contains coaching boundary guardrails (lines 47-57):
- "Never diagnose, prescribe, or claim clinical expertise"
- "If users mention crisis indicators (self-harm, suicide), acknowledge their feelings and encourage professional help"
- "You are a coach, not a therapist"

These exist from earlier epics. **Do not modify or duplicate** these existing implementations.

### What Needs to Be Built

The **only new work** for this story is:

1. **`Features/Safety/Views/DisclaimerView.swift`** — A reusable disclaimer component per architecture. This creates the Safety feature directory that Stories 4.1 and 4.2 will also use.

2. **Legal section in `SettingsView.swift`** — Currently Settings only has Appearance, Data, and Account sections. FR19 requires the disclaimer to be accessible from settings too.

### Architecture Compliance

**Required directory structure** (from architecture.md):
```
Features/
└── Safety/
    ├── Views/
    │   ├── CrisisResourceSheet.swift  # Story 4.2 (future)
    │   └── DisclaimerView.swift       # THIS STORY
    └── Services/
        └── CrisisDetectionService.swift  # Story 4.1 (future)
```

Create the full `Features/Safety/Views/` path. Only create `DisclaimerView.swift` for now — other files belong to Stories 4.1 and 4.2.

### Design System Patterns to Follow

**Existing SettingsView section pattern** (reference `SettingsView.swift` lines 110-132 for the Appearance section):
```swift
private var legalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("About")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .padding(.horizontal, 4)

        VStack(spacing: 0) {
            // ... rows here ...
        }
        .adaptiveGlass()
    }
}
```

**Link styling pattern** (from WelcomeView `disclaimerSection`):
- Use `Link(destination:)` for external URLs
- Link text color: `Color.terracotta` (same as WelcomeView)
- Accessibility: `accessibilityLabel` + `accessibilityHint("Opens in Safari")`

**Color/theme patterns** (from `Colors.swift` and `DesignSystem.swift`):
- Background: `Color.adaptiveCream(colorScheme)`
- Text primary: `Color.adaptiveText(colorScheme)`
- Text secondary: `Color.adaptiveText(colorScheme, isPrimary: false)`
- Accent: `Color.terracotta` / `Color.adaptiveTerracotta(colorScheme)`
- Glass styling: `.adaptiveGlass()` on containers

**Warm copy guidelines (UX-11)**:
- First person: "I couldn't..." not "Failed to..."
- Error messages are opportunities to build trust
- All copy should feel warm, not clinical

### DisclaimerView Component Design

The DisclaimerView should be a simple, reusable SwiftUI view:
- Show the disclaimer text: "AI coaching, not therapy or mental health treatment"
- Optionally show the Terms of Service link
- Use `.caption` font, secondary text color with reduced opacity (matching WelcomeView)
- Full VoiceOver accessibility
- Can be embedded inline in other views (Settings, future onboarding screens)

### URL Constants

Extract the Terms of Service URL to a shared constant so both WelcomeView and SettingsView reference the same value. Either:
- Move to `Core/Constants/AppConstants.swift` if one exists, OR
- Create a shared constant in DisclaimerView and reference from both locations
- Currently WelcomeView has it as `private static let termsOfServiceURL`

### Testing Standards

Per project patterns:
- Use `@MainActor` on test classes for Swift 6 concurrency compliance
- Test view model logic, not SwiftUI rendering
- **DO NOT run tests automatically** — user will run tests manually
- After writing tests, tell user which specific test target to run

### Project Structure Notes

- Alignment: Creates `Features/Safety/` directory per architecture.md specification
- No conflicts: This is a new feature directory, no existing files affected
- SettingsView modification adds a new section — does not change existing sections

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 4.3 definition, lines 1037-1058]
- [Source: _bmad-output/planning-artifacts/architecture.md — Features/Safety/ directory structure]
- [Source: _bmad-output/planning-artifacts/architecture.md — Enforcement guidelines, anti-patterns]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Experience Principles: "Gentle Over Aggressive"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Error Copy Guidelines (UX-11)]
- [Source: CoachMe/Features/Auth/Views/WelcomeView.swift — Existing disclaimer implementation, lines 117-133]
- [Source: CoachMe/Features/Settings/Views/SettingsView.swift — Existing settings sections pattern]
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts — BASE_COACHING_PROMPT with coaching boundaries, lines 47-57]
- [Source: CoachMe/CoachMe/Core/UI/Theme/Colors.swift — Warm color palette]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build succeeded with zero errors on first attempt

### Completion Notes List

- Created `DisclaimerView.swift` as a reusable coaching disclaimer component with `AppURLs` enum for shared URL constants
- Added "About" legal section to `SettingsView.swift` with disclaimer text, Terms of Service link, and Privacy Policy link — all with `.adaptiveGlass()` styling and full VoiceOver accessibility
- Updated `WelcomeView.swift` to reference shared `AppURLs.termsOfService` instead of private URL constant (eliminates duplication)
- Verified existing WelcomeView disclaimer (Epic 1) already satisfies AC #1 and #2 — no changes needed
- All AC (#1–#5) satisfied: welcome disclaimer, ToS link, Settings legal section, Safari opening via `Link`, and VoiceOver accessibility labels/hints
- Tests written in `DisclaimerTests.swift` covering AppURLs validation, DisclaimerView instantiation, accessibility, and URL consistency

### Change Log

- 2026-02-08: Story 4.3 implementation complete — DisclaimerView, SettingsView legal section, shared AppURLs, tests

### File List

- `CoachMe/CoachMe/Features/Safety/Views/DisclaimerView.swift` (new)
- `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift` (modified — added legalSection)
- `CoachMe/CoachMe/Features/Auth/Views/WelcomeView.swift` (modified — updated to use shared AppURLs)
- `CoachMe/CoachMeTests/DisclaimerTests.swift` (new)
