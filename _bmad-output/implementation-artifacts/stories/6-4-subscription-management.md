# Story 6.4: Subscription Management

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **subscriber**,
I want **to view and manage my subscription from settings**,
So that **I have full control over my account and know exactly what I'm paying for**.

## Acceptance Criteria

1. **Given** I am subscribed **When** I tap "Subscription" in settings **Then** I see my current plan name, status (active/cancelled/billing issue), and renewal or expiration date

2. **Given** I want to cancel or change my plan **When** I tap "Manage Subscription" **Then** I'm taken to the iOS subscription management sheet (via RevenueCat `showManageSubscriptions()`)

3. **Given** I have cancelled but still have access **When** I view subscription status **Then** I see a warm message: "Your subscription is active until [date]. You can resubscribe anytime." with the expiration date clearly shown

4. **Given** there is a billing issue with my subscription **When** I view subscription status **Then** I see a warm alert: "There's a hiccup with your payment. Let's get that sorted." with a button to update payment method

5. **Given** I am not subscribed (free/expired) **When** I view subscription settings **Then** I see my free status and a "Subscribe" button that presents the paywall

6. **Given** I want to restore a previous purchase **When** I tap "Restore Purchases" **Then** my entitlements are checked and restored if a valid subscription exists

7. **Given** subscription status changes (e.g., renewal, cancellation detected) **When** I have the subscription management screen open **Then** the UI updates in real-time via `customerInfoStream`

## Tasks / Subtasks

