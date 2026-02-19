# Story 11.3: Onboarding Flow UI

Status: done

## Story

As a **user**,
I want **a seamless flow from app launch to discovery conversation to paywall**,
So that **I experience coaching value immediately without friction**.

## Acceptance Criteria

1. **Given** I am a brand new user who just signed in with Apple, **When** the app loads, **Then** I see one warm welcome screen: "This is your space. No judgment, no forms. Just a conversation." with a "Let's begin" CTA.

2. **Given** I tap "Let's begin" on the welcome screen, **When** the chat view opens, **Then** the coach's first message is already visible (sent automatically via `first_message: true` flag — not waiting for user input).

3. **Given** the discovery conversation is in progress, **When** I am chatting, **Then** the UI looks and feels identical to regular coaching — no "discovery mode" indicator, no progress bar, no message counter.

4. **Given** the AI signals `discovery_complete` in the SSE response, **When** the response arrives, **Then** the chat smoothly transitions to a personalized paywall overlay with the coach's insight summary visible behind it.

5. **Given** I dismiss the paywall without subscribing, **When** I try to send another message, **Then** the paywall reappears — the chat input is disabled until subscription.

6. **Given** I subscribe via the paywall, **When** payment is confirmed, **Then** the chat resumes seamlessly in the same conversation — the coach's first paid message references the discovery.

## Tasks / Subtasks

- [x] Task 1: Create OnboardingWelcomeView (AC: 1, 2)
  - [x] 1.1 Create `Features/Onboarding/Views/OnboardingWelcomeView.swift` — single screen with warm messaging and "Let's begin" button
  - [x] 1.2 Use existing warm design tokens: `Color.adaptiveCream`, `Color.terracotta`, `Color.adaptiveText`, rounded `.system` typography
  - [x] 1.3 Add accessibility label and VoiceOver support for the welcome message and CTA
  - [x] 1.4 Animate entrance with subtle fade-in (match existing `welcomeTransition` pattern in Router)

- [x] Task 2: Create OnboardingCoordinator (AC: 1, 2, 3, 4, 5, 6)
  - [x] 2.1 Create `Features/Onboarding/ViewModels/OnboardingCoordinator.swift` — `@MainActor @Observable` class
  - [x] 2.2 Define flow states: `.welcome` → `.discoveryChat` → `.paywall` → `.paidChat`
  - [x] 2.3 Track `hasCompletedOnboarding` via `UserDefaults` (key: `has_completed_onboarding`)
  - [x] 2.4 Track `discoveryCompleted` via `UserDefaults` (key: `discovery_completed`) — prevents second free session
  - [x] 2.5 On "Let's begin" tap: create new conversation, navigate to ChatView with `isDiscoveryMode: true`
  - [x] 2.6 On `discovery_complete` signal: transition to paywall overlay state
  - [x] 2.7 On subscription confirmed: transition to paid chat, clear discovery gating

- [x] Task 3: Integrate onboarding flow into Router/RootView (AC: 1, 2)
  - [x] 3.1 Add `.onboarding` case to `Router.Screen` enum
  - [x] 3.2 Add `navigateToOnboarding()` method to Router
  - [x] 3.3 In RootView `checkAuthState()`: after successful auth, check `has_completed_onboarding` — if false, navigate to onboarding instead of conversationList
  - [x] 3.4 Add OnboardingWelcomeView branch in RootView's ZStack (alongside existing welcome/conversationList branches)
  - [x] 3.5 After onboarding completes (subscription or dismiss): set `has_completed_onboarding = true`, navigate to conversationList

- [x] Task 4: Add discovery_complete signal parsing to ChatStreamService (AC: 4)
  - [x] 4.1 Add `discoveryComplete: Bool` field to `StreamEvent.done` case
  - [x] 4.2 Parse `discovery_complete` boolean from SSE `done` event JSON
  - [ ] 4.3 Add `discoveryContextProfile: [String: Any]?` to done event (deferred — `[String: Any]` cannot conform to `Decodable`/`Equatable`; profile extraction belongs in Story 11.4)

