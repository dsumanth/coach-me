# Story 10.4: $2.99 Paid Trial Configuration

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **a $2.99/3-day paid trial that auto-upgrades to $19.99/month**,
so that **I can experience premium coaching after my discovery session with a low-commitment entry price**.

## Acceptance Criteria

1. **Given** I subscribe via the paywall after discovery, **When** my payment is confirmed, **Then** I have 3 days of premium Sonnet coaching with up to 100 messages

2. **Given** I am in an active paid trial, **When** I open the app, **Then** I see a subtle, warm trial banner: "Day [X] of 3 — [messages remaining] conversations left"

3. **Given** my paid trial has 24 hours remaining, **When** I open the app, **Then** the banner gently emphasizes: "Last day of your trial — want to keep going? Your subscription continues automatically."

4. **Given** my 3-day trial ends, **When** the auto-upgrade occurs, **Then** my subscription seamlessly converts to $19.99/month with 800 messages/month — no interruption in service

5. **Given** my trial messages run out (100 used) before the 3 days expire, **When** I try to send a message, **Then** I see: "You've been making great progress! Your message limit refreshes when your monthly subscription begins on [date]."

6. **Given** my paid trial expired and I cancelled before auto-upgrade, **When** I open the app, **Then** I can still READ past conversations but cannot send new messages — paywall shows "Ready to come back?"

## Tasks / Subtasks