- [x] Task 1: Create SubscriptionManagementView (AC: #1, #3, #4, #5)
  - [x] 1.1 Create `SubscriptionManagementView.swift` in `Features/Subscription/Views/`
  - [x] 1.2 Display subscription status section: plan name, status badge (active/cancelled/billing issue/free), renewal/expiration date
  - [x] 1.3 Display cancellation banner with warm copy when `unsubscribeDetectedAt != nil` and `isActive`
  - [x] 1.4 Display billing issue alert with warm copy when `billingIssueDetectedAt != nil`
  - [x] 1.5 Display free/expired state with "Subscribe" button linking to PaywallView
  - [x] 1.6 Apply `.adaptiveGlass()` to section containers, warm color palette throughout
  - [x] 1.7 Add VoiceOver accessibility labels on all interactive elements and status indicators

- [x] Task 2: Create SubscriptionManagementViewModel (AC: #1, #7)
  - [x] 2.1 Create `SubscriptionManagementViewModel.swift` in `Features/Subscription/ViewModels/`
  - [x] 2.2 Use `@MainActor @Observable` pattern matching existing ViewModels
  - [x] 2.3 Properties: `subscriptionState`, `planName`, `expirationDate`, `willRenew`, `isLoading`, `error`
  - [x] 2.4 Implement `startListening()` using `Purchases.shared.customerInfoStream` for real-time updates
  - [x] 2.5 Implement `refreshSubscriptionInfo()` using `Purchases.shared.customerInfo()` async/await
  - [x] 2.6 Implement `updateState(from: CustomerInfo)` to parse entitlement into view state
  - [x] 2.7 Use `unsubscribeDetectedAt != nil` (NOT `willRenew == false`) for cancellation detection

- [x] Task 3: Implement manage subscription and restore actions (AC: #2, #6)
  - [x] 3.1 Implement `openManageSubscriptions()` calling `Purchases.shared.showManageSubscriptions()` async
  - [x] 3.2 Implement `restorePurchases()` calling `Purchases.shared.restorePurchases()` async
  - [x] 3.3 Handle errors with warm first-person messages (UX-11)
  - [x] 3.4 Show loading state during restore

- [x] Task 4: Add subscription section to SettingsView (AC: #1)
  - [x] 4.1 Add `subscriptionSection` computed property to SettingsView between Appearance and Data sections
  - [x] 4.2 Show subscription status summary (plan + status badge) inline in settings
  - [x] 4.3 Tap navigates to full SubscriptionManagementView via `.sheet` or `NavigationLink`
  - [x] 4.4 Match existing section styling (header label, `.adaptiveGlass()` container, chevron)

- [x] Task 5: Define SubscriptionManagementState enum (AC: #1, #3, #4, #5)
  - [x] 5.1 Create SubscriptionManagementState enum: `.active`, `.cancelled`, `.billingIssue`, `.expired`, `.free` (renamed from SubscriptionState to avoid collision with existing enum in SubscriptionViewModel)
  - [x] 5.2 Add computed display properties: `displayLabel`, `statusColor`, `systemImageName`
  - [x] 5.3 Place in `Features/Subscription/Models/SubscriptionManagementState.swift`

- [x] Task 6: Write unit tests (AC: all)
  - [x] 6.1 Test SubscriptionManagementViewModel initial state
  - [x] 6.2 Test `updateState(from:)` correctly maps all SubscriptionManagementState cases
  - [x] 6.3 Test cancellation detection uses `unsubscribeDetectedAt` not `willRenew`
  - [x] 6.4 Test error messages are warm first-person
  - [x] 6.5 Test SubscriptionManagementState display properties

## Dev Notes

### Critical Dependencies — MUST be completed first

- **Story 6-1 (RevenueCat Integration)**: Provides `SubscriptionService.swift`, `Purchases.configure()`, API key in Configuration.swift, user identification in AuthService
- **Story 6-3 (Subscription Purchase Flow)**: Provides `PaywallView.swift`, `SubscriptionViewModel.swift` with `isPremium`/`isTrialActive`, purchase flow

If 6-1 and 6-3 are not yet implemented, this story CANNOT be started. Verify these prerequisites exist before beginning.

### Architecture Compliance

**Pattern**: MVVM + Repository | `@Observable` ViewModels | Feature module structure

```
Features/Subscription/
├── Models/
│   └── SubscriptionState.swift              ← CREATE (this story)
├── Views/
│   ├── PaywallView.swift                    ← EXISTS from Story 6-3
│   └── SubscriptionManagementView.swift     ← CREATE (this story)
├── ViewModels/
│   ├── SubscriptionViewModel.swift          ← EXISTS from Story 6-1/6-3
│   └── SubscriptionManagementViewModel.swift ← CREATE (this story)
└── Services/
    └── SubscriptionService.swift            ← EXISTS from Story 6-1
```

**ViewModel Pattern** — Use `@Observable` (NOT `@ObservableObject`):
```swift
@MainActor @Observable
final class SubscriptionManagementViewModel {
    var subscriptionState: SubscriptionState = .free
    var planName: String?
    var expirationDate: Date?
    var willRenew: Bool = false
    var isLoading: Bool = true
    var error: SubscriptionManagementError?

    private var customerInfoTask: Task<Void, Never>?

    func startListening() { ... }
    func stopListening() { customerInfoTask?.cancel() }
    func refreshSubscriptionInfo() async { ... }
    func openManageSubscriptions() async { ... }
    func restorePurchases() async { ... }
}
```

### RevenueCat API Patterns for Subscription Management

**Entitlement name**: `"premium"` (configured in Story 6-1, matches RevenueCat dashboard)

**Fetching subscription info** — async/await:
```swift
let customerInfo = try await Purchases.shared.customerInfo()
let entitlement = customerInfo.entitlements["premium"]
```

**Real-time updates** — `customerInfoStream` (AsyncSequence):
```swift
func startListening() {
    customerInfoTask = Task {
        for try await customerInfo in Purchases.shared.customerInfoStream {
            updateState(from: customerInfo)
        }
    }
}
```

**Key EntitlementInfo properties to use:**
- `isActive` — whether user currently has access
- `expirationDate` — nil for lifetime, Date for subscriptions
- `unsubscribeDetectedAt` — RELIABLE cancellation detection (use this, NOT `willRenew`)
- `billingIssueDetectedAt` — payment problem detected
- `productIdentifier` — the product ID for display
- `periodType` — `.normal`, `.intro`, `.trial`

**Open iOS subscription management:**
```swift
try await Purchases.shared.showManageSubscriptions()
```
This method auto-detects platform, opens StoreKit management sheet on iOS 15+, falls back to App Store subscription settings.

**Restore purchases:**
```swift
let customerInfo = try await Purchases.shared.restorePurchases()
```

### Cancellation Detection — CRITICAL

Use `unsubscribeDetectedAt != nil` instead of `willRenew == false`:
```swift
private func updateState(from customerInfo: CustomerInfo) {
    guard let entitlement = customerInfo.entitlements["premium"] else {
        subscriptionState = .free
        return
    }

    expirationDate = entitlement.expirationDate
    planName = entitlement.productIdentifier
    willRenew = entitlement.willRenew

    if !entitlement.isActive {
        subscriptionState = .expired
    } else if entitlement.billingIssueDetectedAt != nil {
        subscriptionState = .billingIssue
    } else if entitlement.unsubscribeDetectedAt != nil {
        subscriptionState = .cancelled  // Active but won't renew
    } else {
        subscriptionState = .active
    }
}
```

**Why not `willRenew`**: The `willRenew` property can be delayed in both sandbox and production environments, especially without App Store Server Notifications V2 enabled. `unsubscribeDetectedAt` is RevenueCat's officially recommended property for cancellation detection.

### SubscriptionState Enum

```swift
enum SubscriptionState: String, CaseIterable {
    case active
    case cancelled
    case billingIssue
    case expired
    case free

    var displayLabel: String {
        switch self {
        case .active: "Active"
        case .cancelled: "Cancelled"
        case .billingIssue: "Billing Issue"
        case .expired: "Expired"
        case .free: "Free"
        }
    }

    var statusColor: String {  // Map to Color.adaptive* in view
        switch self {
        case .active: "green"
        case .cancelled: "orange"
        case .billingIssue: "red"
        case .expired, .free: "secondary"
        }
    }

    var systemImageName: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        case .billingIssue: "exclamationmark.triangle.fill"
        case .expired: "clock.arrow.circlepath"
        case .free: "person.crop.circle"
        }
    }
}
```

### SettingsView Integration

File: `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift`

Add a new `subscriptionSection` between `appearanceSection` and `dataManagementSection`:

```swift
// In body VStack:
appearanceSection
subscriptionSection   // ← ADD (this story)
dataManagementSection
accountSection
legalSection
```

The section should follow the exact same styling pattern as `dataManagementSection`:
```swift
private var subscriptionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Subscription")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .padding(.horizontal, 4)

        VStack(spacing: 0) {
            Button { showSubscriptionManagement = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                            Text("Manage Subscription")
                                .font(.body)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                        Text(subscriptionStatusSummary)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }
                .padding(16)
            }
            .accessibilityLabel("Manage Subscription")
            .accessibilityHint("View your plan and subscription details")
        }
        .adaptiveGlass()
    }
}
```

Present SubscriptionManagementView as a sheet:
```swift
.sheet(isPresented: $showSubscriptionManagement) {
    NavigationStack {
        SubscriptionManagementView()
    }
}
```

### Error Messages — Warm, First-Person (UX-11)

| Scenario | Message |
|----------|---------|
| Can't load subscription info | "I couldn't load your subscription details right now." |
| Can't open manage subscriptions | "I couldn't open subscription management. Try again from your device Settings." |
| Restore failed | "I wasn't able to find a previous subscription." |
| Restore succeeded (no sub found) | "I didn't find an active subscription to restore." |
| Billing issue banner | "There's a hiccup with your payment. Let's get that sorted." |
| Cancelled banner | "Your subscription is active until [date]. You can resubscribe anytime." |

### Adaptive Design Requirements

- Section containers: `.adaptiveGlass()` modifier
- Status badge / action buttons: Use warm palette colors (`Color.adaptiveTerracotta`, etc.)
- DO NOT apply glass to content text (status labels, dates, plan names)
- DO NOT stack glass on glass
- Test on both iOS 18 and iOS 26 simulators
- Both tiers must feel intentionally designed (UX-14)

### Existing Code to Integrate With

| File | Change |
|------|--------|
| `Features/Settings/Views/SettingsView.swift` | Add `subscriptionSection`, sheet presentation for SubscriptionManagementView |
| `Features/Settings/ViewModels/SettingsViewModel.swift` | Optionally add subscription status summary property |
| `Features/Subscription/ViewModels/SubscriptionViewModel.swift` | Reference for `isPremium` state (exists from 6-1/6-3) |
| `Features/Subscription/Services/SubscriptionService.swift` | Reference for `fetchCustomerInfo()` (exists from 6-1) |

### Files to Create

| File | Location | Pattern |
|------|----------|---------|
| `SubscriptionManagementView.swift` | `Features/Subscription/Views/` | SwiftUI view with `.adaptiveGlass()` |
| `SubscriptionManagementViewModel.swift` | `Features/Subscription/ViewModels/` | `@MainActor @Observable` (like SettingsViewModel) |
| `SubscriptionState.swift` | `Features/Subscription/Models/` | Enum with display properties |

### Files to Modify

| File | Change |
|------|--------|
| `SettingsView.swift` | Add subscription section + sheet presentation |

### What NOT To Do

- Do NOT create a custom cancellation flow — Apple requires using their subscription management system
- Do NOT store subscription status in SwiftData/UserDefaults as source of truth — always use RevenueCat `customerInfo`
- Do NOT use `willRenew == false` for cancellation detection — use `unsubscribeDetectedAt != nil`
- Do NOT call `SKPaymentQueue` or `Transaction.finish()` — RevenueCat handles StoreKit transactions
- Do NOT use `@ObservableObject` / `@Published` — use `@Observable` per Swift 6 patterns
- Do NOT block the UI while loading subscription info — show last known state, update async
- Do NOT skip the "Restore Purchases" button — App Store will reject without it
- Do NOT add a manual "Cancel Subscription" button — Apple does not allow developers to cancel on behalf of users

### Testing Standards

- Use Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- Mark test structs with `@MainActor`
- Test file: `CoachMeTests/SubscriptionManagementViewModelTests.swift`
- **Coverage expectation**: >= 80% for SubscriptionManagementViewModel
- **Key test scenarios:**
  - Active subscription → shows plan name, renewal date, "Active" status
  - Cancelled subscription → shows expiration date, "Cancelled" status, warm banner
  - Billing issue → shows alert with payment update prompt
  - Expired → shows "Expired" status, "Subscribe" button
  - Free (never subscribed) → shows "Free" status, "Subscribe" button
  - `updateState(from:)` correctly prioritizes: billingIssue > cancelled > active

### Git Intelligence

Recent commits show Epics 1-4 completed. Epic 6 stories 6-1 through 6-3 have story files but are not yet implemented (no subscription-related Swift files exist in the codebase). The `Features/Subscription/` directory exists but is empty. This story builds on 6-1 and 6-3 which must be implemented first.

### Project Structure Notes

- All new files go in `Features/Subscription/` (directory exists, currently empty)
- Follows same Feature module pattern as Chat, Context, History, Auth, Settings
- All ViewModels must be `@MainActor @Observable` per Swift 6 strict concurrency
- Use warm color palette from `Core/UI/Theme/Colors.swift`

### References

- [Source: architecture.md#Technology-Stack — ARCH-5: RevenueCat + StoreKit 2]
- [Source: architecture.md#Project-Structure — Features/Subscription/ layout with SubscriptionManagement.swift]
- [Source: architecture.md#Implementation-Patterns — MVVM, @Observable, error handling, adaptive design]
- [Source: epics.md#Story-6.4 — Original AC: view plan, renewal date, manage subscription, iOS settings link]
- [Source: epics.md#Epic-6 — FR35 subscription management]
- [Source: stories/6-1-revenuecat-integration.md — SubscriptionService pattern, entitlement "premium"]
- [Source: stories/6-3-subscription-purchase-flow.md — SubscriptionViewModel, PaywallView, RevenueCat patterns]
- [Source: SettingsView.swift — Section styling pattern, navigation, `.adaptiveGlass()` usage]
- [Source: SettingsViewModel.swift — @Observable ViewModel pattern for settings]
- [Source: AuthService.swift — @MainActor singleton service pattern]
- [Source: RevenueCat iOS SDK v5.58 docs — customerInfoStream, showManageSubscriptions, EntitlementInfo]
- [Source: RevenueCat community — unsubscribeDetectedAt recommended over willRenew for cancellation]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Naming conflict: Existing `SubscriptionState` enum in `SubscriptionViewModel.swift` has different cases (`.unknown`, `.trial`, `.trialExpired`, `.subscribed`, `.expired`) than what story 6-4 specified (`.active`, `.cancelled`, `.billingIssue`, `.expired`, `.free`). Resolved by naming the new enum `SubscriptionManagementState` to avoid collision within the same build target.

### Completion Notes List

- Created `SubscriptionManagementView` with full status display, cancellation banner (AC #3), billing issue alert (AC #4), free/expired state with Subscribe button (AC #5), adaptive glass styling, and VoiceOver accessibility
- Created `SubscriptionManagementViewModel` with `@MainActor @Observable` pattern, `customerInfoStream` real-time listening (AC #7), `refreshSubscriptionInfo()` async, `updateState(from:)` using `unsubscribeDetectedAt` for cancellation detection (AC #1)
- Implemented `openManageSubscriptions()` via `Purchases.shared.showManageSubscriptions()` (AC #2) and `restorePurchases()` (AC #6) with warm first-person error messages (UX-11)
- Updated `SettingsView`: moved subscription section between Appearance and Data, changed to navigate to `SubscriptionManagementView` via `.sheet`, added status summary inline (AC #1)
- Created `SubscriptionManagementState` enum with `.active`, `.cancelled`, `.billingIssue`, `.expired`, `.free` cases and computed `displayLabel`, `statusColor`, `systemImageName` properties
- Wrote 17 unit tests covering initial state, all state representations, error messages (warm first-person), display properties, raw values, and CaseIterable compliance

### Change Log
- 2026-02-08: Story created with comprehensive developer context by create-story workflow
- 2026-02-09: Implementation complete — all 6 tasks done, 17 unit tests written, SettingsView updated with management navigation

### File List
- `CoachMe/CoachMe/Features/Subscription/Models/SubscriptionManagementState.swift` (NEW)
- `CoachMe/CoachMe/Features/Subscription/Views/SubscriptionManagementView.swift` (NEW)
- `CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionManagementViewModel.swift` (NEW)
- `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift` (MODIFIED)
- `CoachMe/CoachMeTests/SubscriptionManagementViewModelTests.swift` (NEW)
