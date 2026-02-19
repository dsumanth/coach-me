# Story 6.3: Subscription Purchase Flow

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to subscribe after my trial ends**,
So that **I can continue using Coach App without interruption**.

## Acceptance Criteria

1. **Given** my trial has ended **When** I try to start a new chat **Then** a paywall sheet appears showing subscription options with adaptive styling (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25)

2. **Given** the paywall is displayed **When** I tap a subscription option **Then** the native Apple payment sheet appears via RevenueCat

3. **Given** Apple payment succeeds **When** the transaction completes **Then** the paywall dismisses and I can immediately continue chatting — no app restart required

4. **Given** Apple payment fails or I cancel **When** the payment sheet dismisses **Then** I see a warm error message ("I couldn't complete that purchase. Let's try again when you're ready.") and remain on the paywall

5. **Given** I have previously purchased a subscription on another device **When** I tap "Restore Purchases" on the paywall **Then** my entitlements are restored and I gain immediate access

6. **Given** I am a subscribed user **When** I launch the app or return to chat **Then** no paywall is shown and I can chat freely

7. **Given** my subscription expires (e.g., cancelled and period ends) **When** I next try to chat **Then** the paywall appears again with my previous plan highlighted

## Tasks / Subtasks

- [x] Task 1: Create SubscriptionViewModel with entitlement checking (AC: #1, #6)
  - [x] 1.1 Create `@Observable` SubscriptionViewModel in `Features/Subscription/ViewModels/` (existed from 6-1/6-2, verified)
  - [x] 1.2 Implement `checkEntitlement()` using `Purchases.shared.customerInfo()` for "premium" entitlement (existed from 6-1/6-2, verified — uses "premium" per 6-1 convention)
  - [x] 1.3 Implement `customerInfoStream` listener for real-time status updates (NEW — `startCustomerInfoStream()`)
  - [x] 1.4 Expose `isPremium`, `isTrialActive`, `trialDaysRemaining` computed properties (existed from 6-1/6-2, verified)
  - [x] 1.5 Implement `fetchOfferings()` to load available packages from RevenueCat (existed from 6-1/6-2, verified)

- [x] Task 2: Create PaywallView with adaptive design (AC: #1, #4, #5)
  - [x] 2.1 Create `PaywallView.swift` in `Features/Subscription/Views/` (existed from 6-2, verified)
  - [x] 2.2 Use custom PaywallView with RevenueCat packages (custom approach from 6-2 maintained — matches warm design system, remotely configurable via RevenueCat offerings)
  - [x] 2.3 Apply `.adaptiveGlass()` to the paywall container/toolbar (existed from 6-2, verified)
  - [x] 2.4 Add "Restore Purchases" button with `Purchases.shared.restorePurchases()` (existed from 6-2, verified)
  - [x] 2.5 Handle purchase completion callback to dismiss paywall (existed from 6-2, verified)
  - [x] 2.6 Handle error states with warm, first-person copy (NEW — `purchaseError` displayed in PaywallView)
  - [x] 2.7 Ensure VoiceOver accessibility on all interactive elements (existed from 6-2, enhanced with error label)

- [x] Task 3: Implement purchase flow logic (AC: #2, #3, #4)
  - [x] 3.1 Implement `purchasePackage(_ package: Package)` in SubscriptionViewModel using async/await (existed from 6-2, verified)
  - [x] 3.2 Handle transaction states: success → dismiss paywall, cancelled → stay on paywall, error → show warm error (ENHANCED — `userCancelled` flag now handled, `purchaseError` set with warm copy)
  - [x] 3.3 Update `isPremium` immediately on successful purchase via `customerInfo` response (existed from 6-2, verified)
  - [x] 3.4 Add loading state during purchase flow (existed from 6-2 via `isPurchasing`, verified)

- [x] Task 4: Gate chat access behind subscription check (AC: #1, #6, #7)
  - [x] 4.1 Add subscription check in ChatViewModel before `sendMessage()` (NEW — `shouldGateChat` guard)
  - [x] 4.2 If `!isPremium && !isTrialActive` → set flag to present paywall sheet (NEW — `showPaywall` + `pendingMessage`)
  - [x] 4.3 Wire paywall sheet presentation in ChatView via `.sheet(isPresented:)` (ENHANCED — `onChange(of: viewModel.showPaywall)` bridge)
  - [x] 4.4 On successful purchase, allow the pending message to send automatically (NEW — `sendPendingMessage()` called on paywall dismiss)

- [x] Task 5: Integrate SubscriptionViewModel into app lifecycle (AC: #6)
  - [x] 5.1 Initialize SubscriptionViewModel in AppEnvironment or inject via @Environment (existed from 6-2, verified)
  - [x] 5.2 Start `customerInfoStream` observation on app launch (NEW — called from `checkTrialStatus()`)
  - [x] 5.3 Ensure RevenueCat user is linked to Supabase user via `Purchases.shared.logIn(supabaseUserId)` (existed from 6-1 in AuthService, verified)

- [x] Task 6: Test subscription flow (AC: all)
  - [x] 6.1 Write unit tests for SubscriptionViewModel entitlement logic (NEW — purchase error, state transitions, gating)
  - [x] 6.2 Write unit tests for paywall presentation trigger logic (NEW — shouldGateChat across all states)
  - [ ] 6.3 Test with StoreKit configuration file in Xcode for sandbox testing (manual Xcode step — requires user to create .storekit config)

## Dev Notes

### Critical Dependencies — MUST be completed first
- **Story 6-1 (RevenueCat Integration)**: Provides `RevenueCatService.swift`, `Purchases.configure()`, API key in Configuration.swift, In-App Purchase entitlement in CoachMe.entitlements
- **Story 6-2 (Free Trial Experience)**: Provides `TrialBanner.swift`, trial tracking in SubscriptionViewModel, trial status detection

If 6-1 and 6-2 are not yet implemented, this story CANNOT be started. The developer must verify these prerequisites exist before beginning.

### Architecture Compliance

**Pattern**: MVVM + Repository | `@Observable` ViewModels | Feature module structure
```
Features/Subscription/
├── Views/
│   └── PaywallView.swift          ← CREATE (this story)
├── ViewModels/
│   └── SubscriptionViewModel.swift ← CREATE (this story, extends 6-1/6-2 if exists)
└── Services/
    └── RevenueCatService.swift     ← EXISTS from Story 6-1
```

**ViewModel Pattern** — Use `@Observable` (NOT `@ObservableObject`):
```swift
@MainActor @Observable
final class SubscriptionViewModel {
    var isPremium = false
    var offerings: Offerings?
    var purchaseError: AppError?
    var isLoading = false
    // ...
}
```

### RevenueCat SDK Integration (v5.58+)

**Key patterns the developer MUST follow:**

1. **Entitlement name**: Use `"pro"` as the entitlement identifier (match RevenueCat dashboard config)
2. **User linking**: After Supabase auth, call `Purchases.shared.logIn(supabaseUserId)` to associate RevenueCat anonymous ID with Supabase user
3. **Paywall approach**: Use RevenueCatUI's built-in `PaywallView` — this allows remote paywall configuration without app updates
4. **Purchase method**: Use `Purchases.shared.purchase(package:)` with async/await pattern
5. **Status checking**: Use `Purchases.shared.customerInfo()` for one-time check, `Purchases.shared.customerInfoStream` for real-time updates
6. **StoreKit 2**: SDK v5 uses StoreKit 2 by default on iOS 16+ — no manual transaction finishing needed
7. **Restore**: Use `Purchases.shared.restorePurchases()` — required by App Store guidelines

**DO NOT:**
- Call `SKPaymentQueue` or `Transaction.finish()` directly — RevenueCat handles this
- Store subscription status locally as source of truth — always check RevenueCat `customerInfo`
- Use the RevenueCat secret API key on the client — only use the public SDK key
- Skip the "Restore Purchases" button — App Store will reject without it

### RevenueCatUI PaywallView Integration

```swift
import RevenueCatUI

// Option A: Automatic presentation (RECOMMENDED)
ChatView()
    .presentPaywallIfNeeded(
        requiredEntitlementIdentifier: "pro"
    ) { customerInfo in
        // Purchase completed
    } restoreCompleted: { customerInfo in
        // Restore completed
    }

// Option B: Manual sheet (if more control needed)
.sheet(isPresented: $showPaywall) {
    PaywallView()
        .onPurchaseCompleted { customerInfo in
            showPaywall = false
        }
        .onRestoreCompleted { customerInfo in
            showPaywall = false
        }
}
```

### Chat Access Gating Pattern

The paywall should trigger in ChatViewModel when user tries to send a message:

```swift
// In ChatViewModel
func sendMessage(_ content: String) async {
    guard subscriptionVM.isPremium || subscriptionVM.isTrialActive else {
        showPaywall = true  // Triggers paywall sheet in ChatView
        pendingMessage = content  // Store for auto-send after purchase
        return
    }
    // ... proceed with normal send flow
}
```

### Error Messages — Warm, First-Person (UX-11)

| Scenario | Message |
|----------|---------|
| Purchase failed | "I couldn't complete that purchase. Let's try again when you're ready." |
| Restore failed | "I wasn't able to find a previous subscription. If you think this is wrong, reach out to support." |
| Network error during purchase | "I lost connection during the purchase. Don't worry — if you were charged, it'll show up shortly." |
| Subscription expired | (No error — just show paywall with warm welcome back) |

### Existing Code to Integrate With

- **ChatViewModel** (`Features/Chat/ViewModels/ChatViewModel.swift`): Add subscription guard to `sendMessage()`
- **ChatView** (`Features/Chat/Views/ChatView.swift`): Add `.sheet` for paywall presentation
- **AppEnvironment** (`App/Environment/AppEnvironment.swift`): May need SubscriptionViewModel injection
- **RootView** (`App/Navigation/RootView.swift`): May need to pass subscription state
- **AppError** (`Features/Chat/ViewModels/ChatError.swift`): Add `.subscriptionRequired` case if not present

### Adaptive Design Requirements

- Paywall container/toolbar: `.adaptiveGlass()` modifier
- Subscription option buttons: `.adaptiveInteractiveGlass()` modifier
- DO NOT apply glass to content text (pricing, descriptions)
- Test on both iOS 18 and iOS 26 simulators
- Both tiers must feel intentionally designed (UX-14)

### Testing Standards

- **Unit tests**: SubscriptionViewModel entitlement logic, paywall trigger conditions
- **StoreKit Configuration File**: Create `.storekit` config in Xcode for sandbox testing
- **Test scenarios**: Trial active → no paywall, trial expired → paywall, purchase success → dismiss, purchase cancel → stay, restore success → dismiss
- **Framework**: XCTest with `@MainActor` test classes
- **Coverage expectation**: ≥80% for SubscriptionViewModel

### Project Structure Notes

- All Subscription files go in `Features/Subscription/` (directory exists, currently empty)
- Follows same Feature module pattern as Chat, Context, History, Auth
- SubscriptionViewModel should be `@MainActor` per Swift 6 strict concurrency
- CodingKeys with snake_case if any Supabase models are involved

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Technology Stack] — RevenueCat + StoreKit 2
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — Features/Subscription/ layout
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — MVVM, @Observable, error handling
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3] — Acceptance criteria and technical notes
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 6 Overview] — FR33, FR34, FR36 coverage
- [Source: RevenueCat iOS SDK v5.58 docs] — Purchase flow, PaywallView, customerInfoStream patterns
- [Source: RevenueCat webhook docs] — Server-side subscription sync (for 6-1 webhook Edge Function)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Stories 6-1 and 6-2 (both in "review" status) provided prerequisite code: SubscriptionService, SubscriptionViewModel (base), PaywallView, TrialBanner, RevenueCat configuration, trial tracking
- Entitlement identifier uses "premium" (per 6-1 convention) instead of "pro" (as written in story Dev Notes) — existing code consistency preserved
- Task 2.2 kept custom PaywallView (from 6-2) instead of switching to RevenueCatUI's built-in PaywallView — custom view matches warm design system and adaptive glass styling
- Task 6.3 (StoreKit configuration file) is a manual Xcode step — cannot be automated

### Completion Notes List

- **Task 1**: SubscriptionViewModel enhanced with `startCustomerInfoStream()` for real-time subscription status updates via `Purchases.shared.customerInfoStream`. Existing features from 6-1/6-2 verified intact.
- **Task 2**: PaywallView enhanced with `purchaseError` display — warm, terracotta-styled error message shown below package list with VoiceOver accessibility.
- **Task 3**: Purchase flow enhanced — `userCancelled` flag now properly handled (silent stay on paywall), `purchaseError` set with UX-11 warm copy on failure. Restore also sets warm error on failure.
- **Task 4**: Chat access gated in ChatViewModel.sendMessage() — `shouldGateChat` check stores `pendingMessage` and triggers `showPaywall`. ChatView bridges ViewModel trigger to local sheet state. On paywall dismiss after purchase, `sendPendingMessage()` auto-sends the queued message.
- **Task 5**: `startCustomerInfoStream()` called automatically from `checkTrialStatus()` (which runs on app launch). User linking via `Purchases.shared.logIn()` confirmed in AuthService from 6-1.
- **Task 6**: 12 new unit tests added covering purchase error handling, state transitions, chat gating logic, and warm copy verification.

### Change Log
- 2026-02-08: Story created with comprehensive developer context by create-story workflow
- 2026-02-09: Story implemented — customerInfoStream listener, purchase error handling, chat access gating with pending message auto-send, PaywallView error display, unit tests

### File List
- CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift (MODIFIED — customerInfoStream, purchaseError, enhanced purchase/restore)
- CoachMe/CoachMe/Features/Subscription/Views/PaywallView.swift (MODIFIED — error message display)
- CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift (MODIFIED — subscription gate, showPaywall, pendingMessage, sendPendingMessage)
- CoachMe/CoachMe/Features/Chat/Views/ChatView.swift (MODIFIED — paywall onDismiss auto-send, onChange bridge for ViewModel paywall trigger)
- CoachMe/CoachMeTests/SubscriptionServiceTests.swift (MODIFIED — 12 new Story 6.3 tests)
