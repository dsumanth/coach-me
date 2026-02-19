# Story 8.3: Push Permission Timing & Notification Preferences

Status: done

## Story

As a **user**,
I want **to be asked for push permission at the right moment and control my notification settings**,
So that **I opt in when I understand the value and stay in control of frequency**.

## Acceptance Criteria

1. **Given** I'm a new user **When** I first launch the app **Then** I am NOT asked for push permission
2. **Given** I complete my first coaching session **When** the session ends **Then** I'm asked: "Want me to check in with you between sessions?" with warm, explanatory copy
3. **Given** I open notification settings **When** I view preferences **Then** I can enable/disable check-ins and choose frequency (daily, few times a week, weekly)
4. **Given** I change my notification preferences **When** I save **Then** the push-trigger function respects my new settings immediately

5. **Given** the push-trigger scheduled function runs **When** it queries eligible users **Then** it reads `context_profiles.notification_preferences` to determine frequency and channel settings, applies the user's preferences when deciding whether to send, and suppresses pushes per the frequency rules (daily, few_times_a_week, weekly). **Note:** The push-trigger implementation is part of Story 8.7. If Story 8.7 is not yet implemented, this AC serves as a contract: notification_preferences stored here MUST be queryable and respected by the push-trigger function. Story 8.7 must include acceptance criteria for correct querying of `notification_preferences`, enforcement of frequency and suppression rules, and documented scheduling behavior (e.g., daily cron via pg_cron or Supabase scheduled function).

## Tasks / Subtasks

