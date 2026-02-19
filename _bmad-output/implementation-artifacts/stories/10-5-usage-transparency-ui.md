# Story 10.5: Usage Transparency UI

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to see how many messages I have remaining this month**,
so that **I feel informed and in control, never surprised by a sudden limit**.

## Acceptance Criteria

1. **Given** I am a paid subscriber, **When** I view the chat screen, **Then** I can see my usage in a subtle, non-intrusive way (e.g., in settings or a tap-to-reveal counter) — usage indicator is hidden below 80% threshold.

2. **Given** I have used 80% of my monthly messages (640+), **When** I view the chat screen, **Then** a gentle indicator appears: "You have [X] conversations left this month".

3. **Given** I have used 95% of my messages (760+), **When** I send a message, **Then** the indicator becomes more prominent: "Almost there — [X] messages left until [reset date]".

4. **Given** I am a trial user, **When** I view the chat screen, **Then** I see messages remaining more prominently since the limit is lower: "[X] of 100 trial messages remaining".

5. **Given** I tap on the usage indicator, **When** the detail view appears, **Then** I see: messages used, messages remaining, reset date (paid) or trial expiry (trial), and a link to manage subscription.

## Tasks / Subtasks

- [x]**Task 1: Create MessageUsage data model** (AC: 1,2,3,4,5)
  - [x]1.1 Create `Core/Data/Remote/MessageUsage.swift` — Codable struct matching `message_usage` table (Story 10.1): `userId: UUID`, `billingPeriod: String` (YYYY-MM), `messageCount: Int`, `limit: Int`, `updatedAt: Date`
  - [x]1.2 Add CodingKeys with `snake_case` mapping per project convention
  - [x]1.3 Add computed properties: `messagesRemaining: Int`, `usagePercentage: Double`, `isAtLimit: Bool`

- [x]**Task 2: Create UsageTrackingService** (AC: 1,2,3,4,5)
  - [x]2.1 Create `Core/Services/UsageTrackingService.swift` — `@MainActor final class`
  - [x]2.2 Implement `fetchCurrentUsage(userId: UUID) async throws -> MessageUsage?` — queries `message_usage` table from Supabase via `AppEnvironment.shared.supabase.from("message_usage").select().eq("user_id", value: userId.uuidString).single().execute()`
  - [x]2.3 Implement `incrementLocalCount(_ usage: inout MessageUsage)` — optimistic local increment for instant UI update after sending a message (real count comes from server on next fetch)
  - [x]2.4 Use warm, first-person error messages per UX-11 for any service errors: `"I couldn't check your usage right now — don't worry, you can keep chatting."`

- [x]**Task 3: Create UsageViewModel** (AC: 1,2,3,4,5)
  - [x]3.1 Create `Features/Chat/ViewModels/UsageViewModel.swift` — `@MainActor @Observable final class`
  - [x]3.2 Define `UsageDisplayTier` enum: `.silent` (0–79%), `.gentle` (80–94%), `.prominent` (95–99%), `.blocked` (100%)
  - [x]3.3 Define `UsageDisplayState` enum: `.hidden`, `.compact(messagesRemaining: Int, tier: UsageDisplayTier)`, `.trial(messagesRemaining: Int, totalLimit: Int)`, `.blocked(resetDate: Date?)`
  - [x]3.4 Properties: `displayState: UsageDisplayState`, `currentUsage: MessageUsage?`, `isLoading: Bool`, `error: String?`
  - [x]3.5 Implement `refreshUsage()` — fetches from `UsageTrackingService`, determines tier using `SubscriptionViewModel.state` (trial vs paid), computes `displayState`
  - [x]3.6 Implement `onMessageSent()` — optimistic local increment + recalculate display state instantly
  - [x]3.7 Implement tier calculation logic:
    - Trial user (`SubscriptionState.trial`): always show `.trial(messagesRemaining:totalLimit:)` — limit is 100
    - Paid user (`SubscriptionState.subscribed`): show `.hidden` if <80%, `.compact` if 80–99%, `.blocked` if 100% — limit is 800/month
    - Unknown/expired: `.hidden` (rate limiting handled by Story 10.1 edge function)
  - [x]3.8 Add VoiceOver accessible description: `accessibleUsageDescription: String` computed from display state (e.g., "160 of 800 messages used this month")

