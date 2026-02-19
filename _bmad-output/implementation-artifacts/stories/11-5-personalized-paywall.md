# Story 11.5: Personalized Paywall

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the paywall to reflect what the coach learned about me during discovery**,
So that **the subscription feels like continuing a meaningful conversation, not buying a generic app**.

## Acceptance Criteria

1. **Given** the discovery conversation is complete, **When** the paywall appears as an overlay in ChatView, **Then** the header dynamically references my coaching domain: "Your coach understands your [domain]. Ready to keep going?" (e.g., "Your coach understands your career journey. Ready to keep going?"). If no domain was extracted, the fallback is "Your coach gets you. Ready for more?"

2. **Given** the AI extracted a key theme or aha insight during discovery, **When** the paywall body copy is rendered, **Then** it references the insight: "You've already taken the hardest step — getting honest about [their theme]. Let's keep building on that." If no theme was extracted, fallback copy is used: "You've already started something meaningful. Let's keep going."

3. **Given** the paywall is displayed immediately after discovery (first presentation), **When** the user sees the screen, **Then** the coach's last message (containing the aha insight/summary) remains visible behind a semi-transparent overlay (`.background(.ultraThinMaterial)` with ~0.85 opacity), reinforcing emotional continuity.

4. **Given** the paywall shows subscription options, **When** RevenueCat offerings load successfully, **Then** the user sees the available packages with localized pricing from RevenueCat (introductory offer if configured). The CTA reads "Continue my coaching journey" (NOT "Subscribe" or "Start trial").

5. **Given** the user taps "Continue my coaching journey", **When** the StoreKit purchase completes successfully, **Then** the paywall overlay dismisses, the chat resumes in the same conversation, and the coach's first paid message continues naturally (referencing discovery context via Story 11.4's prompt injection).