- [x] Task 1: Configure StoreKit introductory offer (AC: #1, #4)
  - [x] 1.1 Create/update StoreKit Configuration file (`.storekit`) with `coach_app_premium_monthly` product: $19.99/month auto-renewable subscription
  - [x] 1.2 Add Pay As You Go introductory offer: $2.99/week, 1 period
  - [x] 1.3 Set subscription group: `coach_app_subscriptions`
  - [ ] 1.4 Add StoreKit configuration file to the CoachMe Xcode scheme for local sandbox testing *(manual Xcode step — user must configure in scheme settings)*

- [x] Task 2: Update SubscriptionViewModel for paid trial detection (AC: #1, #2, #4)
  - [x] 2.1 Story 10-3 already replaced UserDefaults with TrialManager — adapted to use TrialManager.shared state
  - [x] 2.2 `startCustomerInfoStream()` now uses `entitlement.periodType == .intro` to detect paid trial vs `.normal` (standard subscription)
  - [x] 2.3 Updated `SubscriptionState` enum: `.trial(daysRemaining:)` → `.paidTrial(daysRemaining: Int, messagesRemaining: Int)`
  - [x] 2.4 `daysRemaining` computed from TrialManager state (which uses `trial_activated_at` from server)
  - [x] 2.5 `messagesRemaining` reads from TrialManager.shared.messagesRemaining (TrialManager already tracks via message_usage)
  - [x] 2.6 Updated `trialStatusMessage` to return "Day X of 3 — Y conversations left"
  - [x] 2.7 Updated `shouldGateChat` to return `true` when `.paidTrial` messages are exhausted (messagesRemaining <= 0)
  - [x] 2.8 Story 10-3 already removed UserDefaults trial logic — no further cleanup needed
  - [x] 2.9 `checkTrialStatus()` delegates to TrialManager.refreshState() + syncStateFromTrialManager()

- [x] Task 3: Update TrialBanner for paid trial UX (AC: #2, #3)
  - [x] 3.1 TrialBanner reads directly from TrialManager.shared (messagesRemaining, trialDayNumber)
  - [x] 3.2 Normal trial display: "Day [X] of 3 — [Y] conversations left" with sparkle icon
  - [x] 3.3 Last-day emphasis: warm amber accent color, "Last day of your trial — want to keep going? Your subscription continues automatically."
  - [x] 3.4 Low-messages emphasis: when messagesRemaining <= 10, message count shown in bold weight
  - [x] 3.5 Maintained existing adaptive glass styling (`.adaptiveGlass()`)
  - [x] 3.6 Updated VoiceOver accessibility label to include both days and messages

- [x] Task 4: Update PaywallView for trial-expired contexts (AC: #5, #6)
  - [x] 4.1 Added `PaywallContext` enum: `.trialExpired`, `.messagesExhausted(nextBillingDate: Date?)`, `.cancelled`, `.generic`
  - [x] 4.2 Messages-exhausted copy with next billing date
  - [x] 4.3 Cancelled copy: "Ready to come back?" with value proposition subtitle
  - [x] 4.4 `nextBillingDate` derived from `TrialManager.shared.trialExpirationDate` (added computed property)
  - [x] 4.5 All copy follows warm first-person coaching voice per UX-11

- [x] Task 5: Update ChatView for message-exhausted gating (AC: #5, #6)
  - [x] 5.1 Existing `shouldGateChat` block already handles `.paidTrial` message exhaustion
  - [x] 5.2 PaywallView sheet now receives `context: subscriptionViewModel.currentPaywallContext`
  - [x] 5.3 Read-only access preserved: gating only blocks send, past conversations visible
  - [x] 5.4 `trialExpiredPrompt` now shows context-aware copy (messages exhausted vs trial expired)

- [x] Task 6: Handle trial-to-subscription transition (AC: #4)
  - [x] 6.1 `startCustomerInfoStream()` detects intro → normal via `entitlement.periodType`
  - [x] 6.2 On `.intro` → `.normal` transition: state updates from `.paidTrial` to `.subscribed`, trial notification cancelled
  - [x] 6.3 Server-side limit handled by `subscription_status` in `increment_and_check_usage` RPC
  - [x] 6.4 Analytics logging deferred — existing cost-tracker pattern available when needed

- [x] Task 7: Write unit tests (all ACs)
  - [x] 7.1 Test paidTrial state detection and isTrialActive computed property
  - [x] 7.2 Test `SubscriptionState.paidTrial` equality and daysRemaining/messagesRemaining
  - [x] 7.3 Test `shouldGateChat` returns `true` when paidTrial messagesRemaining == 0
  - [x] 7.4 Test `shouldGateChat` returns `true` when trialExpired
  - [x] 7.5 Test `shouldGateChat` returns `false` when paidTrial has both days and messages remaining
  - [x] 7.6 Test trial-to-subscription transition updates state from `.paidTrial` to `.subscribed`
  - [x] 7.7 Test trialStatusMessage for normal trial, last-day, and empty states
  - [x] 7.8 Test PaywallContext computed property for messagesExhausted, trialExpired, cancelled, generic
  - [x] 7.9 Test read-only access: shouldGateChat blocks send but conversations remain accessible

## Dev Notes

### Critical Architecture Constraints

- **RevenueCat as subscription source of truth** — NEVER store trial status locally via UserDefaults. The existing 7-day free trial uses `getOrCreateTrialStartDate()` in UserDefaults — this must be REMOVED and replaced with RevenueCat entitlement detection. Use `customerInfo.entitlements["premium"]` and `customerInfoStream` for real-time updates.
- **StoreKit Pay As You Go intro offer** — This is NOT a "free trial" in StoreKit terms. It's a paid introductory offer. RevenueCat exposes this via `entitlement.periodType == .intro`.
- **Warm coaching voice (UX-11)** — All user-facing text uses first-person warm tone. "You've been making great progress!" not "Trial message limit reached."
- **Adaptive design** — All UI uses `.adaptiveGlass()` modifier (Warm Modern for iOS 18-25, Liquid Glass for iOS 26+). Never use raw `.glassEffect()`.
- **Swift 6 strict concurrency** — `@MainActor` on all ViewModels and Services. `@Observable` (not `@ObservableObject`).

### Dependency Status & Integration Points

| Dependency | Status | Integration |
|---|---|---|
| Story 10-1 (Message Rate Limiting) | `ready-for-dev` | Provides `message_usage` table with `(user_id, billing_period, message_count, limit_amount)`. Trial billing period = `'trial'` (fixed string, 100 limit, never resets). Paid = `'YYYY-MM'` (800 limit, monthly reset). Also provides `rate-limiter.ts` in chat-stream and `ChatStreamError.rateLimited` on iOS. |
| Story 10-5 (Usage Transparency UI) | `ready-for-dev` | Provides `UsageTrackingService.fetchCurrentUsage(userId:)` and `MessageUsage` model. Use this service to get `messagesRemaining` for the TrialBanner and SubscriptionViewModel. |
| Story 10-3 (Paid Trial Activation) | `backlog` — not yet created | Defines `TrialManager.swift` and `trial_activated_at` field. NOT needed for 10-4: use RevenueCat `originalPurchaseDate` on the entitlement instead. |
| Epic 6 (RevenueCat/Paywall) | `review` — implemented | SubscriptionService, SubscriptionViewModel, TrialBanner, PaywallView all exist. THIS STORY MODIFIES them. |
| Story 6.3 (Purchase Flow) | `review` — implemented | `customerInfoStream`, purchase flow, pending message queue. Verify transition detection works with intro→normal. |
| Epic 11 (Discovery) | `done` | OnboardingCoordinator, PersonalizedPaywallView complete. Discovery precedes trial — no changes needed. |

### Existing Files to Modify

| File | What to Change |
|---|---|
| `CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift` | Replace 7-day free trial with RevenueCat paid trial detection. Update `SubscriptionState` enum. Remove UserDefaults trial tracking. Add `messagesRemaining` via `UsageTrackingService`. Update `shouldGateChat` for message exhaustion. |
| `CoachMe/Features/Subscription/Views/TrialBanner.swift` | Add `messagesRemaining` parameter. Add last-day emphasis. Show "Day X of 3 — Y conversations left". |
| `CoachMe/Features/Subscription/Views/PaywallView.swift` | Add `PaywallContext` enum. Add messages-exhausted and cancelled copy states. Show next billing date. |
| `CoachMe/Features/Chat/Views/ChatView.swift` | Pass `PaywallContext` to PaywallView in gating block. Verify message-exhausted gating works. |

### New Files to Create

| File | Purpose |
|---|---|
| StoreKit Configuration (`.storekit`) | Local testing configuration for $2.99 intro offer → $19.99/month |

### Files NOT to Modify

- `SubscriptionService.swift` — RevenueCat wrapper is complete, no changes needed
- `PersonalizedPaywallView.swift` — Discovery paywall is a separate flow, do not merge
- `OnboardingCoordinator.swift` — Onboarding flow is complete, paywall step calls SubscriptionViewModel which we're updating
- `chat-stream/index.ts` — Server-side rate limiting is Story 10-1's scope
- `session-mode.ts` — Session mode routing is complete
- `rate-limiter.ts` — Story 10-1's scope
- `UsageTrackingService.swift` — Story 10-5 creates this; 10-4 only READS from it
- `UsageViewModel.swift` — Story 10-5 creates this; 10-4 only READS from it

### RevenueCat Entitlement Detection Pattern

```swift
// In SubscriptionViewModel — detecting paid trial vs standard subscription
func updateSubscriptionState(from customerInfo: CustomerInfo) {
    guard let entitlement = customerInfo.entitlements["premium"],
          entitlement.isActive else {
        state = .expired
        return
    }

    switch entitlement.periodType {
    case .intro:
        // Paid trial (introductory offer period)
        let daysRemaining = Calendar.current.dateComponents(
            [.day], from: Date(), to: entitlement.expirationDate ?? Date()
        ).day ?? 0
        // messagesRemaining from UsageTrackingService
        state = .paidTrial(daysRemaining: max(0, daysRemaining), messagesRemaining: messagesRemaining)
    case .normal:
        // Standard $19.99/month subscription
        state = .subscribed
    case .trial:
        // Free trial (not used in our model, treat as paid trial for safety)
        state = .subscribed
    @unknown default:
        state = .subscribed
    }
}
```

### Message Count Data Flow

```
SubscriptionViewModel.checkTrialStatus()
  → UsageTrackingService.fetchCurrentUsage(userId:)   [Story 10-5]
    → Supabase: SELECT FROM message_usage               [Story 10-1]
      WHERE user_id = $1 AND billing_period = 'trial'
    → Returns MessageUsage { messageCount, limit: 100 }
  → messagesRemaining = usage.limit - usage.messageCount
  → state = .paidTrial(daysRemaining: X, messagesRemaining: Y)
  → TrialBanner renders "Day X of 3 — Y conversations left"
```

### StoreKit Configuration Details

- **Product ID:** `coach_app_premium_monthly` (match existing product from Epic 6 if already configured)
- **Subscription Group:** `coach_app_subscriptions`
- **Base Price:** $19.99/month auto-renewable
- **Introductory Offer:** Pay As You Go, $2.99/week, 1 period
- **RevenueCat Entitlement:** `premium`
- **RevenueCat Offering:** Default offering, single package

> **NOTE:** The StoreKit "Pay As You Go" intro offer is billed weekly. The "3 days" trial experience is the UX framing. RevenueCat's `expirationDate` on the intro entitlement provides the actual end date — use that for `daysRemaining` calculation, not a hardcoded 3-day offset.

### UserDefaults Cleanup

The existing SubscriptionViewModel uses these UserDefaults keys that should be REMOVED:
- `coachme_trial_start_date` — replaced by RevenueCat `originalPurchaseDate`
- `trialDurationDays = 7` — replaced by RevenueCat `expirationDate`
- `getOrCreateTrialStartDate()` method — no longer needed
- Local notification scheduling for trial expiry — RevenueCat handles this or can be re-wired to entitlement expiration

### Testing Standards

- **XCTest** framework with `@MainActor` on test classes
- Mock `CustomerInfo` and entitlements for SubscriptionViewModel tests
- Mock `UsageTrackingService` for message count tests
- Test file: `CoachMeTests/PaidTrialConfigurationTests.swift`
- Follow existing test pattern from `SubscriptionServiceTests.swift` and `PersonalizedPaywallTests.swift`

### Project Structure Notes

- Feature path: `CoachMe/CoachMe/Features/Subscription/`
- Follows existing Feature Module Pattern: Views/, ViewModels/, Models/, Services/
- Tests in `CoachMe/CoachMeTests/` with naming pattern `{Feature}Tests.swift`
- StoreKit configuration files go in Xcode project root (not in source tree)
- No new Supabase migrations — message counting is Story 10-1, usage service is Story 10-5

### References

- [Source: epics.md#Story 10.4] — Story requirements, acceptance criteria, technical notes
- [Source: epics.md#Epic 10] — Epic overview, trial model, design principle ("Limits should feel like care, not walls")
- [Source: architecture.md#Frontend Architecture] — MVVM + Repository pattern, @Observable ViewModels
- [Source: architecture.md#Naming Patterns] — Swift PascalCase types, camelCase properties, CodingKeys for snake_case
- [Source: architecture.md#Feature Module Pattern] — Views/, ViewModels/, Models/, Services/
- [Source: architecture.md#Subscription] — RevenueCat, PaywallView, TrialBanner in Features/Subscription/
- [Source: Story 10-1] — `message_usage` table schema, `increment_and_check_usage` RPC, `rate-limiter.ts`, billing period conventions (trial='trial', paid='YYYY-MM'), limit amounts (trial=100, paid=800)
- [Source: Story 10-5] — `UsageTrackingService.fetchCurrentUsage()`, `MessageUsage` model, `UsageViewModel` tier calculation, `UsageIndicator` component
- [Source: Story 6.1] — RevenueCat SDK init, SubscriptionService, "premium" entitlement ID
- [Source: Story 6.2] — TrialBanner, PaywallView, SubscriptionState enum, 7-day local trial (to be replaced), shouldGateChat
- [Source: Story 6.3] — customerInfoStream, purchase flow, pending message queue
- [Source: Story 11.5] — PersonalizedPaywallView (separate from PaywallView), DiscoveryPaywallContext

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- Story 10-3 had already replaced UserDefaults-based trial with TrialManager (server-side `trial_activated_at`). Adapted tasks 2.1/2.8 to current codebase state rather than following outdated removal instructions.
- UsageTrackingService (Story 10-5) not yet implemented. TrialManager.shared already provides `messagesUsed`/`messagesRemaining` tracking — used that as the data source.
- StoreKit "3 days" vs "1 week" Pay As You Go: UX frames as 3 days, StoreKit bills weekly (P1W). `daysRemaining` uses RevenueCat `expirationDate`, not hardcoded offset.
- Existing `SubscriptionServiceTests.swift` had broken tests referencing old `.trial(daysRemaining:)` enum — fixed those references to `.paidTrial(daysRemaining:, messagesRemaining:)` as part of Task 7.
- Subtask 1.4 (StoreKit config → Xcode scheme) requires manual Xcode configuration by user.

### Completion Notes List
- All 7 tasks completed with comprehensive test coverage (37 tests in PaidTrialConfigurationTests.swift)
- SubscriptionState enum updated across entire codebase (source + tests) with zero remaining `.trial(daysRemaining:)` references
- ChatView trialExpiredPrompt now shows context-aware copy for messages-exhausted vs trial-expired states
- PaywallContext enum enables context-specific hero section in PaywallView
- TrialManager.trialExpirationDate added for PaywallContext next billing date display

### Change Log
| File | Change Type | Description |
|---|---|---|
| `CoachMeStoreKitConfiguration.storekit` | Created | StoreKit sandbox config with $2.99 intro offer |
| `SubscriptionViewModel.swift` | Modified | `.paidTrial` enum, `currentPaywallContext`, `shouldGateChat` message gating, `periodType` detection |
| `TrialManager.swift` | Modified | Added `trialExpirationDate` computed property |
| `TrialBanner.swift` | Modified | Last-day emphasis, low-messages bold, amber accent, VoiceOver labels |
| `PaywallView.swift` | Modified | `PaywallContext` enum, context-specific hero copy, next billing date |
| `ChatView.swift` | Modified | `PaywallContext` passed to PaywallView, context-aware gated prompt copy |
| `SettingsView.swift` | Modified | `.trial` → `.paidTrial` pattern match fix |
| `SubscriptionServiceTests.swift` | Modified | Updated all `.trial` → `.paidTrial` references, removed UserDefaults test methods |
| `PaidTrialConfigurationTests.swift` | Created | 37 unit tests covering all ACs |

### File List
- `CoachMe/CoachMeStoreKitConfiguration.storekit` (new)
- `CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift` (modified)
- `CoachMe/CoachMe/Features/Subscription/Services/TrialManager.swift` (modified)
- `CoachMe/CoachMe/Features/Subscription/Views/TrialBanner.swift` (modified)
- `CoachMe/CoachMe/Features/Subscription/Views/PaywallView.swift` (modified)
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` (modified)
- `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift` (modified)
- `CoachMe/CoachMeTests/SubscriptionServiceTests.swift` (modified)
- `CoachMe/CoachMeTests/PaidTrialConfigurationTests.swift` (new)