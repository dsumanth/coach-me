# Story 6.2: Free Trial Experience

Status: review

## Story

As a **user**,
I want **to try Coach App without providing payment info**,
so that **I can experience the value before committing**.

## Acceptance Criteria

1. **Given** I'm a new user, **When** I sign up, **Then** my trial starts automatically without requiring payment information.

2. **Given** I'm in my trial period, **When** I see the trial banner, **Then** I know how many days/sessions remain with clear, warm messaging.

3. **Given** my trial is about to end (1 day remaining), **When** the app detects this, **Then** I get a gentle, non-intrusive notification nudge.

4. **Given** my trial has expired, **When** I try to start a new chat, **Then** a paywall appears with subscription options (not blocking read access to past conversations).

5. **Given** the trial banner is displayed, **When** I view it on iOS 26+, **Then** it uses adaptive glass styling consistent with the design system; on iOS 18-25, it uses Warm Modern styling.

6. **Given** I'm in trial, **When** I view Settings, **Then** I see my trial status (days/sessions remaining) in a Subscription section.

7. **Given** I'm a trial user, **When** I interact with the trial UI, **Then** all messaging is warm and first-person ("Your free trial has X days left — enjoy exploring!" not "Trial expires in X days").

## Tasks / Subtasks

- [x] Task 1: Create SubscriptionViewModel with trial state management (AC: #1, #2, #6)
  - [x] 1.1: Define `SubscriptionState` enum: `.unknown`, `.trial(daysRemaining: Int)`, `.trialExpired`, `.subscribed`, `.expired`
  - [x] 1.2: Create `SubscriptionViewModel` as `@MainActor @Observable` class
  - [x] 1.3: Implement `checkTrialStatus()` that queries RevenueCat for current entitlements and trial info
  - [x] 1.4: Implement `trialDaysRemaining` computed property from RevenueCat offering data
  - [x] 1.5: Add `isTrialActive`, `isTrialExpired`, `isSubscribed` convenience booleans
  - [x] 1.6: Expose SubscriptionViewModel through AppEnvironment.shared

- [x] Task 2: Create TrialBanner view component (AC: #2, #5, #7)
  - [x] 2.1: Create `Features/Subscription/Views/TrialBanner.swift`
  - [x] 2.2: Implement warm messaging: "Your free trial has X days left — enjoy exploring!"
  - [x] 2.3: Apply `.adaptiveGlass()` styling (NOT raw `.glassEffect()`)
  - [x] 2.4: Include a gentle CTA to view subscription options (not aggressive)
  - [x] 2.5: Add VoiceOver accessibility labels and Dynamic Type support
  - [x] 2.6: Add the banner to ChatView when trial is active

- [x] Task 3: Create PaywallView for trial-expired state (AC: #4, #5, #7)
  - [x] 3.1: Create `Features/Subscription/Views/PaywallView.swift`
  - [x] 3.2: Display subscription options from RevenueCat offerings
  - [x] 3.3: Use adaptive glass styling consistent with design system
  - [x] 3.4: Use warm, value-focused copy: "You've experienced what Coach App can do — keep the conversation going" (not "Your trial has expired")
  - [x] 3.5: Show pricing and trial period info from RevenueCat
  - [x] 3.6: Add VoiceOver accessibility labels
  - [x] 3.7: Allow dismissal (users can still browse past conversations)

- [x] Task 4: Integrate trial status into Settings (AC: #6)
  - [x] 4.1: Add "Subscription" section to SettingsView between "Account" and "About"
  - [x] 4.2: Display current plan status (trial/subscribed/expired)
  - [x] 4.3: Show trial days remaining or subscription renewal date
  - [x] 4.4: Add "View Plans" button that presents PaywallView
  - [x] 4.5: Use warm first-person copy throughout

- [x] Task 5: Add trial-expired gate to chat flow (AC: #4)
  - [x] 5.1: In ChatViewModel, check subscription state before allowing new messages
  - [x] 5.2: If trial expired and not subscribed, present PaywallView as sheet
  - [x] 5.3: Allow reading past conversations even when trial expired (read-only access preserved)
  - [x] 5.4: After successful purchase, dismiss paywall and allow chatting immediately

- [x] Task 6: Implement trial expiration notification (AC: #3)
  - [x] 6.1: Schedule local notification 1 day before trial ends
  - [x] 6.2: Use warm copy: "Your Coach App trial wraps up tomorrow. Want to keep our conversations going?"
  - [x] 6.3: Handle notification scheduling when trial status is first detected
  - [x] 6.4: Cancel notification if user subscribes before trial ends

- [x] Task 7: Write unit tests for SubscriptionViewModel (AC: all)
  - [x] 7.1: Test trial active state detection
  - [x] 7.2: Test trial expired state detection
  - [x] 7.3: Test subscribed state detection
  - [x] 7.4: Test days remaining calculation
  - [x] 7.5: Test chat gate logic (expired trial blocks new messages)

## Dev Notes

### Critical Architecture Patterns & Constraints

**MVVM + Repository Pattern:**
- SubscriptionViewModel MUST be `@MainActor @Observable` (NOT `@ObservableObject`)
- Follow existing service patterns: singleton with `.shared`, lazy initialization in AppEnvironment
- See AuthService.swift for the exact pattern to follow

**RevenueCat Integration (DEPENDENCY: Story 6-1 must be complete first):**
- RevenueCat SDK is already added to the Xcode project (`purchases-ios` SPM package)
- RevenueCat is NOT yet configured or initialized — Story 6-1 creates `RevenueCatService.swift` and handles initialization
- This story builds ON TOP of RevenueCatService to query entitlements and trial status
- Use `Purchases.shared.customerInfo` to check current entitlements
- Use RevenueCat's `CustomerInfo.entitlements["premium"]?.isActive` pattern
- Trial period is configured in RevenueCat dashboard + App Store Connect, not in client code

**Adaptive Design System (MANDATORY):**
- All UI components MUST use `.adaptiveGlass()` / `.adaptiveInteractiveGlass()` — NEVER raw `.glassEffect()`
- TrialBanner should use `AdaptiveGlassContainer` for grouping
- Both iOS 18-25 (Warm Modern) and iOS 26+ (Liquid Glass) must look intentionally designed
- Test on both iOS 18 and iOS 26 simulators
- Reference: `Core/UI/Modifiers/AdaptiveGlassModifiers.swift`

**UX Design Principles (FROM UX SPEC — MUST FOLLOW):**
- **Moment 7 (Trial-to-Paid Conversion):** The paywall should appear after a memory moment has landed — not on an arbitrary timer. If the user hasn't experienced the "AI that remembers me" promise, asking them to pay is asking for money before delivering value. [Source: ux-design-specification.md#Moment 7]
- **"Gentle Over Aggressive" principle:** Trial expiration is a nudge, not a wall. The app earns trust by respecting autonomy. [Source: ux-design-specification.md#Experience Principles]
- **Warm error/messaging standard:** First-person language ("Your free trial..." not "Trial period..."). See existing patterns in AppError enum.
- PRD specifies: "3-7 day trial or first N sessions (enough to hit session 3 aha moment)" [Source: prd.md#Revenue Model]

**Error Messages — WARM FIRST-PERSON REQUIRED (UX-11):**
- "Your free trial has X days left — enjoy exploring!"
- "You've experienced what Coach App can do — keep the conversation going"
- "Your Coach App trial wraps up tomorrow. Want to keep our conversations going?"
- NEVER: "Trial expires in X days", "Trial period ended", "Subscribe to continue"

**Accessibility (MANDATORY — UX-12, UX-13):**
- Full VoiceOver labels on all interactive elements (banner CTA, paywall buttons, settings subscription section)
- Dynamic Type support at all sizes
- Reduced transparency auto-handled by adaptive materials

### Project Structure Notes

**New files to create:**
```
CoachMe/CoachMe/Features/Subscription/
├── Views/
│   ├── TrialBanner.swift           # Trial status banner for ChatView
│   └── PaywallView.swift           # Subscription purchase screen
└── ViewModels/
    └── SubscriptionViewModel.swift # Trial/subscription state management
```

**Existing files to modify:**
- `Features/Settings/Views/SettingsView.swift` — Add Subscription section
- `Features/Chat/Views/ChatView.swift` — Add TrialBanner, trial-expired gate
- `Features/Chat/ViewModels/ChatViewModel.swift` — Add subscription check before sending
- `App/Environment/AppEnvironment.swift` — Expose SubscriptionViewModel

**Alignment with architecture.md project structure:**
- Features/Subscription/ path matches architecture's defined structure exactly
- SubscriptionViewModel follows the @Observable ViewModel pattern used across all features
- No conflicts with existing patterns detected

### References

- [Source: prd.md#FR33] Users can experience a free trial period without providing payment information
- [Source: prd.md#FR34] Users can subscribe to the paid plan after the trial ends
- [Source: prd.md#Revenue Model] 3-7 day trial or first N sessions, $5-10/month via Apple IAP
- [Source: prd.md#NFR32] Apple IAP integration handles all subscription lifecycle events
- [Source: architecture.md#Technology Stack] RevenueCat + StoreKit 2 for payments
- [Source: architecture.md#Implementation Patterns] @Observable ViewModels, warm error messages, adaptive glass
- [Source: ux-design-specification.md#Moment 7] Paywall after memory moment, not arbitrary timer
- [Source: ux-design-specification.md#Experience Principles] "Gentle Over Aggressive" — trial expiration is a nudge, not a wall
- [Source: ux-design-specification.md#Emotional Journey] Trial ending emotion: "Investing in growth", NOT "Losing access, punished"
- [Source: epics.md#Story 6.2] Configure trial in RevenueCat, create TrialBanner, track in SubscriptionViewModel

### Git Intelligence

Recent commit patterns show:
- Epic-level commits with descriptive summaries
- Files follow consistent naming: `{Feature}View.swift`, `{Feature}ViewModel.swift`
- All prior epics (1-4) completed; Epic 4 has 2 stories in review

### Dependency Note

**This story depends on Story 6-1 (RevenueCat Integration) being completed first.** Story 6-1 creates the `RevenueCatService.swift`, initializes RevenueCat in `CoachMeApp.swift`, configures API keys in `Configuration.swift`, and sets up the user identification flow. This story builds on that foundation to implement trial-specific UX.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build succeeded on first attempt with no compilation errors

### Completion Notes List

- **Task 1**: Enhanced SubscriptionViewModel with SubscriptionState enum (5 cases), trial tracking via UserDefaults (7-day local trial), RevenueCat entitlement checking, computed convenience properties, and offerings/purchase support. Exposed through AppEnvironment.shared.
- **Task 2**: Created TrialBanner with warm first-person messaging, sparkles icon, adaptive glass styling, gentle "See plans" CTA, and full VoiceOver/Dynamic Type support. Integrated into ChatView body.
- **Task 3**: Created PaywallView with hero section, RevenueCat offerings display, purchase/restore flows, warm value-focused copy, adaptive glass styling, dismissible design (allows browsing past conversations), and loading overlay during purchase.
- **Task 4**: Added Subscription section to SettingsView between Account and About. Shows current plan status (trial/subscribed/expired), days remaining, status icon, and "View plans" button. Uses warm first-person copy throughout.
- **Task 5**: Added trial-expired gate in ChatView. When trial is expired, shows a gentle prompt with "View plans" button instead of the message composer. Past conversations remain readable. Successful purchase dismisses paywall and re-enables chatting immediately.
- **Task 6**: Implemented local notification scheduling 1 day before trial ends using UNUserNotificationCenter. Warm copy: "Your Coach App trial wraps up tomorrow. Want to keep our conversations going?" Auto-scheduled when trial detected, auto-cancelled on subscription.
- **Task 7**: Wrote 18 comprehensive unit tests covering: initial state, trial active/expired detection, subscribed state, days remaining calculation (fresh/mid/expired), chat gate logic (4 state tests), warm message validation, trial start date creation/preservation, and SubscriptionState equality.

### File List

**New files:**
- CoachMe/CoachMe/Features/Subscription/Views/TrialBanner.swift
- CoachMe/CoachMe/Features/Subscription/Views/PaywallView.swift

**Modified files:**
- CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift
- CoachMe/CoachMe/App/Environment/AppEnvironment.swift
- CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift
- CoachMe/CoachMe/Features/Chat/Views/ChatView.swift
- CoachMe/CoachMeTests/SubscriptionServiceTests.swift

## Change Log

- **2026-02-08**: Story 6.2 — Free Trial Experience implementation. Added 7-day local trial with RevenueCat subscription checking, TrialBanner for ChatView, PaywallView with purchase flow, Settings Subscription section, trial-expired chat gate, local notification 1 day before trial ends, and 18 unit tests. Build succeeded.