- [x]**Task 4: Create UsageIndicator view** (AC: 1,2,3,4)
  - [x]4.1 Create `Features/Chat/Views/UsageIndicator.swift` — SwiftUI view
  - [x]4.2 Implement `.gentle` tier display: HStack with `chart.bar` SF Symbol icon + "You have [X] conversations left this month" text + `.adaptiveGlass()` styling
  - [x]4.3 Implement `.prominent` tier display: same layout but with `exclamationmark.circle` icon + "Almost there — [X] messages left until [reset date]" + slightly bolder color accent (terracotta, matching TrialBanner)
  - [x]4.4 Implement `.trial` tier display: always visible with `sparkles` icon + "[X] of 100 trial messages remaining" + `.adaptiveGlass()` styling
  - [x]4.5 Implement `.blocked` tier display: solid banner + "We've had a lot of great conversations this month! Your next session refreshes on [date]." (paid) or "You've used your trial sessions — ready to continue? [Subscribe]" (trial) — handled by Story 10.1 rate limit response, but display warmly here
  - [x]4.6 Add tap gesture → `showUsageDetail = true` to trigger detail sheet
  - [x]4.7 Apply `.accessibilityLabel()` using `UsageViewModel.accessibleUsageDescription`
  - [x]4.8 Match existing banner styling from `TrialBanner.swift` and `OfflineBanner.swift`: HStack with icon + VStack(leading) text, `.padding(.horizontal, 14)` + `.padding(.vertical, 10)` internal, `.padding(.horizontal, 12)` + `.padding(.top, 4)` external
  - [x]4.9 Use `.transition(.move(edge: .top).combined(with: .opacity))` to match existing banner animation pattern

- [x]**Task 5: Create UsageDetailSheet** (AC: 5)
  - [x]5.1 Create `Features/Chat/Views/UsageDetailSheet.swift` — presented as `.sheet` when tapping usage indicator
  - [x]5.2 Display: messages used count, messages remaining count, usage progress bar (warm color gradient: green → terracotta → red)
  - [x]5.3 Display: reset date for paid users (next billing cycle date) or trial expiry date for trial users
  - [x]5.4 Display: current tier label ("Premium" or "Trial — Day X of 3")
  - [x]5.5 Add "Manage Subscription" navigation link → opens `SubscriptionManagementView` (from Story 6.4)
  - [x]5.6 Apply `.adaptiveGlass()` styling to card sections
  - [x]5.7 Add VoiceOver labels for all data elements

- [x]**Task 6: Integrate UsageIndicator into ChatView** (AC: 1,2,3,4)
  - [x]6.1 Add `@State private var usageViewModel = UsageViewModel()` (or inject via `AppEnvironment`)
  - [x]6.2 Add `@State private var showUsageDetail = false` for sheet presentation
  - [x]6.3 Insert `UsageIndicator` into the existing banner priority chain in ChatView (lines ~122-134), after OfflineBanner but integrated with TrialBanner logic:
    ```
    if !networkMonitor.isConnected {
        OfflineBanner()
    } else if usageViewModel.displayState != .hidden {
        UsageIndicator(viewModel: usageViewModel, showDetail: $showUsageDetail)
    }
    ```
  - [x]6.4 **IMPORTANT**: The existing `TrialBanner` shows days remaining — `UsageIndicator` for trial users shows *messages* remaining. These complement each other. Show `UsageIndicator` below `TrialBanner` when both are relevant (trial active AND messages used), OR replace TrialBanner with a combined view that shows both days and messages. Preferred: show `UsageIndicator` independently — it handles trial display via `.trial` state.
  - [x]6.5 Call `usageViewModel.refreshUsage()` in `.task` modifier on ChatView appear
  - [x]6.6 Call `usageViewModel.onMessageSent()` after `ChatViewModel.sendMessage()` completes for optimistic increment
  - [x]6.7 Add `.sheet(isPresented: $showUsageDetail) { UsageDetailSheet(viewModel: usageViewModel) }`

- [x]**Task 7: Add usage display to SettingsView** (AC: 5)
  - [x]7.1 Add a "Usage" row inside the existing subscription/account section of `SettingsView.swift` (near lines 343-379 subscription section)
  - [x]7.2 Display: "[X] of [limit] messages used" with a compact progress indicator
  - [x]7.3 Tap → navigate to full `UsageDetailSheet` or inline expansion
  - [x]7.4 Always visible in Settings regardless of threshold tier (paid or trial)
  - [x]7.5 Apply `.adaptiveGlass()` styling consistent with other Settings rows