6. **Given** the user dismisses the personalized paywall without subscribing, **When** they return to the app later or try to send a message, **Then** they see a return-variant paywall with modified copy: "Your coach is still here. Pick up where you left off." with the same subscription options — presented as a full-screen paywall (not overlay, since there's no chat context behind it).

7. **Given** RevenueCat offerings fail to load or no packages are available, **When** the paywall is displayed, **Then** a warm fallback message appears: "I'm having trouble loading subscription options. Please check your connection and try again." with a "Try again" button that re-fetches offerings.

## Tasks / Subtasks

- [x] Task 1: Create PersonalizedPaywallView (AC: #1, #2, #3, #4, #7)
  - [x]1.1 Create `Features/Subscription/Views/PersonalizedPaywallView.swift` — `@MainActor` SwiftUI View
  - [x]1.2 Define `PaywallPresentation` enum: `.firstPresentation(discoveryContext: DiscoveryPaywallContext)` and `.returnPresentation(discoveryContext: DiscoveryPaywallContext?)`
  - [x]1.3 Create `DiscoveryPaywallContext` struct: `coachingDomain: String?`, `ahaInsight: String?`, `keyTheme: String?`, `userName: String?`
  - [x]1.4 Implement personalized header: use `discoveryContext.coachingDomain` for "Your coach understands your [domain]. Ready to keep going?" — fallback: "Your coach gets you. Ready for more?"
  - [x]1.5 Implement personalized body: use `discoveryContext.ahaInsight` or `discoveryContext.keyTheme` for contextual copy — fallback: "You've already started something meaningful. Let's keep going."
  - [x]1.6 Display RevenueCat packages from `subscriptionViewModel.availablePackages` using `PackageRow` pattern from existing PaywallView
  - [x]1.7 CTA button: "Continue my coaching journey" — styled with `Color.terracotta` filled capsule, 44pt height, full width
  - [x]1.8 "Not now" dismiss button — `.returnPresentation` shows as toolbar button; `.firstPresentation` shows as secondary text button below CTA
  - [x]1.9 Restore purchases link below packages (same pattern as PaywallView)
  - [x]1.10 Legal fine print about Apple subscription management (reuse from PaywallView)
  - [x]1.11 Loading overlay during purchase (semi-transparent with ProgressView — same pattern as PaywallView)
  - [x]1.12 Error display for purchase failures: warm first-person message below packages (same pattern as PaywallView `purchaseError`)
  - [x]1.13 Offerings failure state: "I'm having trouble loading subscription options. Please check your connection and try again." with retry button
  - [x]1.14 Use adaptive design: `.adaptiveGlass()` for card elements, `Color.adaptiveCream` background, `Color.terracotta` accent, `Color.adaptiveText` for typography
  - [x]1.15 Full accessibility: VoiceOver labels on all interactive elements, Dynamic Type support, reduced motion handling

- [x] Task 2: Create PersonalizedPaywallViewModel (AC: #1, #2, #6)
  - [x]2.1 Create `Features/Subscription/ViewModels/PersonalizedPaywallViewModel.swift` — `@MainActor @Observable final class`
  - [x]2.2 Properties: `presentation: PaywallPresentation`, `discoveryContext: DiscoveryPaywallContext`
  - [x]2.3 Computed properties: `headerText: String` (dynamic based on context), `bodyText: String` (dynamic based on context), `ctaText: String` = "Continue my coaching journey"
  - [x]2.4 Method: `buildHeaderText()` — checks `discoveryContext.coachingDomain`, returns personalized or fallback
  - [x]2.5 Method: `buildBodyText()` — checks `discoveryContext.ahaInsight` then `discoveryContext.keyTheme`, returns personalized or fallback
  - [x]2.6 Track `impressionLogged: Bool` to log paywall impression once per presentation

- [x] Task 3: Integrate personalized paywall as overlay in ChatView (AC: #3, #5)
  - [x]3.1 In `ChatView.swift`, add overlay triggered when `chatViewModel.discoveryComplete && !subscriptionViewModel.isSubscribed`
  - [x]3.2 Overlay structure: `PersonalizedPaywallView` with `.firstPresentation` mode, placed OVER chat ScrollView using `.overlay()` modifier
  - [x]3.3 Overlay uses `.background(.ultraThinMaterial)` with opacity 0.85 — coach's last message visible behind it
  - [x]3.4 Wire purchase success: on completion dismiss overlay, call `viewModel.sendPendingMessage()` if pending (reuse existing pattern)
  - [x]3.5 Wire dismiss: hide overlay, set `discoveryPaywallDismissed = true` on ChatViewModel, disable MessageInput
  - [x]3.6 After dismiss, if user taps send show `.returnPresentation` paywall as `.sheet()` (full screen, not overlay)

- [x] Task 4: Add discovery context to ChatViewModel for paywall (AC: #1, #2, #6)
  - [x]4.1 Add `discoveryPaywallContext: DiscoveryPaywallContext?` property to ChatViewModel
  - [x]4.2 Add `discoveryPaywallDismissed: Bool` property (defaults false)
  - [x]4.3 Add `showPersonalizedPaywall: Bool` computed — true when `discoveryComplete && !subscribed && !discoveryPaywallDismissed`
  - [x]4.4 When `discoveryComplete` becomes true: build `DiscoveryPaywallContext` from SSE response metadata (coaching_domains, aha_insight, key_themes)
  - [x]4.5 Override `sendMessage()` gating: when `discoveryPaywallDismissed && !subscribed` set `pendingMessage`, present return paywall (reuse `showPaywall`/`pendingMessage` pattern)

- [x] Task 5: Wire OnboardingCoordinator paywall state (AC: #5, #6)
  - [x]5.1 In `OnboardingCoordinator.swift` (Story 11.3), update `.paywall` state to pass discovery context to PersonalizedPaywallView
  - [x]5.2 On subscription confirmed: transition to `.paidChat`, chat resumes seamlessly
  - [x]5.3 On dismiss without purchase: set `discovery_completed = true` in UserDefaults, prevent re-entry to free session
  - [x]5.4 On return to app with `discovery_completed = true && !subscribed`: show return paywall directly

- [x] Task 6: Populate DiscoveryPaywallContext from SSE metadata (AC: #1, #2)
  - [x]6.1 In `ChatStreamService.swift`, ensure `StreamEvent.done` includes `discoveryProfile: [String: Any]?` from SSE response (may already exist from Story 11.3)
  - [x]6.2 Parse `coaching_domains`, `aha_insight`, `key_themes` from discovery profile JSON
  - [x]6.3 In ChatViewModel, when handling `.done` event with `discoveryComplete: true`: extract fields and build `DiscoveryPaywallContext` — use first item from `coaching_domains` for `coachingDomain`, first from `key_themes` for `keyTheme`
  - [x]6.4 If SSE metadata is missing or malformed: use empty context (paywall falls back to generic copy gracefully)

- [x] Task 7: Write tests (AC: all)
  - [x]7.1 Test PersonalizedPaywallViewModel — personalized header with domain, fallback without domain
  - [x]7.2 Test PersonalizedPaywallViewModel — personalized body with aha insight, fallback with key theme, fallback without either
  - [x]7.3 Test ChatViewModel discovery paywall flow: discoveryComplete triggers paywall, dismiss then send shows return paywall
  - [x]7.4 Test DiscoveryPaywallContext construction from SSE metadata: valid JSON, partial JSON, missing JSON
  - [x]7.5 Test paywall state persistence: `discovery_completed` prevents re-entry to free session

## Dev Notes

### Architecture & Patterns

- **PersonalizedPaywallView is a NEW view, separate from PaywallView.** The existing PaywallView handles trial expiration scenarios with static copy. PersonalizedPaywallView serves the post-discovery context with dynamic, insight-driven copy. They share design tokens (colors, glass, accessibility patterns) and package display patterns, but have fundamentally different copy generation logic and presentation modes.

- **Two presentation modes with different UI affordances:**
  1. **`.firstPresentation`**: Overlay ON TOP of the chat using `.overlay()` or ZStack. Coach's last message (the aha insight) is visible behind `.ultraThinMaterial`. This creates emotional continuity: the coach just delivered a breakthrough, and now you're invited to continue.
  2. **`.returnPresentation`**: Full-screen `.sheet()` when user returns after dismissing. No chat visible behind it. Different copy: "Your coach is still here. Pick up where you left off." — acknowledges time has passed.

- **DiscoveryPaywallContext is a lightweight DTO** containing only the 3-4 fields needed for paywall copy generation (`coachingDomain`, `ahaInsight`, `keyTheme`, `userName`). It does NOT reference the full `ContextProfile` model, keeping the paywall decoupled from the profile schema.

- **RevenueCat offerings are fetched by SubscriptionViewModel** — PersonalizedPaywallView receives `subscriptionViewModel` (the app's singleton) and displays its `availablePackages`. Do NOT create a separate offerings fetch.

- **Purchase flow reuses `SubscriptionViewModel.purchase(package:)`** — identical to existing PaywallView. No new purchase logic needed. The personalization is purely in copy and presentation.

### Critical Integration Points

**ChatViewModel.discoveryComplete** (created by Story 11.3):
- When the SSE stream signals `discovery_complete: true`, ChatViewModel sets `self.discoveryComplete = true`
- Story 11.5 hooks in: when `discoveryComplete` becomes `true`, build `DiscoveryPaywallContext` from SSE response metadata and trigger the personalized paywall overlay

**ChatViewModel.showPaywall / pendingMessage pattern** (lines ~180-186 in existing code):
- The return paywall for post-discovery gating MUST reuse this exact pattern
- When `discoveryPaywallDismissed && !subscribed` and user tries to send: `pendingMessage = text`, `showPaywall = true` → present return variant
- After purchase: `sendPendingMessage()` auto-sends the queued message

**OnboardingCoordinator** (created by Story 11.3):
- Manages flow: `.welcome` → `.discoveryChat` → `.paywall` → `.paidChat`
- Story 11.5 enriches the `.paywall` state with discovery context data
- After purchase → coordinator transitions to `.paidChat`

**SSE done event structure** (modified by Story 11.3, Task 4):
- `StreamEvent.done` includes `discoveryComplete: Bool` and `discoveryContextProfile: [String: Any]?`
- Story 11.5 uses the `discoveryContextProfile` dictionary to build `DiscoveryPaywallContext`
- If the dictionary is nil or malformed, paywall gracefully falls back to generic copy

### Existing Code to Reuse — DO NOT Reinvent

| What | Where | How to Reuse |
|------|-------|-------------|
| Warm color palette | `Core/UI/Theme/Colors.swift` | `Color.adaptiveCream`, `.terracotta`, `.adaptiveText`, `.warmGray` |
| Adaptive glass | `Core/UI/Modifiers/AdaptiveGlassModifiers.swift` | `.adaptiveGlass()` on card elements |
| Package display | `Features/Subscription/Views/PaywallView.swift` | Follow `PackageRow` pattern for subscription options |
| Purchase flow | `SubscriptionViewModel.purchase(package:)` | Call directly — no new purchase logic |
| Restore purchases | `SubscriptionViewModel.restorePurchases()` | Same restore flow |
| Purchase error display | `PaywallView.swift` (purchaseError section) | Same warm error pattern |
| Message gating | `ChatViewModel.swift:180-186` | Reuse `showPaywall`/`pendingMessage` for return paywall |
| Legal text | `PaywallView.swift` | Reuse legal copy pattern |
| Loading overlay | `PaywallView.swift` | Same purchase loading overlay pattern |
| Trial expired prompt | `ChatView.swift:810-835` | Follow same warm messaging pattern for disabled chat state |

### Key Design Decisions

1. **PersonalizedPaywallView is a NEW file, not a modification of PaywallView.** The existing PaywallView serves trial expiration with static copy. Merging them would create a confusing multi-purpose view. They share design patterns but are architecturally separate.

2. **DiscoveryPaywallContext is a simple struct, NOT the full ContextProfile.** The paywall only needs 3-4 fields for copy generation. Passing the entire ContextProfile would create unnecessary coupling. The struct is defined in `PersonalizedPaywallViewModel.swift`.

3. **Overlay with `.ultraThinMaterial` for first presentation, NOT `.sheet()`.** A sheet hides the chat completely. The overlay keeps the coach's last message visible, reinforcing the emotional "aha moment." Material blur creates depth without obscuring content.

4. **Return paywall uses `.sheet()` because there's no chat context to show behind it.** When the user returns days later, overlaying on stale/empty chat is meaningless. A clean full-screen paywall with "pick up where you left off" copy is more appropriate.

5. **Paywall copy is generated client-side from discovery context fields, NOT server-side.** The Edge Function extracts context fields and returns them in SSE metadata. The iOS client uses these fields to compose copy. This is simpler than server-side copy generation and allows future A/B testing without server changes.

6. **CTA: "Continue my coaching journey" — NOT "Subscribe" or "Start trial."** Frames the action as continuing something already begun, not starting a transaction. Aligns with the emotional design principle: "The paywall is not a gate — it's an invitation to continue something already begun."

### Dependencies (must be implemented BEFORE this story)

| Story | What it provides | What 11.5 consumes |
|-------|-----------------|---------------------|
| **11.1** | Discovery system prompt, context extraction, `[DISCOVERY_COMPLETE]` signal format | Tag format, extraction field definitions |
| **11.2** | Discovery mode routing, `discovery_complete` flag in SSE response | The SSE signal that triggers paywall |
| **11.3** | OnboardingCoordinator, ChatView overlay anchor, `discoveryComplete` on ChatViewModel, SSE parsing | Flow state machine, overlay presentation, discovery signal detection |
| **11.4** | Discovery profile extraction, `parseDiscoveryProfile()`, profile data in SSE metadata | Context fields (`aha_insight`, `coaching_domains`, `key_themes`) for paywall copy |
| **Epic 6** | PaywallView, SubscriptionViewModel, RevenueCat SDK, purchase flow | Purchase infrastructure, package display patterns, subscription state management |

### File Paths

| File | Action | Purpose |
|------|--------|---------|
| `CoachMe/CoachMe/Features/Subscription/Views/PersonalizedPaywallView.swift` | NEW | Personalized paywall view with discovery context copy |
| `CoachMe/CoachMe/Features/Subscription/ViewModels/PersonalizedPaywallViewModel.swift` | NEW | Copy generation logic, DiscoveryPaywallContext struct, presentation state |
| `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` | MODIFY | Add personalized paywall overlay for first presentation |
| `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` | MODIFY | Add `discoveryPaywallContext`, `discoveryPaywallDismissed`, paywall state management |
| `CoachMe/CoachMe/Features/Onboarding/ViewModels/OnboardingCoordinator.swift` | MODIFY | Pass discovery context to paywall state, handle dismiss/subscribe transitions |
| `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` | MODIFY | Ensure `StreamEvent.done` includes discovery profile JSON (if not done by 11.3) |
| `CoachMe/CoachMeTests/PersonalizedPaywallViewModelTests.swift` | NEW | Copy generation tests, fallback behavior |
| `CoachMe/CoachMeTests/DiscoveryPaywallFlowTests.swift` | NEW | ChatViewModel discovery paywall flow tests |

### Anti-Patterns to Avoid

- **DO NOT** modify the existing `PaywallView.swift` — create a separate `PersonalizedPaywallView`
- **DO NOT** use `@ObservableObject` — use `@Observable` (Swift Observation framework)
- **DO NOT** fetch offerings in PersonalizedPaywallView — use `subscriptionViewModel.fetchOfferings()` and read `subscriptionViewModel.availablePackages`
- **DO NOT** create a new purchase flow — call `subscriptionViewModel.purchase(package:)` directly
- **DO NOT** hardcode pricing strings — always use RevenueCat's `storeProduct.localizedPriceString`
- **DO NOT** store paywall copy in Edge Function — copy generation is client-side from extracted context fields
- **DO NOT** apply `.glassEffect()` directly — always use `.adaptiveGlass()` or `.adaptiveInteractiveGlass()` modifiers
- **DO NOT** use `.sheet()` for first presentation — use overlay to keep chat visible; `.sheet()` is only for return presentation
- **DO NOT** bypass the `sendPendingMessage()` pattern — always queue messages when paywall appears
- **DO NOT** modify `shouldGateChat` in SubscriptionViewModel — add discovery-specific gating logic separately in ChatViewModel

### What This Story Does NOT Include

- **Discovery session UI** (welcome screen, onboarding flow) — Story 11.3
- **Model routing** (Haiku for discovery, Sonnet for paid) — Story 11.2
- **Discovery system prompt** — Story 11.1
- **Context profile extraction pipeline** — Story 11.4
- **RevenueCat SDK setup** — Story 6.1 (already done)
- **A/B testing paywall copy variants** — future optimization
- **RevenueCat Experiments configuration** — future optimization
- **Analytics event tracking for paywall** — future enhancement
- **Message counting bypass for discovery** — Epic 10 / Story 11.2

### Migration Requirements

None. This story is purely iOS-side UI and ViewModel changes. No database migrations needed. All discovery data consumed comes from the SSE response metadata (populated by Stories 11.1-11.4).

### Existing Code Patterns to Follow

**Package row pattern** (PaywallView.swift):
```swift
private func PackageRow(package: Package, onPurchase: @escaping () -> Void) -> some View {
    Button(action: onPurchase) {
        VStack(alignment: .leading, spacing: 4) {
            Text(package.storeProduct.localizedTitle)
                .font(.headline)
            Text(package.storeProduct.localizedDescription)
                .font(.subheadline)
            Text(package.storeProduct.localizedPriceString)
                .font(.title3.weight(.bold))
        }
    }
    .adaptiveGlass()
}
```

**Purchase flow pattern** (SubscriptionViewModel.swift):
```swift
func purchase(package: Package) async -> Bool {
    isPurchasing = true
    purchaseError = nil
    defer { isPurchasing = false }
    do {
        let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
        if userCancelled { return false }
        if customerInfo.entitlements["premium"]?.isActive == true {
            state = .subscribed
            isPremium = true
            return true
        }
        return false
    } catch {
        purchaseError = "I couldn't complete that purchase. Let's try again when you're ready."
        return false
    }
}
```

**Message gating pattern** (ChatViewModel.swift):
```swift
// Reuse this exact pattern for discovery paywall return state
if subscriptionVM.shouldGateChat {
    pendingMessage = trimmedInput
    inputText = ""
    showPaywall = true
    return
}
```

### Testing Requirements

- All ViewModels tested with `@MainActor` isolation
- Mock `SubscriptionViewModel` for paywall tests
- Test copy generation: personalized with full context, partial context, empty context (all fallbacks)
- Test presentation states: firstPresentation overlay vs returnPresentation sheet
- Test purchase flow through personalized paywall (reuses existing purchase path)
- Test dismiss + re-trigger flow: dismiss overlay then send shows return paywall
- Test `DiscoveryPaywallContext` construction: valid SSE metadata, partial, missing, malformed
- Test `discovery_completed` UserDefaults persistence prevents re-entry to free session

### Project Structure Notes

- `PersonalizedPaywallView.swift` lives in existing `Features/Subscription/Views/` alongside `PaywallView.swift`
- `PersonalizedPaywallViewModel.swift` in `Features/Subscription/ViewModels/` alongside `SubscriptionViewModel.swift`
- `DiscoveryPaywallContext` struct and `PaywallPresentation` enum defined in `PersonalizedPaywallViewModel.swift` (not separate files)
- Test files in `CoachMeTests/` following existing naming convention
- All paths align with architecture.md project structure

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11, Story 11.5] — User story, AC, paywall copy, pricing, technical notes
- [Source: _bmad-output/planning-artifacts/architecture.md] — MVVM pattern, adaptive design, RevenueCat integration, navigation
- [Source: _bmad-output/implementation-artifacts/stories/11-3-onboarding-flow-ui.md] — OnboardingCoordinator states, ChatView overlay, discovery_complete signal parsing
- [Source: _bmad-output/implementation-artifacts/stories/11-4-discovery-to-profile-pipeline.md] — Discovery context extraction fields, context profile schema
- [Source: _bmad-output/implementation-artifacts/stories/11-1-discovery-session-system-prompt.md] — Discovery prompt phases, [DISCOVERY_COMPLETE] format, extraction fields
- [Source: CoachMe/CoachMe/Features/Subscription/Views/PaywallView.swift] — PackageRow pattern, purchase error display, legal text, glass styling
- [Source: CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift] — Purchase flow, offerings fetch, shouldGateChat, trial tracking
- [Source: CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift] — showPaywall/pendingMessage pattern, sendPendingMessage()
- [Source: CoachMe/CoachMe/Features/Chat/Views/ChatView.swift] — Paywall sheet presentation, overlay patterns
- [Source: CoachMe/CoachMe/Core/UI/Theme/Colors.swift] — Color.terracotta, Color.adaptiveCream, warm palette
- [Source: CoachMe/CoachMe/Core/UI/Modifiers/AdaptiveGlassModifiers.swift] — .adaptiveGlass(), .adaptiveInteractiveGlass()

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — implementation completed without build/test errors requiring debug cycles.

### Completion Notes List

- **Task 1**: Created `PersonalizedPaywallView.swift` — full SwiftUI view with hero, body, packages, CTA, dismiss, restore, legal text, offerings failure state, loading overlay. Two presentation modes (first=overlay, return=sheet). Adaptive design with `.adaptiveGlass()`, warm colors, full accessibility.
- **Task 2**: Created `PersonalizedPaywallViewModel.swift` — `DiscoveryPaywallContext` struct, `PaywallPresentation` enum, `PersonalizedPaywallViewModel` class with client-side copy generation. Header uses coaching domain, body prefers aha insight over key theme, graceful fallbacks.
- **Task 3**: Replaced basic `discoveryPaywallOverlay` in ChatView with `PersonalizedPaywallView` using `.firstPresentation` mode. Added `.sheet()` for return paywall. Wired purchase success → dismiss + send pending message. Wired dismiss → set `discoveryPaywallDismissed`. Updated `onChange(of: viewModel.showPaywall)` to route to return paywall in discovery mode.
- **Task 4**: Added `discoveryPaywallContext`, `discoveryPaywallDismissed`, `showPersonalizedPaywall` computed property to ChatViewModel. Updated `resetStateForConversation()`.
- **Task 5**: Added `discoveryPaywallContext` property to OnboardingCoordinator. Added `onDiscoveryComplete(with:)` overload. Added `shouldShowReturnPaywall` computed property. Updated `reset()` to clear context.
- **Task 6**: Added `DiscoveryProfileData` struct to `StreamEvent`. Extended `.done` case with 5th parameter `discoveryProfile`. Updated decoder with `decodeIfPresent`. Updated both `sendMessage` and `sendFirstDiscoveryMessage` done handlers to build `DiscoveryPaywallContext` from SSE metadata. Updated 9 pattern matches across test files.
- **Task 7**: Created `PersonalizedPaywallTests.swift` with 24 tests covering: copy generation (domain, insight, theme, fallbacks), presentation modes, ChatViewModel paywall flow, SSE context construction (full/partial/nil profile), coordinator persistence, and equatable conformance.

### File List

**New files:**
- `CoachMe/CoachMe/Features/Subscription/Views/PersonalizedPaywallView.swift`
- `CoachMe/CoachMe/Features/Subscription/ViewModels/PersonalizedPaywallViewModel.swift`
- `CoachMe/CoachMeTests/PersonalizedPaywallTests.swift`

**Modified files:**
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — replaced basic overlay with PersonalizedPaywallView, added return paywall sheet, updated gating, added discoveryGatedPrompt (review fix H1), fixed coordinator context passing (review fix H3)
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — added paywall context/dismissed properties, SSE context extraction, extracted buildDiscoveryPaywallContext helper (review fix M1)
- `CoachMe/CoachMe/Features/Onboarding/ViewModels/OnboardingCoordinator.swift` — added context property, overloaded completion, return paywall eligibility, added init() to restore flow state from persisted flags (review fix H4)
- `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` — added DiscoveryProfileData, extended .done event
- `CoachMe/CoachMe/Features/Subscription/Views/PersonalizedPaywallView.swift` — wired impressionLogged on appear (review fix H2), added packages loading indicator (review fix M3)
- `CoachMe/CoachMeTests/PersonalizedPaywallTests.swift` — added 5 coordinator state restoration and impression tracking tests (review fix M2)
- `CoachMe/CoachMeTests/ChatStreamServiceTests.swift` — updated .done pattern matches for 5th parameter
- `CoachMe/CoachMeTests/OnboardingFlowTests.swift` — updated .done pattern match for 5th parameter

## Senior Developer Review (AI)

**Reviewer:** Sumanth (via Claude Opus 4.6) on 2026-02-10

### Review Outcome: APPROVED with fixes applied

### Issues Found: 4 High, 4 Medium, 2 Low

**HIGH — Fixed:**
- **H1**: Discovery-gated "View plans" button routed to generic PaywallView instead of PersonalizedPaywallView return variant (AC #6 violation). Fixed: created `discoveryGatedPrompt` with correct routing.
- **H2**: `impressionLogged` declared but never set to true (Task 2.6 incomplete). Fixed: wired in PersonalizedPaywallView `.task`.
- **H3**: `onDiscoveryComplete(with: context)` never called from ChatView — coordinator context always nil. Fixed: ChatView now passes context when available.
- **H4**: `shouldShowReturnPaywall` defined but never consumed on app relaunch. Fixed: added `init()` to OnboardingCoordinator that restores `.paywall` flow state from persisted flags.

**MEDIUM — Fixed:**
- **M1**: Duplicate context construction logic in `sendMessage()` and `sendFirstDiscoveryMessage()`. Fixed: extracted `buildDiscoveryPaywallContext(from:)` helper.
- **M2**: Thin ChatViewModel paywall integration tests. Fixed: added 5 tests for coordinator state restoration and impression tracking.
- **M3**: No loading indicator while offerings fetch. Fixed: added ProgressView when packages empty and loading.

**MEDIUM — Accepted as-is:**
- **M4**: Redundant `dismiss()` call in overlay mode — harmless no-op, not worth the risk of changing.

**LOW — Not fixed (acceptable):**
- **L1**: `userName` field always nil — likely placeholder for future use.
- **L2**: Story File Paths table names don't match actual files — doc inconsistency only.

### Change Log

| Date | Agent | Change |
|------|-------|--------|
| 2026-02-10 | Claude Opus 4.6 (dev) | Initial implementation — Tasks 1-7 |
| 2026-02-10 | Claude Opus 4.6 (review) | Fixed 7 issues (4H, 3M): H1 wrong paywall routing, H2 impressionLogged wiring, H3 coordinator context passing, H4 flow state restoration, M1 DRY extraction, M2 test coverage, M3 loading indicator |