- [x] Task 1: Create `NotificationPreference` model (AC: #3, #4)
  - [x] 1.1 Define `NotificationPreference` struct with `Codable`/`Sendable` conformance
  - [x] 1.2 Add `CheckInFrequency` enum: `.daily`, `.fewTimesAWeek`, `.weekly`
  - [x] 1.3 Add `CodingKeys` with snake_case mapping for Supabase compatibility
  - [x] 1.4 Create factory method `.default()` for initial preferences

- [x] Task 2: Extend `ContextProfile` with notification preferences (AC: #4)
  - [x] 2.1 Add `notificationPreferences` optional property to `ContextProfile`
  - [x] 2.2 Add `notification_preferences` to `CodingKeys`
  - [x] 2.3 Update `ContextProfile.empty(userId:)` factory to include `nil` notification preferences
  - [x] 2.4 Create Supabase migration: `ALTER TABLE context_profiles ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT NULL`
  - [x] 2.5 **Update ContextRepository encoding/decoding for NotificationPreference JSONB:**
    - In `ContextRepository.updateProfile()`: ensure `ContextProfile.notificationPreferences` (and nested `NotificationPreference`) are encoded to a JSONB-compatible dictionary before upsert. Validate structure and allowed values (e.g., `frequency` must be one of `daily`, `few_times_a_week`, `weekly`; `checkInsEnabled` must be a boolean). Return a clear error if validation fails.
    - In `ContextRepository.fetchProfile()` / decode logic: safely parse `notification_preferences` JSONB into `ContextProfile.notificationPreferences` using `try?` decoding that maps malformed JSON to `nil` (not a crash). Log decoding failures for debugging.

- [x] Task 3: Create `PushPermissionService` (AC: #1, #2)
  - [x] 3.1 Create `PushPermissionService.swift` as `@MainActor` singleton in `Core/Services/`
  - [x] 3.2 Implement `shouldRequestPermission()` — checks `firstSessionComplete` on ContextProfile
  - [x] 3.3 Implement `requestPermissionIfNeeded()` — calls `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])`
  - [x] 3.4 Implement `registerForRemoteNotificationsIfAuthorized()` — calls `UIApplication.shared.registerForRemoteNotifications()` only when authorized
  - [x] 3.5 Implement `currentAuthorizationStatus()` async getter
  - [x] 3.6 Store permission-requested flag in `UserDefaults` to avoid re-prompting after denial

- [x] Task 4: Create post-session push permission prompt UI (AC: #2)
  - [x] 4.1 Create `PushPermissionPromptView.swift` in `Features/Settings/Views/`
  - [x] 4.2 Warm copy: "I'd love to check in between our sessions — a quick nudge to see how things are going. You can always adjust this later."
  - [x] 4.3 Two buttons: "Sure, check in with me" (primary) and "Not now" (secondary)
  - [x] 4.4 Use `.adaptiveGlass()` styling consistent with existing sheets
  - [x] 4.5 On "Sure" tap — call `PushPermissionService.requestPermissionIfNeeded()`, then save default `NotificationPreference` to profile
  - [x] 4.6 On "Not now" — dismiss, set UserDefaults flag to suppress future prompts this session

- [x] Task 5: Integrate permission prompt into ChatViewModel (AC: #1, #2)
  - [x] 5.1 Add `showPushPermissionPrompt` state to `ChatViewModel`
  - [x] 5.2 **Define deterministic "session ends" trigger in ChatViewModel:**
    - A session is considered complete when the conversation has ≥4 messages exchanged AND one of the following occurs:
      - (a) The app moves to background (observe `UIApplication.willResignActiveNotification` or SwiftUI `scenePhase` change to `.inactive`/`.background`)
      - (b) There is 5 minutes of user inactivity (start/reset a timer on each incoming or outgoing message; fire after 5 minutes of no new messages)
    - When the trigger fires: set `firstSessionComplete = true` via `ContextRepository` (server-side update), and if push permission hasn't been requested yet (check UserDefaults flag), set `showPushPermissionPrompt = true`
  - [x] 5.3 Present `PushPermissionPromptView` as sheet from `ChatView` when `showPushPermissionPrompt` is true

- [x] Task 6: Create `NotificationPreferencesView` in Settings (AC: #3, #4)
  - [x] 6.1 Create `NotificationPreferencesView.swift` in `Features/Settings/Views/`
  - [x] 6.2 Toggle: "Check-in notifications" (on/off)
  - [x] 6.3 Frequency picker (only visible when enabled): Daily, Few times a week, Weekly
  - [x] 6.4 Warm description text explaining what check-ins are
  - [x] 6.5 Link to iOS system notification settings if permissions denied at OS level
  - [x] 6.6 Use `@Observable` ViewModel pattern: `NotificationPreferencesViewModel`
  - [x] 6.7 On save — update `ContextProfile.notificationPreferences` via `ContextRepository`
  - [x] 6.8 Add `.adaptiveGlass()` section styling matching existing SettingsView sections

- [x] Task 7: Add Notifications section to SettingsView (AC: #3)
  - [x] 7.1 Add "Notifications" section to `SettingsView` between Subscription and Data sections
  - [x] 7.2 Row with bell icon, "Notification Preferences" label, chevron
  - [x] 7.3 NavigationLink to `NotificationPreferencesView`
  - [x] 7.4 Show current frequency as subtitle (e.g., "Check-ins: Few times a week")

- [x] Task 8: Write unit tests
  - [x] 8.1 `PushPermissionServiceTests` — test `shouldRequestPermission()` logic
  - [x] 8.2 `NotificationPreferencesViewModelTests` — test save/load preferences
  - [x] 8.3 `NotificationPreferenceTests` — test model encoding/decoding with snake_case
  - [x] 8.4 `PushPermissionPromptTests` — test prompt visibility conditions
  - [x] 8.5 Test that new user does NOT see push prompt on first launch

## Dev Notes

### Critical Architecture Patterns to Follow

- **ViewModel pattern**: Use `@MainActor @Observable final class` (NOT `@ObservableObject`). See [SettingsViewModel.swift](CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift) for the exact pattern.
- **Service pattern**: Use `@MainActor` singleton with `static let shared`. See existing services for pattern.
- **Supabase models**: All structs must use `CodingKeys` with `snake_case` mapping. See [ContextProfile.swift:26-38](CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift#L26-L38).
- **Error messages**: Warm, first-person per UX-11 ("I couldn't..." not "Failed to..."). See [SettingsViewModel.swift:49-57](CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift#L49-L57).
- **UI styling**: Use `.adaptiveGlass()` modifier for card sections, `Color.adaptiveCream(colorScheme)` for backgrounds, `Color.adaptiveTerracotta(colorScheme)` for accent. NEVER use raw `.glassEffect()`.
- **Accessibility**: Every interactive element needs `.accessibilityLabel()` and `.accessibilityHint()`. See SettingsView for comprehensive examples.
- **UserDefaults**: Architecture specifies UserDefaults for non-sensitive preferences like notification settings flags. [Source: architecture.md line 143]

### Existing Code to Build On (DO NOT REINVENT)

- **`firstSessionComplete`** already exists on `ContextProfile` and is tracked in `ContextRepository` (line 341-348). Use this as the trigger for push permission timing — do NOT create a separate session counter.
- **`SubscriptionViewModel`** already has `UNUserNotificationCenter` usage for local trial notifications (lines 284-354). Follow the same pattern for requesting authorization and scheduling.
- **SettingsView sections** follow a consistent pattern: VStack with section header Text, then VStack with `.adaptiveGlass()` containing rows. Copy the pattern from `subscriptionSection` or `dataManagementSection`.
- **ContextRepository** handles saving/loading ContextProfile to/from Supabase. Extend it for notification preferences — do NOT create a separate repository.

### Dependency: Story 8-2 (APNs Push Infrastructure)

Story 8-2 creates the `PushNotificationService.swift` for device token registration and the `push_tokens` Supabase table. This story (8-3) focuses on:
- **Permission timing** (when to ask)
- **Preference UI** (user controls)
- **Preference storage** (notification_preferences JSONB on context_profiles)

If Story 8-2 is not yet implemented, this story can still proceed for local notification preferences and the permission prompt flow. The remote push token registration (`registerForRemoteNotifications`) can be wired up later when `PushNotificationService` exists from 8-2. Implement the permission request flow independently — just skip the device token registration call if `PushNotificationService` doesn't exist yet.

### iOS 18+ Push Notification Best Practices

- **Do NOT request push permission on first launch** — this is both our AC and Apple's best practice. Ask after the user has experienced value (first session complete).
- **Pre-permission screen pattern**: Show a custom warm UI explaining value BEFORE triggering the native iOS permission dialog. This increases opt-in rates.
- **Provisional authorization** (`.provisional` option) is available but NOT recommended here — the story explicitly wants an informed opt-in with warm copy.
- **iOS 18 priority notifications**: Apple has enhanced notification controls. Our implementation should respect user frequency preferences to stay in the user's good graces.
- **Authorization check before scheduling**: Always check `notificationSettings()` before trying to schedule. See the pattern in `SubscriptionViewModel.scheduleTrialExpirationNotification()`.

### File Locations (Architecture-Mandated)

| File | Location |
|------|----------|
| `NotificationPreference.swift` (model) | `Features/Settings/Models/` (create directory) |
| `PushPermissionService.swift` | `Core/Services/` |
| `PushPermissionPromptView.swift` | `Features/Settings/Views/` |
| `NotificationPreferencesView.swift` | `Features/Settings/Views/` |
| `NotificationPreferencesViewModel.swift` | `Features/Settings/ViewModels/` |
| Migration SQL | `Supabase/migrations/` |
| Tests | `CoachMeTests/` |

### Supabase Migration

```sql
-- Migration: Add notification_preferences to context_profiles
-- Story 8-3: Push Permission Timing & Notification Preferences
ALTER TABLE context_profiles
ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT NULL;

COMMENT ON COLUMN context_profiles.notification_preferences IS
'User notification preferences: { "check_ins_enabled": bool, "frequency": "daily"|"few_times_a_week"|"weekly" }';
```

### NotificationPreference Model Shape

```swift
struct NotificationPreference: Codable, Sendable, Equatable {
    var checkInsEnabled: Bool
    var frequency: CheckInFrequency

    enum CheckInFrequency: String, Codable, Sendable, CaseIterable {
        case daily
        case fewTimesAWeek = "few_times_a_week"
        case weekly

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .fewTimesAWeek: return "Few times a week"
            case .weekly: return "Weekly"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case checkInsEnabled = "check_ins_enabled"
        case frequency
    }

    static func `default`() -> NotificationPreference {
        NotificationPreference(checkInsEnabled: true, frequency: .fewTimesAWeek)
    }
}
```

### Testing Standards

- Tests in `CoachMeTests/` directory, NOT a separate test target
- Use `@MainActor` on test classes for concurrency safety
- Mock services via protocol conformance (e.g., `ConversationServiceProtocol` pattern)
- Use `XCTAssertEqual`, `XCTAssertTrue`, `XCTAssertNil` — standard XCTest
- Per project workflow: **write the tests, but DO NOT run them**. Tell the user which specific tests to run after dev/review cycle.

### Project Structure Notes

- Alignment with unified project structure: `Features/Settings/` is the correct location for notification preferences UI, matching the architecture spec which lists `NotificationSettings.swift` under `Features/Settings/Views/`
- The architecture names the file `NotificationSettings.swift` — consider using `NotificationPreferencesView.swift` for consistency with SwiftUI naming conventions (matches `SettingsView.swift`, `SubscriptionManagementView.swift`) but either name is acceptable
- No conflicts detected with existing file structure

### References

- [Source: architecture.md#Data Modeling] — UserDefaults for non-sensitive preferences, context_profiles JSONB
- [Source: architecture.md#Project Structure] — `Features/Settings/Views/NotificationSettings.swift`, `Core/Services/PushNotificationService.swift`
- [Source: epics.md#Story 8.3] — Full acceptance criteria and technical notes
- [Source: epics.md#Story 8.2] — Dependency: APNs infrastructure (push_tokens table, PushNotificationService)
- [Source: ContextProfile.swift] — `firstSessionComplete` field for permission timing trigger
- [Source: SubscriptionViewModel.swift:284-354] — Existing UNUserNotificationCenter pattern for local notifications
- [Source: SettingsView.swift] — Section layout patterns, `.adaptiveGlass()`, accessibility patterns
- [Source: SettingsViewModel.swift] — `@MainActor @Observable` ViewModel pattern

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References
- Build error: `AppEnvironment.shared.supabase.auth.session.user.id` missing imports → Fixed by using `AuthService.shared.currentUserId`
- Test build error: Missing `@MainActor` on `NotificationPreferenceTests` → Added annotation
- Test build error: `sending 'testDefaults' risks causing data races` in PushPermissionServiceTests and PushPermissionPromptTests → Fixed by using computed property pattern for `testDefaults` and inline `UserDefaults(suiteName:)!` in `setUp()`

### Completion Notes List
- All 8 tasks implemented and verified with successful test build
- AC #1: New user NOT prompted — enforced via `shouldRequestPermission(firstSessionComplete: false)` returning `false`
- AC #2: Post-session prompt with warm copy — `PushPermissionPromptView` presented as sheet after ≥4 messages + backgrounding/inactivity
- AC #3: Notification preferences UI — `NotificationPreferencesView` with toggle, frequency picker, system settings link
- AC #4: Preferences saved immediately — `NotificationPreferencesViewModel` writes to `ContextProfile.notificationPreferences` via `ContextRepository`
- AC #5: Contract fulfilled — `notification_preferences` JSONB column added to `context_profiles`, queryable by Story 8.7's push-trigger function
- Swift 6 strict concurrency: all services/ViewModels use `@MainActor`, test UserDefaults use computed property pattern to avoid `sending` errors

### File List

**New Files Created:**
| File | Purpose |
|------|---------|
| `CoachMe/Features/Settings/Models/NotificationPreference.swift` | Notification preference model with `CheckInFrequency` enum |
| `CoachMe/Core/Services/PushPermissionService.swift` | Push permission timing and authorization service |
| `CoachMe/Features/Settings/Views/PushPermissionPromptView.swift` | Post-session warm permission prompt UI |
| `CoachMe/Features/Settings/Views/NotificationPreferencesView.swift` | Settings notification preferences screen |
| `CoachMe/Features/Settings/ViewModels/NotificationPreferencesViewModel.swift` | ViewModel for notification preferences |
| `Supabase/supabase/migrations/20260210000004_notification_preferences.sql` | Migration: add `notification_preferences` JSONB column |
| `CoachMeTests/PushPermissionServiceTests.swift` | Tests for `shouldRequestPermission()` logic |
| `CoachMeTests/NotificationPreferencesViewModelTests.swift` | Tests for save/load preferences |
| `CoachMeTests/NotificationPreferenceTests.swift` | Tests for model encoding/decoding |
| `CoachMeTests/PushPermissionPromptTests.swift` | Tests for prompt visibility conditions |

**Modified Files:**
| File | Changes |
|------|---------|
| `CoachMe/Features/Context/Models/ContextProfile.swift` | Added `notificationPreferences` property, CodingKeys, factory, decoder |
| `CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` | Added push permission trigger logic, inactivity timer, session threshold |
| `CoachMe/Features/Chat/Views/ChatView.swift` | Added `.sheet` for permission prompt, scenePhase observer |
| `CoachMe/Features/Settings/Views/SettingsView.swift` | Added Notifications section with NavigationLink |

### Change Log
| Change | Reason |
|--------|--------|
| Used `AuthService.shared.currentUserId` instead of `AppEnvironment.shared.supabase.auth` | Avoids needing `import Supabase` and `import Auth` in ChatViewModel/ChatView |
| Used computed property pattern for test `UserDefaults` | Swift 6 strict concurrency: `sending` keyword on stored properties causes data race warnings |
| `init(defaults: sending UserDefaults)` on `PushPermissionService` | Enables test injection while satisfying Swift 6 Sendable requirements |

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 | **Date:** 2026-02-09 | **Outcome:** Approved with fixes applied

### Issues Found: 2 High, 5 Medium, 3 Low

### Issues Fixed (7):
| ID | Severity | Issue | Fix |
|----|----------|-------|-----|
| H1 | HIGH | `resetSessionDismissal()` never called on app launch — "Not now" permanently stuck | Added call in `CoachMeApp.init()` |
| H2 | HIGH | Notification preferences only saved when iOS permission granted — breaks user intent | Moved profile save outside `if granted` block |
| M1 | MEDIUM | Silent `try?` failures in onAccept — data loss with no feedback | Replaced with `do/catch` + DEBUG logging |
| M2 | MEDIUM | `onChange` auto-save fires during initial load — unnecessary saves + race condition | Added `hasLoaded` flag, guard in `save()` |
| M3 | MEDIUM | SettingsView notification summary not refreshed after editing | Changed `.task` to `.task(id:)` + `.onAppear` refresh |
| M4 | MEDIUM | Epic vs Story session counter discrepancy | Documented (see action item below) |
| M5 | MEDIUM | No integration tests for trigger mechanism | Documented (see action item below) |

### Remaining Action Items:
- [ ] [AI-Review][MEDIUM] M4: Resolve epic vs story discrepancy — epic says use `coaching_preferences.session_count`, story says use `messages.count >= 4`. Align one with the other.
- [ ] [AI-Review][MEDIUM] M5: Add integration tests for `ChatViewModel.onAppBackgrounded()` and `resetInactivityTimer()` trigger paths
- [ ] [AI-Review][LOW] L1: Consolidate duplicate tests between `PushPermissionPromptTests` and `PushPermissionServiceTests`
- [ ] [AI-Review][LOW] L2: Store `Task` from `checkPushPermissionTrigger()` for cancellation support
- [ ] [AI-Review][LOW] L3: Re-check `isSystemPermissionDenied` in `NotificationPreferencesView.onAppear`

### Additional Files Modified by Review:
| File | Changes |
|------|---------|
| `CoachMe/CoachMeApp.swift` | Added `PushPermissionService.shared.resetSessionDismissal()` call on launch |
| `CoachMe/Features/Chat/Views/ChatView.swift` | Fixed onAccept: save prefs regardless of grant, proper do/catch |
| `CoachMe/Features/Settings/ViewModels/NotificationPreferencesViewModel.swift` | Added `hasLoaded` flag to prevent onChange save during load |
| `CoachMe/Features/Settings/Views/SettingsView.swift` | Added `.onAppear` refresh for notification summary |