- [x] Task 5: Add discovery mode support to ChatViewModel (AC: 2, 3, 4, 5, 6)
  - [x] 5.1 Add `isDiscoveryMode: Bool` property (set by OnboardingCoordinator)
  - [x] 5.2 Add `discoveryComplete: Bool` published state
  - [x] 5.3 On init with `isDiscoveryMode: true`: auto-send first message via `first_message: true` flag to chat-stream (coach speaks first)
  - [x] 5.4 In streaming `.done` handler: check `discoveryComplete` flag → set `self.discoveryComplete = true`
  - [x] 5.5 Override `sendMessage()` gating: when `discoveryComplete && !subscribed` → show paywall (reuse existing `showPaywall`/`pendingMessage` pattern)
  - [x] 5.6 After subscription purchase: call existing `handleSuccessfulPurchase()` → resume chat, Sonnet mode kicks in server-side

- [x] Task 6: Create discovery paywall overlay in ChatView (AC: 4, 5)
  - [x] 6.1 When `chatViewModel.discoveryComplete` becomes true, present semi-transparent paywall overlay
  - [x] 6.2 Coach's last message (the aha insight/summary) remains visible behind overlay — use `.background(.ultraThinMaterial)` with 0.85 opacity
  - [x] 6.3 Overlay contains personalized paywall copy (from discovery context or default): "Your coach gets you. Ready for more?"
  - [x] 6.4 CTA: "Continue my coaching journey" (not "Subscribe")
  - [x] 6.5 "Not now" dismiss → hide overlay, disable MessageInput, show paywall on next send attempt
  - [x] 6.6 Integrate with existing `PaywallView` / RevenueCat purchase flow from Epic 6

- [x] Task 7: Write tests (AC: all)
  - [x] 7.1 Test OnboardingCoordinator state transitions: welcome → discovery → paywall → paid
  - [x] 7.2 Test Router onboarding flow: new user → onboarding, returning user → conversationList
  - [x] 7.3 Test ChatViewModel discovery mode: auto-first-message, discovery_complete signal, paywall trigger
  - [x] 7.4 Test has_completed_onboarding persistence prevents repeat onboarding
  - [x] 7.5 Test discovery_completed prevents second free session on return

## Dev Notes

### Architecture Compliance

**MVVM + Repository pattern.** All new ViewModels MUST be `@MainActor @Observable` (NOT `@ObservableObject`). Follow the established pattern in [ChatViewModel.swift](CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift) and [Router.swift](CoachMe/CoachMe/App/Navigation/Router.swift).

