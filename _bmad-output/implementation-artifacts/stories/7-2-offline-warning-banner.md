# Story 7.2: Offline Warning Banner

Status: review

## Story

As a **user who is offline**,
I want **a clear but warm warning when I lose connectivity**,
So that **I understand why I can't chat but don't feel frustrated**.

## Acceptance Criteria

1. **Given** I'm offline, **When** I'm on the chat screen, **Then** I see an adaptive banner: "You're offline right now. Your past conversations are here — new coaching needs a connection." (UX-10)
2. **Given** I'm offline, **When** I try to send a message, **Then** the send button is disabled with warm tooltip explaining why.
3. **Given** I'm offline and viewing the banner, **When** my connection restores, **Then** the banner dismisses automatically with a smooth animation.
4. **Given** I'm offline, **When** I view the banner on iOS 26+, **Then** it uses Liquid Glass styling via `.adaptiveGlass()`.
5. **Given** I'm offline, **When** I view the banner on iOS 18-25, **Then** it uses Warm Modern `.ultraThinMaterial` styling.
6. **Given** I'm offline, **When** VoiceOver is active, **Then** the banner is announced with appropriate accessibility labels and the send button disabled state is communicated.

## Tasks / Subtasks

- [x] Task 1: Create OfflineBanner.swift component (AC: #1, #3, #4, #5, #6)
  - [x] 1.1 Create `Features/Chat/Views/OfflineBanner.swift` with adaptive glass styling
  - [x] 1.2 Use warm first-person copy per UX-10/UX-11
  - [x] 1.3 Add enter/exit animation (`.transition(.move(edge: .top).combined(with: .opacity))`)
  - [x] 1.4 Add VoiceOver accessibility label
  - [x] 1.5 Support both light and dark mode with warm color palette
- [x] Task 2: Integrate OfflineBanner into ChatView (AC: #1, #3)
  - [x] 2.1 Add `@Environment` or direct reference to existing `NetworkMonitor.shared`
  - [x] 2.2 Place banner below toolbar, above message list (same slot pattern as TrialBanner)
  - [x] 2.3 Conditionally show banner when `!networkMonitor.isConnected`
  - [x] 2.4 Animate appearance/dismissal with `withAnimation`
- [x] Task 3: Disable send button when offline (AC: #2)
  - [x] 3.1 In `MessageInput.swift`, add `networkMonitor.isConnected` check to `canSend` computed property
  - [x] 3.2 Update accessibility hint to explain offline state
  - [x] 3.3 Optionally disable voice input button when offline (speech recognition requires network)
- [x] Task 4: Write unit tests (AC: all)
  - [x] 4.1 Test OfflineBanner renders correct text and styling
  - [x] 4.2 Test ChatView shows/hides banner based on network state
  - [x] 4.3 Test MessageInput `canSend` returns false when offline
  - [x] 4.4 Test banner dismisses when connection restores

## Dev Notes

### CRITICAL: DO NOT Recreate NetworkMonitor

**NetworkMonitor.swift ALREADY EXISTS** at:
`CoachMe/CoachMe/Core/Services/NetworkMonitor.swift`

It is a fully implemented `@MainActor @Observable` singleton using `NWPathMonitor`:
- Access via `NetworkMonitor.shared`
- Properties: `isConnected: Bool`, `isExpensive: Bool`
- Test-friendly: `init(isConnected: Bool, isExpensive: Bool)` for injecting state
- Already used by `VoiceInputViewModel` for network checks

**DO NOT create a new network monitor. USE the existing one.**

### Banner Design Pattern — Follow TrialBanner

Reference `Features/Subscription/Views/TrialBanner.swift` for the established banner pattern:
```swift
// Pattern from TrialBanner:
HStack(spacing: 12) {
    Image(systemName: "wifi.slash")  // Use wifi.slash for offline
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color.terracotta)

    VStack(alignment: .leading, spacing: 2) {
        Text("You're offline right now")
            .font(.subheadline.weight(.medium))
        Text("Your past conversations are here — new coaching needs a connection.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
.padding(.horizontal, 14)
.padding(.vertical, 10)
.adaptiveGlass()
.padding(.horizontal, 12)
.padding(.top, 4)
.transition(.move(edge: .top).combined(with: .opacity))
```

### ChatView Integration Point

In `ChatView.swift`, the banner should go in the same position as TrialBanner — below the toolbar, above the message list. Current layout structure:

```swift
VStack(spacing: 0) {
    // Toolbar area
    // TrialBanner (conditional)
    // → INSERT OfflineBanner HERE (conditional on !networkMonitor.isConnected)
    // Message list / Empty state
    // MessageInput
}
```

Only show ONE banner at a time — offline banner takes priority over trial banner (can't do anything without network).

### MessageInput Send Button Modification

In `MessageInput.swift`, the `canSend` computed property currently checks:
```swift
private var canSend: Bool {
    let textToCheck = voiceViewModel.transcribedText.isEmpty
        ? viewModel.inputText
        : voiceViewModel.transcribedText
    return !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           !viewModel.isLoading &&
           !voiceViewModel.isRecording
}
```

**Add** `&& networkMonitor.isConnected` to this check. MessageInput will need access to NetworkMonitor — pass it as a parameter or access via `NetworkMonitor.shared`.

Also update the accessibility hint:
```swift
.accessibilityHint(
    !networkMonitor.isConnected ? "You're offline. Sending requires a connection." :
    canSend ? "Sends your message to the coach" : "Type a message first"
)
```

### Voice Input Already Handles Offline

`VoiceInputViewModel` already checks `networkMonitor.isConnected` before starting recording (line ~77). No changes needed there, but the VoiceInputButton in MessageInput should also appear disabled when offline for visual consistency.

### Warm Copy Guidelines (UX-10, UX-11)

- Banner text: "You're offline right now. Your past conversations are here — new coaching needs a connection." (exact UX-10 spec)
- Error messages: first-person per UX-11 ("I couldn't..." not "Failed to...")
- ChatError.networkUnavailable already has: "I couldn't connect right now. Let's try again when you're back online."
- WarmErrorView.offline exists if needed for other screens

### Color & Styling Requirements

- Use `Color.terracotta` for the icon accent (warm, not alarming red)
- Use `Color.adaptiveText(colorScheme)` for text
- Use `.adaptiveGlass()` modifier (NOT raw `.glassEffect()`)
- Background: matches warm palette (`Color.adaptiveCream(colorScheme)` context)
- Both light and dark mode must feel warm (dark mode uses warm dark tones, NOT pure black)

### Animation Specifications

- Banner appear: `.transition(.move(edge: .top).combined(with: .opacity))`
- Wrap show/hide in `withAnimation(.easeInOut(duration: DesignConstants.Animation.standard))` (0.25s)
- Banner should NOT bounce or feel alarming — smooth, calm entrance/exit
- Match the coaching pace: gentle, grounded (UX principle #3)

### Accessibility Requirements (UX-12, UX-13)

- VoiceOver label on banner: "Offline notice. You're offline right now. Your past conversations are available. New coaching needs a connection."
- Dynamic Type: all text must scale with user's preferred text size
- Reduced Transparency: `.ultraThinMaterial` automatically handles this on iOS 18-25; Liquid Glass handles it on iOS 26+
- Send button disabled state must be announced to VoiceOver

### Architecture Compliance

| Requirement | Implementation |
|---|---|
| MVVM + Repository | OfflineBanner is a pure View; uses NetworkMonitor service |
| `@Observable` | NetworkMonitor already uses `@Observable` |
| Adaptive design | `.adaptiveGlass()` modifier — NEVER raw `.glassEffect()` |
| No glass on content | Banner is a navigation/status element — glass is appropriate |
| Warm error messages | First-person per UX-11 |
| VoiceOver | Accessibility labels on all interactive elements |
| Swift 6 concurrency | `@MainActor` on NetworkMonitor (already done) |
| No PII in logs | No user content logged |

### Existing Components to Reuse

| Component | Location | Usage |
|---|---|---|
| `NetworkMonitor` | `Core/Services/NetworkMonitor.swift` | Network state — **DO NOT recreate** |
| `TrialBanner` | `Features/Subscription/Views/TrialBanner.swift` | Layout/animation pattern reference |
| `WarmErrorView` | `Core/UI/Components/WarmErrorView.swift` | Has `.offline` preset if needed |
| `.adaptiveGlass()` | `Core/UI/Modifiers/AdaptiveGlassModifiers.swift` | Glass styling modifier |
| `DesignConstants` | `Core/UI/Theme/DesignConstants.swift` | Spacing, animation, corner radius tokens |
| `Colors` | `Core/UI/Theme/Colors.swift` | `.terracotta`, `.adaptiveCream()`, `.adaptiveText()` |
| `ChatError` | `Features/Chat/ViewModels/ChatError.swift` | `.networkUnavailable` case |

### Files to Create

| File | Path |
|---|---|
| `OfflineBanner.swift` | `CoachMe/CoachMe/Features/Chat/Views/OfflineBanner.swift` |

### Files to Modify

| File | Path | Change |
|---|---|---|
| `ChatView.swift` | `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` | Add OfflineBanner below toolbar |
| `MessageInput.swift` | `CoachMe/CoachMe/Features/Chat/Views/MessageInput.swift` | Add network check to `canSend` |

### Files to Create (Tests)

| File | Path |
|---|---|
| `OfflineBannerTests.swift` | `CoachMe/CoachMeTests/OfflineBannerTests.swift` |

### Project Structure Notes

- OfflineBanner lives in `Features/Chat/Views/` because it's specific to the chat experience
- If offline banners are needed on other screens later (History, Profile), refactor to `Core/UI/Components/`
- NetworkMonitor is already in `Core/Services/` — shared across features

### References

- [Source: architecture.md#Process-Patterns] — NetworkMonitor pattern with `NWPathMonitor`
- [Source: architecture.md#Frontend-Architecture] — MVVM + Repository, `@Observable` ViewModels
- [Source: architecture.md#Implementation-Patterns] — Adaptive design modifiers, anti-patterns
- [Source: epics.md#Story-7.2] — Story requirements and technical notes
- [Source: ux-design-specification.md#Offline-State] — UX-10 banner copy, emotional design for offline
- [Source: ux-design-specification.md#Emotional-Journey] — Offline: "Calm, informed" target emotion
- [Source: ux-design-specification.md#Error-States] — Warm, not alarming error presentation

## Dev Agent Record

### Agent Model Used

Claude Code

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- **Task 1**: Created `OfflineBanner.swift` following the established TrialBanner pattern. Uses `HStack` layout with `wifi.slash` icon in terracotta, warm first-person UX-10 copy, `.adaptiveGlass()` modifier for iOS 26+/18-25 adaptive styling, and comprehensive VoiceOver accessibility label. Includes light/dark mode previews.
- **Task 2**: Integrated OfflineBanner into ChatView with priority logic — offline banner shows instead of trial banner when `!networkMonitor.isConnected` (can't do anything without network). Added `NetworkMonitor.shared` reference and `.animation(.easeInOut)` keyed to `isConnected` for smooth transitions.
- **Task 3**: Added `&& networkMonitor.isConnected` to MessageInput's `canSend` computed property. Updated send button accessibility hint to explain offline state. Made VoiceInputButton disabled when offline (speech recognition requires network). Made `networkMonitor` injectable (`var` with `.shared` default) for testability.
- **Task 4**: Created 16 unit tests covering: banner instantiation, NetworkMonitor state management, MessageInput injection, VoiceInputButton offline disable logic, banner dismiss/appear on reconnect/disconnect, banner priority over trial banner, and canSend logic with all state combinations.

### Change Log

- 2026-02-09: Story 7.2 implementation — Offline warning banner with adaptive glass styling, ChatView integration with banner priority, send/voice button offline disable, and comprehensive unit tests.

### File List

#### New Files
- `CoachMe/CoachMe/Features/Chat/Views/OfflineBanner.swift` — Offline warning banner component
- `CoachMe/CoachMeTests/OfflineBannerTests.swift` — Unit tests for offline banner functionality

#### Modified Files
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — Added NetworkMonitor reference, offline banner with priority over trial banner, network state animation
- `CoachMe/CoachMe/Features/Chat/Views/MessageInput.swift` — Added NetworkMonitor injection, network check in canSend, offline accessibility hints, voice button offline disable