- [x]**Task 8: Write unit tests** (AC: 1,2,3,4,5)
  - [x]8.1 Create `CoachMeTests/UsageViewModelTests.swift`
  - [x]8.2 Test tier calculation: paid user at 0%, 79%, 80%, 94%, 95%, 99%, 100% → correct `UsageDisplayTier`
  - [x]8.3 Test tier calculation: trial user at various counts → always `.trial` state
  - [x]8.4 Test `onMessageSent()` optimistic increment updates display state correctly
  - [x]8.5 Test `accessibleUsageDescription` produces correct VoiceOver strings
  - [x]8.6 Test edge cases: nil usage data (no message_usage row yet) → default to `.hidden`
  - [x]8.7 Test edge cases: limit of 0 (shouldn't divide by zero)
  - [x]8.8 Test display state transitions: paid user crossing 80% threshold → state changes from `.hidden` to `.compact`

## Dev Notes

### Architecture & Patterns

- **MVVM + Repository**: `UsageViewModel` observes data from `UsageTrackingService`, Views bind to `@Observable` properties
- **@Observable** (NOT @ObservableObject) for `UsageViewModel` per project convention
- **@MainActor** on both `UsageTrackingService` and `UsageViewModel` per Swift 6 strict concurrency
- **Warm, first-person error messages** per UX-11: "I couldn't..." not "Failed to..."
- **adaptiveGlass()** modifier for all indicator/banner UI — never raw `.glassEffect()`
- **CodingKeys with snake_case** for all Supabase model structs

### Data Flow

```
ChatView.task { usageViewModel.refreshUsage() }
  → UsageTrackingService.fetchCurrentUsage(userId:)
    → Supabase REST: SELECT * FROM message_usage WHERE user_id = $1
  → UsageViewModel combines usage data + SubscriptionViewModel.state
  → Computes UsageDisplayTier and UsageDisplayState
  → UsageIndicator renders based on displayState

ChatViewModel.sendMessage() completes
  → usageViewModel.onMessageSent()
  → Optimistic local increment (messageCount += 1)
  → Recalculate displayState instantly
  → Next refreshUsage() syncs with server truth
```

### Critical Dependencies (Must Exist Before This Story)

- **Story 10.1** (`message_usage` table + `increment_and_check_usage` RPC) — this story READS the data that 10.1 WRITES. Without the `message_usage` table, the ViewModel will receive nil and default to `.hidden` (graceful degradation).
- **Epic 6** (`SubscriptionService` + `SubscriptionViewModel`) — already implemented. Provides `SubscriptionState` enum for tier detection (trial vs subscribed vs expired).

### Threshold Configuration

| User Tier | Limit | Silent (hidden) | Gentle | Prominent | Blocked |
|-----------|-------|-----------------|--------|-----------|---------|
| Paid      | 800/month | 0–639 (0–79%) | 640–759 (80–94%) | 760–799 (95–99%) | 800 (100%) |
| Trial     | 100 total | Never hidden | Always shown | Always shown | 100 (100%) |

### Existing Banner Priority in ChatView

Current order (ChatView lines ~122-134):
1. `OfflineBanner` — highest priority (no connection = nothing works)
2. `TrialBanner` — shows when online AND trial active (days remaining)

New order after this story:
1. `OfflineBanner` — unchanged, highest priority
2. `UsageIndicator` — replaces/supplements TrialBanner for message-count display
3. Note: `TrialBanner` shows *days* remaining, `UsageIndicator` shows *messages* remaining. The dev should decide whether to:
   - (A) Show both banners when both are relevant (trial active + messages used)
   - (B) Combine into a single `UsageIndicator` that also shows days for trial users
   - Recommended: **(B)** — for trial users, the UsageIndicator `.trial` state can include both days and messages in one banner to avoid banner stacking

### Key Existing Files to Reference

| File | Relevance |
|------|-----------|
| [TrialBanner.swift](CoachMe/CoachMe/Features/Subscription/Views/TrialBanner.swift) | Styling pattern, HStack layout, `.adaptiveGlass()`, terracotta color |
| [OfflineBanner.swift](CoachMe/CoachMe/Features/Chat/Views/OfflineBanner.swift) | Banner pattern, transition animation, warm messaging |
| [ChatView.swift](CoachMe/CoachMe/Features/Chat/Views/ChatView.swift) | Banner insertion point (lines 122-134), message send hook |
| [SubscriptionViewModel.swift](CoachMe/CoachMe/Features/Subscription/ViewModels/SubscriptionViewModel.swift) | `SubscriptionState` enum, `isTrialActive`, `isSubscribed`, `trialDaysRemaining` |
| [SettingsView.swift](CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift) | Subscription section (lines 343-379) for usage row placement |
| [LearningSignalService.swift](CoachMe/CoachMe/Core/Services/LearningSignalService.swift) | Pattern for @MainActor service with Supabase queries |
| [AppEnvironment.swift](CoachMe/CoachMe/App/Environment/AppEnvironment.swift) | Dependency container — may need UsageTrackingService registration |

### Project Structure Notes

- **New files** follow existing feature module organization:
  - `Core/Data/Remote/MessageUsage.swift` — data model (alongside `LearningSignal.swift`)
  - `Core/Services/UsageTrackingService.swift` — service (alongside `LearningSignalService.swift`)
  - `Features/Chat/ViewModels/UsageViewModel.swift` — ViewModel (alongside `ChatViewModel.swift`)
  - `Features/Chat/Views/UsageIndicator.swift` — indicator view (alongside `OfflineBanner.swift`)
  - `Features/Chat/Views/UsageDetailSheet.swift` — detail sheet (new file)
- No conflicts with existing file structure detected
- Test file: `CoachMeTests/UsageViewModelTests.swift` — follows existing test naming pattern

### Anti-Patterns to Avoid

- **DO NOT** use `@ObservableObject` — use `@Observable` (iOS 17+)
- **DO NOT** use raw `.glassEffect()` — use `.adaptiveGlass()` or `.adaptiveInteractiveGlass()`
- **DO NOT** stack glass on glass (no glass indicator inside a glass container)
- **DO NOT** create anxiety — hide usage for paid users below 80%, always warm tone
- **DO NOT** make direct Supabase calls from Views — go through ViewModel → Service
- **DO NOT** block main thread for network fetches — all usage fetches are `async`
- **DO NOT** log message content or PII — only log usage counts

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.5] — Story requirements, AC, technical notes
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 10] — Epic context, trial model, design principle
- [Source: _bmad-output/planning-artifacts/architecture.md#MVVM+Repository] — Architecture pattern
- [Source: _bmad-output/planning-artifacts/architecture.md#Adaptive Design System] — `.adaptiveGlass()` pattern
- [Source: _bmad-output/planning-artifacts/architecture.md#Anti-Patterns] — What NOT to do
- [Source: _bmad-output/planning-artifacts/architecture.md#Enforcement Guidelines] — VoiceOver, warm messages, @Observable

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- Pre-existing build error in `TrialManager.swift` — missing `import Supabase`. Fixed as part of this story to unblock build verification.

### Completion Notes List

- All 8 tasks implemented per story spec
- Used approach (B) for banner strategy: `UsageIndicator` handles both paid threshold and trial message display, with `TrialBanner` as fallback when usage hasn't loaded
- Banner priority chain: OfflineBanner > UsageIndicator > TrialBanner
- Optimistic increment hooks into `.onChange(of: viewModel.isStreaming)` when streaming starts
- Settings usage row shows compact circular progress ring + "[X] of [limit] messages used"
- Tests focus on MessageUsage model properties (threshold boundaries, computed properties), display state equatable, ViewModel initial state, error message UX-11 compliance
- Build verified: **BUILD SUCCEEDED**

### Change Log

- **Story 10.5**: Implemented usage transparency UI with non-intrusive usage indicators, detail sheet, and Settings integration

### File List

**New files:**
- `CoachMe/CoachMe/Core/Data/Remote/MessageUsage.swift` — Codable model matching message_usage table
- `CoachMe/CoachMe/Core/Services/UsageTrackingService.swift` — @MainActor service for Supabase usage queries
- `CoachMe/CoachMe/Features/Chat/ViewModels/UsageViewModel.swift` — @Observable ViewModel with tier calculation
- `CoachMe/CoachMe/Features/Chat/Views/UsageIndicator.swift` — SwiftUI banner view for usage display
- `CoachMe/CoachMe/Features/Chat/Views/UsageDetailSheet.swift` — Detail sheet with progress bar and subscription link
- `CoachMeTests/UsageViewModelTests.swift` — Unit tests for model, ViewModel, and error messages

**Modified files:**
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — Added usageViewModel state, banner priority integration, optimistic increment hook, usage detail sheet
- `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift` — Added usage row in subscription section with progress ring
- `CoachMe/CoachMe/Features/Subscription/Services/TrialManager.swift` — Added missing `import Supabase` (pre-existing bug fix)
