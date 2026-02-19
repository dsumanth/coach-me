# Story 6.1: RevenueCat Integration

Status: review

## Story

As a **developer**,
I want **RevenueCat configured for subscription management**,
so that **payments work reliably without manual StoreKit complexity**.

## Acceptance Criteria

1. **Given** RevenueCat SDK is installed **When** I configure it with API keys **Then** it initializes successfully on app launch with debug logging in DEBUG builds
2. **Given** a user signs in with Apple **When** authentication completes **Then** the user is identified with RevenueCat using their Supabase user ID and subscription status syncs
3. **Given** a user signs out **When** sign-out completes **Then** RevenueCat is reset to anonymous user via `Purchases.shared.logOut()`
4. **Given** the app launches with a returning user **When** session is restored **Then** RevenueCat re-identifies the user and entitlement status is available
5. **Given** RevenueCat is configured **When** I check entitlements **Then** I can determine if user has active "premium" entitlement via `customerInfo.entitlements.all["premium"]?.isActive`
6. **Given** RevenueCat initialization fails **When** the error is caught **Then** app continues without subscription features and logs the error (non-blocking)

## Tasks / Subtasks

- [x] Task 1: Add RevenueCat API key to configuration pipeline (AC: #1)
  - [x] 1.1 Add `REVENUECAT_API_KEY` to `Config.xcconfig.template`
  - [x] 1.2 Add `revenueCatAPIKey` static property to `Configuration.swift` reading from Info.plist
  - [x] 1.3 Add `RevenueCatAPIKey` entry to Info.plist (via xcconfig injection)
  - [x] 1.4 Update `Configuration.validateConfiguration()` to validate RevenueCat key
- [x] Task 2: Initialize RevenueCat SDK in CoachMeApp (AC: #1, #6)
  - [x] 2.1 Add `import RevenueCat` to `CoachMeApp.swift`
  - [x] 2.2 Call `Purchases.logLevel = .debug` in DEBUG builds
  - [x] 2.3 Call `Purchases.configure(withAPIKey: Configuration.revenueCatAPIKey)` in `init()`
  - [x] 2.4 Wrap in do/catch — app must launch even if RevenueCat fails
- [x] Task 3: Create SubscriptionService (AC: #2, #3, #4, #5)
  - [x] 3.1 Create `Features/Subscription/Services/SubscriptionService.swift`
  - [x] 3.2 Follow `@MainActor` singleton pattern matching AuthService
  - [x] 3.3 Implement `identifyUser(userId: UUID)` calling `Purchases.shared.logIn(userId.uuidString)`
  - [x] 3.4 Implement `logOutUser()` calling `Purchases.shared.logOut()`
  - [x] 3.5 Implement `isEntitled(to entitlementId: String) async -> Bool` checking CustomerInfo
  - [x] 3.6 Implement `fetchCustomerInfo() async throws -> CustomerInfo`
  - [x] 3.7 Add `SubscriptionError` enum with warm first-person messages (UX-11)
- [x] Task 4: Integrate with AuthService sign-in/sign-out flow (AC: #2, #3, #4)
  - [x] 4.1 After successful `signInWithApple()` in AuthService, call `SubscriptionService.shared.identifyUser(userId:)`
  - [x] 4.2 After successful `restoreSession()` in AuthService, call `SubscriptionService.shared.identifyUser(userId:)`
  - [x] 4.3 In `signOut()`, call `SubscriptionService.shared.logOutUser()` before clearing session
  - [x] 4.4 All RevenueCat calls in AuthService are non-blocking (failures don't break auth)
- [x] Task 5: Create SubscriptionViewModel (AC: #5)
  - [x] 5.1 Create `Features/Subscription/ViewModels/SubscriptionViewModel.swift`
  - [x] 5.2 Use `@MainActor @Observable` pattern matching other ViewModels
  - [x] 5.3 Properties: `isPremium: Bool`, `isLoading: Bool`, `error: SubscriptionError?`
  - [x] 5.4 Implement `checkEntitlements() async` that updates `isPremium`
- [x] Task 6: Write unit tests (AC: #1-#6)
  - [x] 6.1 Create `CoachMeTests/SubscriptionServiceTests.swift`
  - [x] 6.2 Test: SubscriptionService initializes as singleton
  - [x] 6.3 Test: SubscriptionViewModel initial state is correct
  - [x] 6.4 Test: Error enum provides warm first-person messages
  - [x] 6.5 Test: Configuration.revenueCatAPIKey reads from Info.plist

## Dev Notes

### Critical: RevenueCat SDK Already Installed

The `purchases-ios` package (v5.57.1) is **already added** as an SPM dependency in the Xcode project. Do NOT add it again. Just `import RevenueCat` in Swift files.

### Architecture Compliance (ARCH-5)

- **Pattern**: RevenueCat + StoreKit 2 per architecture.md
- **API Boundary**: iOS App communicates with RevenueCat via Native SDK (RevenueCat API key auth)
- **No payment data stored locally** — RevenueCat SDK manages its own cache
- **Server-side receipt validation** handled by RevenueCat automatically

### Service Pattern — Follow AuthService Exactly

File: `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift`

SubscriptionService must mirror the AuthService pattern:

```swift
@MainActor
final class SubscriptionService {
    static let shared = SubscriptionService()

    enum SubscriptionError: LocalizedError {
        case identifyFailed(Error)
        case entitlementCheckFailed(Error)
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .identifyFailed:
                return "I had trouble syncing your subscription. Let's try again."
            case .entitlementCheckFailed:
                return "I couldn't check your subscription status right now."
            case .notConfigured:
                return "Subscription features aren't available yet."
            }
        }
    }

    private init() {}

    func identifyUser(userId: UUID) async throws { ... }
    func logOutUser() async throws { ... }
    func isEntitled(to entitlementId: String = "premium") async -> Bool { ... }
    func fetchCustomerInfo() async throws -> CustomerInfo { ... }
}
```

### Configuration Pattern — Follow Existing xcconfig Pipeline

File: `CoachMe/CoachMe/App/Environment/Configuration.swift`

Add to Configuration.swift following the exact Supabase pattern:

```swift
static var revenueCatAPIKey: String {
    guard let key = envValue(for: "RevenueCatAPIKey"), !key.isEmpty else {
        #if DEBUG
        print("Warning: RevenueCatAPIKey not configured. Subscription features disabled.")
        return ""
        #else
        fatalError("RevenueCatAPIKey not configured.")
        #endif
    }
    return key
}
```

**IMPORTANT**: Unlike Supabase (which fatalErrors on missing key), RevenueCat should return empty string in DEBUG to allow development without a key configured. Only fatalError in release builds.

### CoachMeApp.swift Initialization

File: `CoachMe/CoachMe/CoachMeApp.swift`

Add to `init()` after Sentry setup:

```swift
init() {
    // ... existing Sentry setup ...

    // RevenueCat SDK initialization (Story 6.1)
    let rcKey = Configuration.revenueCatAPIKey
    if !rcKey.isEmpty {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: rcKey)
    } else {
        #if DEBUG
        print("RevenueCat: API key not configured, subscription features disabled")
        #endif
    }
}
```

### AuthService Integration Points

File: `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift`

Add these calls (all non-blocking):

1. **After `signInWithApple()` succeeds** (after `ensureContextProfileExists`):
```swift
// Identify user with RevenueCat (Story 6.1) - non-blocking
Task {
    try? await SubscriptionService.shared.identifyUser(userId: session.user.id)
}
```

2. **After `restoreSession()` succeeds** (after setting currentUser):
```swift
// Re-identify with RevenueCat (Story 6.1) - non-blocking
Task {
    try? await SubscriptionService.shared.identifyUser(userId: session.user.id)
}
```

3. **In `signOut()` before clearing session**:
```swift
// Log out from RevenueCat (Story 6.1) - non-blocking
try? await SubscriptionService.shared.logOutUser()
```

### RevenueCat API Key Details

- **Key type**: Public Apple API key from RevenueCat Dashboard > Project Settings > API Keys
- **Safe for client**: Yes, this is a publishable key (like Supabase publishable key)
- **EntitlementID**: Use `"premium"` as the entitlement identifier (configure in RevenueCat dashboard)
- **StoreKit 2**: SDK v5.x uses StoreKit 2 by default on iOS 16+; our iOS 18+ minimum is fully supported

### RevenueCat User Identification

- Use **Supabase user UUID** as the RevenueCat app user ID: `Purchases.shared.logIn(userId.uuidString)`
- This links the Supabase user to their RevenueCat subscription
- On sign-out, call `Purchases.shared.logOut()` to reset to anonymous
- RevenueCat handles anonymous-to-identified user migration automatically

### Config.xcconfig.template Addition

File: `CoachMe/Config.xcconfig.template`

Add after the Supabase keys:
```
// RevenueCat API Key (public Apple API key from RevenueCat Dashboard)
REVENUECAT_API_KEY = your_revenuecat_public_api_key_here
```

### Files to Create

| File | Location | Pattern |
|------|----------|---------|
| `SubscriptionService.swift` | `Features/Subscription/Services/` | @MainActor singleton (like AuthService) |
| `SubscriptionViewModel.swift` | `Features/Subscription/ViewModels/` | @MainActor @Observable (like SettingsViewModel) |
| `SubscriptionServiceTests.swift` | `CoachMeTests/` | Testing framework with #expect |

### Files to Modify

| File | Change |
|------|--------|
| `CoachMeApp.swift` | Add `import RevenueCat`, configure SDK in `init()` |
| `Configuration.swift` | Add `revenueCatAPIKey` static property |
| `Config.xcconfig.template` | Add `REVENUECAT_API_KEY` placeholder |
| `AuthService.swift` | Add RevenueCat identify/logout calls (non-blocking) |

### What NOT To Do

- Do NOT add RevenueCat SPM package again — it's already installed (v5.57.1)
- Do NOT store any payment/subscription data in SwiftData or Keychain — RevenueCat manages its own cache
- Do NOT create a RevenueCat webhook Edge Function yet — that's a separate concern for server-side events
- Do NOT create PaywallView, TrialBanner, or SubscriptionManagement views — those are Stories 6.2-6.4
- Do NOT add subscription checks to chat flow — paywall gating comes in Story 6.3
- Do NOT use `@ObservableObject` or `@Published` — use `@Observable` per Swift 6 / iOS 18+ patterns
- Do NOT block app launch if RevenueCat fails — subscription is optional for app functionality

### Project Structure Notes

- `Features/Subscription/` directory already exists but is empty — create `Services/`, `ViewModels/` subdirectories
- Follows feature module pattern: `Features/{Feature}/Services/`, `Features/{Feature}/ViewModels/`, `Features/{Feature}/Views/`
- No Views needed for this story (views come in Stories 6.2-6.4)

### Testing Standards

- Use Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- Mark test structs with `@MainActor`
- Inject mock dependencies via init parameters
- Test file: `CoachMeTests/SubscriptionServiceTests.swift`

### References

- [Source: architecture.md#Technology-Stack — ARCH-5: RevenueCat + StoreKit 2]
- [Source: architecture.md#Project-Structure — Features/Subscription/ layout]
- [Source: architecture.md#API-Boundaries — iOS App to RevenueCat SDK Native SDK]
- [Source: architecture.md#Error-Handling — AppError enum pattern with warm messages]
- [Source: epics.md#Story-6.1 — Original acceptance criteria and technical notes]
- [Source: CoachMeApp.swift — App entry point for SDK initialization]
- [Source: Configuration.swift — xcconfig-based API key management]
- [Source: AuthService.swift — @MainActor singleton service pattern, sign-in/out integration points]
- [Source: KeychainManager.swift — Secure storage pattern (not needed for RevenueCat)]
- [RevenueCat iOS SDK Docs](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [RevenueCat Quickstart](https://www.revenuecat.com/docs/getting-started/quickstart)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- No blocking issues encountered during implementation

### Completion Notes List

- Task 1: Added `REVENUECAT_API_KEY` to xcconfig template, Debug.xcconfig, Release.xcconfig, Info.plist, and `Configuration.revenueCatAPIKey` property. Validation warns but doesn't block in DEBUG (allows dev without key).
- Task 2: Added `import RevenueCat` and SDK initialization in `CoachMeApp.init()`. Gracefully skips if API key is empty. Debug logging enabled in DEBUG builds.
- Task 3: Created `SubscriptionService` as `@MainActor` singleton matching AuthService pattern. Includes `identifyUser`, `logOutUser`, `isEntitled`, `fetchCustomerInfo`. All methods guard on `Purchases.isConfigured` for safety. Error enum uses warm first-person messages per UX-11.
- Task 4: Integrated RevenueCat into AuthService at three points: after `signInWithApple` (non-blocking Task), after `restoreSession` (non-blocking Task), and in `signOut` (before clearing session). All calls use `try?` to ensure auth flow is never blocked.
- Task 5: Created `SubscriptionViewModel` with `@MainActor @Observable` pattern. Properties: `isPremium`, `isLoading`, `error`. Accepts `SubscriptionService` via init for testability.
- Task 6: Created 7 unit tests covering singleton pattern, ViewModel initial state, all 3 error messages, and graceful behavior when RevenueCat is not configured.

### Change Log

- 2026-02-08: Story 6.1 implementation complete — RevenueCat SDK configuration, SubscriptionService, SubscriptionViewModel, AuthService integration, and unit tests

### File List

**New Files:**
- `CoachMe/CoachMe/Features/Subscription/Services/SubscriptionService.swift`
- `CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift`
- `CoachMe/CoachMeTests/SubscriptionServiceTests.swift`

**Modified Files:**
- `CoachMe/Config.xcconfig.template` — Added REVENUECAT_API_KEY placeholder
- `CoachMe/Debug.xcconfig` — Added REVENUECAT_API_KEY (empty for dev)
- `CoachMe/Release.xcconfig` — Added REVENUECAT_API_KEY placeholder
- `CoachMe/Info.plist` — Added RevenueCatAPIKey entry with xcconfig injection
- `CoachMe/CoachMe/App/Environment/Configuration.swift` — Added revenueCatAPIKey property and validation
- `CoachMe/CoachMe/CoachMeApp.swift` — Added RevenueCat import and SDK initialization
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` — Added RevenueCat identify/logout integration
