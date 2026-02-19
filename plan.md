# Plan: IAP + Monthly Subscription Model

## Context
Currently the app uses a single monthly subscription ($19.99) with a $2.99/1-week intro offer. The new model uses a **separate $3 one-time IAP** (non-renewing subscription in App Store Connect) for 3-day access, alongside the monthly subscription. Both are configured in RevenueCat as packages in the same offering. The paywall renders RevenueCat packages dynamically — no hardcoded product IDs.

## User Flow
1. Onboarding → Discovery → Paywall shows **both** IAP ($3) and monthly subscription
2. User **must** purchase one to proceed
3. If IAP chosen → 3-day access, nudge on day 3 to convert to monthly
4. If monthly chosen → fully subscribed, no nudge needed

## Changes Required (6 files)

### 1. `TrialManager.swift` — Distinguish IAP from subscription in `refreshState()`

**Problem**: `refreshState()` calls `isEntitled(to: "premium")` and if true, sets `currentState = .subscribed`. Both IAP and subscription grant the "premium" entitlement, so the IAP would incorrectly become `.subscribed`.

**Fix**:
- Replace the simple `isEntitled` check with `fetchCustomerInfo()`
- Check if the entitlement's product is in `customerInfo.activeSubscriptions` (which only contains auto-renewing products)
- If auto-renewing → `.subscribed`
- If NOT auto-renewing (IAP) → fall through to trial tracking via `trial_activated_at`

```swift
// In refreshState():
let customerInfo = try? await subscriptionService.fetchCustomerInfo()
if let entitlement = customerInfo?.entitlements["premium"], entitlement.isActive {
    let isAutoRenewing = customerInfo?.activeSubscriptions.contains(entitlement.productIdentifier) ?? false
    if isAutoRenewing {
        currentState = .subscribed
        return
    }
    // Non-renewing IAP — fall through to trial_activated_at tracking
}
```

This is generic — no hardcoded product IDs. It just checks whether the active product auto-renews.

---

### 2. `SubscriptionViewModel.swift` — Multiple changes

#### 2a. `purchase()` — Differentiate IAP vs subscription after purchase

**Currently**: Always calls `TrialManager.activateTrial()` after any purchase.
**Change**: Check `package.storeProduct.productType`:
- `.autoRenewableSubscription` → set `.subscribed` directly, cancel trial notification
- Anything else (non-renewing, consumable) → call `activateTrial()`, schedule notification

#### 2b. `startCustomerInfoStream()` — Replace `.intro` period detection

**Currently**: Checks `entitlement.periodType == .intro` to detect trial.
**Change**: Check `customerInfo.activeSubscriptions.contains(entitlement.productIdentifier)`:
- If true → auto-renewing → `.subscribed`
- If false → non-renewing IAP → refresh TrialManager

#### 2c. Add `subscriptionOnlyPackages` computed property

For post-trial paywalls, filter out the IAP and only show subscriptions:
```swift
var subscriptionOnlyPackages: [Package] {
    availablePackages.filter { $0.storeProduct.productType == .autoRenewableSubscription }
}
```

#### 2d. Update notification copy

Change from: "Your Coach App trial wraps up tomorrow. Want to keep our conversations going?"
To: "Your 3-day access ends today — subscribe to keep the conversation going."

Also update scheduling to fire on the **expiration day at 10 AM** (currently fires 1 day before — which is actually already day 3 for a 3-day trial, but the copy implies "tomorrow"). Change `-1` to `0` days offset from expiration:
```swift
// Fire on the expiration day at 10 AM
var components = Calendar.current.dateComponents([.year, .month, .day], from: expirationDate)
components.hour = 10
components.minute = 0
```

---

### 3. `PaywallView.swift` — Use filtered packages post-trial

**Change**: Accept a `packages` parameter (defaults to `subscriptionViewModel.availablePackages`). When triggered from trial expiration or message exhaustion, pass `subscriptionViewModel.subscriptionOnlyPackages` so the IAP doesn't appear again.

**Copy updates**:
- `.messagesExhausted` hero: Remove "refreshes when your monthly subscription begins on [date]" → "You've used all your conversations for now. Subscribe to continue."
- `.trialExpired` hero: "Your 3-day access has ended" (already close, minor tweak)

Also update last-day `.messagesExhausted` to not reference auto-conversion.

---

### 4. `PersonalizedPaywallView.swift` — No filtering (show all packages)

This is the post-discovery paywall where both options should appear. **Minimal change** — just ensure it still uses `subscriptionViewModel.availablePackages` (which it already does). No content changes needed.

---

### 5. `TrialBanner.swift` — Update last-day copy

**Currently**: "Last day of your trial — want to keep going? Your subscription continues automatically."
**Change**: "Last day of your 3-day access — subscribe to keep the conversation going."

The IAP does NOT auto-renew, so "continues automatically" is wrong.

---

### 6. `CoachMeStoreKitConfiguration.storekit` — Add IAP product for local testing

Add a non-renewing subscription product to the StoreKit config so the IAP can be tested locally:
```json
"nonRenewingSubscriptions": [
  {
    "displayPrice": "2.99",
    "localizations": [{ "description": "3 days of coaching access", "displayName": "3-Day Access", "locale": "en_US" }],
    "productID": "coach_app_3day_access",
    "referenceName": "3-Day Access"
  }
]
```

---

## What Does NOT Need Code Changes

| Concern | Why no change needed |
|---------|---------------------|
| Adding future plans (yearly, etc.) | RevenueCat offering drives the UI dynamically |
| Pricing changes | RevenueCat dashboard, no code |
| `OnboardingCoordinator` | Flow states unchanged — still welcome → discovery → paywall → paidChat |
| `TrialManager` state machine | States remain the same (discovery, trialActive, trialExpired, subscribed, blocked) |
| Server-side `activate_trial` RPC | Still called for IAP purchases, same behavior |
| Chat gating logic | `shouldGateChat` already works correctly for trialExpired/blocked states |

## Test Impact

Tests to update:
- `SubscriptionServiceTests` — no change (service API unchanged)
- `PaidTrialConfigurationTests` — update to reflect new product type checks
- `SubscriptionManagementViewModelTests` — if it checks trial state mapping
- `TrialManagerTests` — update `refreshState` tests for auto-renewing vs non-renewing

Tests to run after changes:
```
-only-testing:CoachMeTests/TrialManagerTests
-only-testing:CoachMeTests/PaidTrialConfigurationTests
-only-testing:CoachMeTests/SubscriptionManagementViewModelTests
```