**Navigation pattern.** The app uses a `Router` class with a `Screen` enum injected via SwiftUI `@Environment`. RootView switches between screens in a ZStack. Chat ↔ list uses `NavigationStack` with a `Binding<Bool>` — study [RootView.swift:52-63](CoachMe/CoachMe/App/Navigation/RootView.swift#L52-L63) for the exact pattern.

**Error messages.** All user-facing text MUST use warm, first-person phrasing per UX-11 ("I couldn't..." not "Failed to...").

### Critical Integration Points

**Existing `showPaywall` / `pendingMessage` pattern in ChatViewModel (lines 64-67, 180-186).** Discovery paywall MUST reuse this exact pattern. When discovery completes and user tries to send without subscription → set `pendingMessage`, set `showPaywall = true`. After purchase → call `handleSuccessfulPurchase()` which clears pending state and sends the message.

**Existing `shouldGateChat` in SubscriptionViewModel (line 94).** Returns true when `state == .trialExpired || state == .expired`. For discovery flow, gating logic is: `discoveryComplete && !subscribed` (different from trial expiry). Do NOT modify `shouldGateChat` — add a separate discovery-specific check.

**SSE event parsing in ChatStreamService (line 27-60).** The `StreamEvent.done` case currently carries `(messageId, usage, reflectionAccepted)`. Add `discoveryComplete: Bool` as a new field with default `false` for backward compatibility. Parse from `discovery_complete` key in the SSE JSON.

**Coach's automatic first message.** When `isDiscoveryMode: true`, ChatViewModel should send a request to chat-stream with `first_message: true` flag (and empty user message) immediately on init. The server responds with the coach's warm opening. Display this as the first assistant message. The user has NOT typed anything yet.

### Existing Code to Reuse — DO NOT Reinvent

| What | Where | How to Reuse |
|------|-------|-------------|
| Warm color palette | `Core/UI/Theme/Colors.swift` | Use `Color.adaptiveCream`, `.terracotta`, `.adaptiveText`, `.warmGray` |
| Adaptive glass | `Core/UI/Modifiers/AdaptiveGlassModifiers.swift` | Use `.adaptiveGlass()` on control elements only |
| PaywallView | `Features/Subscription/Views/PaywallView.swift` | Embed or present for purchase flow |
| SubscriptionViewModel | `AppEnvironment.shared.subscriptionViewModel` | Check subscription state, handle purchase |
| ChatView + ChatViewModel | `Features/Chat/` | Discovery uses the SAME ChatView — no separate UI |
| Router + Environment injection | `App/Navigation/Router.swift` | Add `.onboarding` screen case |
| Message gating pattern | `ChatViewModel.swift:180-186` | Reuse `showPaywall`/`pendingMessage` for post-discovery gating |
| Splash/loading overlay | `RootView.swift:126-152` | Follow same overlay pattern for onboarding welcome |

### File Structure — New and Modified Files

**New Files:**
```
CoachMe/CoachMe/Features/Onboarding/
├── Views/
│   └── OnboardingWelcomeView.swift       # Warm welcome screen
└── ViewModels/
    └── OnboardingCoordinator.swift        # Flow state machine
```

**Modified Files:**
```
CoachMe/CoachMe/App/Navigation/Router.swift              # Add .onboarding screen
CoachMe/CoachMe/App/Navigation/RootView.swift             # Add onboarding branch + auth check
CoachMe/CoachMe/Core/Services/ChatStreamService.swift     # Add discovery_complete to StreamEvent.done
CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift  # Discovery mode, auto-first-message, discovery_complete handling
CoachMe/CoachMe/Features/Chat/Views/ChatView.swift        # Discovery paywall overlay
```

**Test Files:**
```
CoachMe/CoachMeTests/OnboardingCoordinatorTests.swift     # State machine tests
CoachMe/CoachMeTests/OnboardingFlowTests.swift            # Integration flow tests
```

### Key Design Decisions

1. **Discovery uses the SAME ChatView/ChatViewModel** — no separate discovery UI. The conversation looks identical to regular coaching. Only the server-side prompt and model differ (handled by Story 11.2).

2. **OnboardingCoordinator is separate from Router** — Router manages app-level navigation (auth/chat/list). OnboardingCoordinator manages the onboarding sub-flow (welcome → discovery → paywall). They communicate but don't merge responsibilities.

3. **UserDefaults for onboarding state, NOT the context profile** — `has_completed_onboarding` and `discovery_completed` are device-local flags. The server-side `discovery_completed_at` (Story 11.4) is separate. Local flags ensure the flow works offline.

4. **Coach speaks first** — In discovery mode, the coach's opening message is generated server-side (Haiku) via a `first_message: true` request. The client sends an empty/initial request and displays the response as the first message. This matches the discovery prompt Phase 1 design.

5. **Paywall overlay, NOT a sheet** — The paywall appears as a semi-transparent overlay ON TOP of the chat, so the coach's last message (the aha insight) remains visible. This reinforces emotional continuity. Use `.background(.ultraThinMaterial)` NOT `.sheet()`.

### Dependencies

- **Story 11.2 (Discovery Mode Edge Function)** — Server-side model routing and `discovery_complete` signal. If not yet implemented, mock the `discovery_complete` flag in SSE responses for UI development.
- **Epic 6 (PaywallView, RevenueCat)** — Subscription purchase flow. Already implemented and in review.
- **Epic 1 (ChatView, ChatStreamService)** — Core chat infrastructure. Already done.

### Anti-Patterns to Avoid

- **DO NOT** create a separate "DiscoveryChatView" — reuse existing ChatView
- **DO NOT** add "discovery mode" visual indicators (progress bars, step counters) — the UI must be indistinguishable from regular coaching
- **DO NOT** store system prompts in the iOS client — all prompt logic is server-side (Edge Function)
- **DO NOT** use `@ObservableObject` — use `@Observable` (Swift Observation framework)
- **DO NOT** apply `.glassEffect()` directly — always use `.adaptiveGlass()` modifiers
- **DO NOT** modify `shouldGateChat` in SubscriptionViewModel — add discovery-specific gating logic separately
- **DO NOT** use `.sheet()` for the discovery paywall — use an overlay so chat remains visible

### Testing Requirements

- All ViewModels tested with `@MainActor` isolation
- Mock `ChatStreamService` and `ConversationService` (protocols already exist)
- Test UserDefaults persistence for `has_completed_onboarding` and `discovery_completed`
- Test state transitions: new user → onboarding → discovery → paywall → paid chat
- Test returning user with `discovery_completed = true` → goes directly to paywall (no second free session)

### Project Structure Notes

- New `Features/Onboarding/` folder follows existing feature module pattern (`Features/Auth/`, `Features/Chat/`, etc.)
- OnboardingCoordinator follows the same `@MainActor @Observable` pattern as Router and all other ViewModels
- All paths align with architecture.md project structure

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11, Story 11.3]
- [Source: _bmad-output/planning-artifacts/architecture.md#Frontend Architecture]
- [Source: _bmad-output/planning-artifacts/architecture.md#Auth Flow]
- [Source: _bmad-output/implementation-artifacts/stories/11-1-discovery-session-system-prompt.md]
- [Source: CoachMe/CoachMe/App/Navigation/Router.swift — Screen enum, navigation methods]
- [Source: CoachMe/CoachMe/App/Navigation/RootView.swift — Auth check flow, ZStack screen switching]
- [Source: CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift — showPaywall/pendingMessage pattern]
- [Source: CoachMe/CoachMe/Core/Services/ChatStreamService.swift — StreamEvent enum, SSE parsing]
- [Source: CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift — shouldGateChat]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- BUILD SUCCEEDED on first compilation attempt
- No runtime errors encountered
- SourceKit transient diagnostics for `Color.adaptiveCream` (compiles correctly — static function pattern)

### Completion Notes List
- All 7 tasks implemented; 29 of 30 subtasks complete (4.3 deferred to Story 11.4)
- Code review found 6 issues (3 HIGH, 2 MEDIUM, 1 LOW); all HIGH and MEDIUM fixed
- OnboardingWelcomeView uses warm design tokens, accessibility labels, fade-in animation
- OnboardingCoordinator implements full state machine: welcome → discoveryChat → paywall → paidChat
- Router.Screen extended with `.onboarding` case; RootView auth flow branches new vs returning users
- ChatStreamService.StreamEvent.done extended with 4th parameter `discoveryComplete: Bool` (backward-compatible default `false`)
- ChatRequest extended with `firstMessage: Bool` for coach-speaks-first pattern
- ChatViewModel: discovery-specific gating via `discoveryComplete && !subscribed`, reuses existing `showPaywall`/`pendingMessage` pattern
- ChatView: `.ultraThinMaterial` overlay (NOT sheet) with "Your coach gets you" messaging and "Continue my coaching journey" CTA
- 21 new tests across OnboardingCoordinatorTests (11) and OnboardingFlowTests (10), plus 4 new ChatStreamServiceTests
- No modifications to `shouldGateChat` in SubscriptionViewModel per anti-pattern guidance

### Change Log
- 2026-02-10: All tasks implemented, build verified, status → review
- 2026-02-10: Code review fixes applied:
  - H1: Added missing `firstMessage: false` to ChatStreamServiceTests.testEncodeChatRequest
  - H2: Added discovery-gated composer disable in ChatView safeAreaInset (AC5 compliance)
  - H3: Unmarked task 4.3 — `discoveryContextProfile: [String: Any]?` deferred to Story 11.4
  - M1: Added `showError = true` to sendFirstDiscoveryMessage() error handlers
  - M2: Removed hardcoded "Discovery" conversation title to prevent leaking into conversation list
  - L1: Acknowledged code duplication in sendFirstDiscoveryMessage() — acceptable for discovery-specific flow

### File List

**New Files:**
- `CoachMe/CoachMe/Features/Onboarding/Views/OnboardingWelcomeView.swift`
- `CoachMe/CoachMe/Features/Onboarding/ViewModels/OnboardingCoordinator.swift`
- `CoachMe/CoachMeTests/OnboardingCoordinatorTests.swift`
- `CoachMe/CoachMeTests/OnboardingFlowTests.swift`

**Modified Files:**
- `CoachMe/CoachMe/App/Navigation/Router.swift` — Added `.onboarding` screen case and `navigateToOnboarding()` method
- `CoachMe/CoachMe/App/Navigation/RootView.swift` — Added OnboardingCoordinator state, onboarding branch in ZStack, auth flow routing, environment injection
- `CoachMe/CoachMe/Core/Services/ChatStreamService.swift` — Added `discoveryComplete` to `.done` case, `firstMessage` to ChatRequest, updated `streamChat`/`streamOnce` signatures
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — Added `isDiscoveryMode`, `discoveryComplete`, `sendFirstDiscoveryMessage()`, discovery gating in `sendMessage()`
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — Added `isDiscoveryMode` parameter, discovery paywall overlay, auto-first-message in `.task`, onboarding coordinator integration
- `CoachMe/CoachMeTests/ChatStreamServiceTests.swift` — Updated existing `.done` destructuring to 4 parameters, added 4 new discovery_complete tests
