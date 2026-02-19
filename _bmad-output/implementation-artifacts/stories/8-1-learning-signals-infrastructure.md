# Story 8.1: Learning Signals Infrastructure

Status: done

## Story

As a **developer**,
I want **a data foundation that captures behavioral signals from user interactions**,
So that **all intelligence layers (pattern recognition, coaching adaptation, proactive nudges) have the signals they need to learn about each user**.

## Acceptance Criteria

1. **AC-1: Insight feedback recording** — Given a user confirms or dismisses an extracted insight, When the action completes, Then the confirmation action (confirmed/dismissed) and timestamp are recorded in `learning_signals`.

2. **AC-2: Session engagement capture** — Given a user completes a coaching session, When the session ends, Then engagement metrics are captured: message count, average message length, session duration, domain.

3. **AC-3: Derivable analytics** — Given a user has multiple sessions over time, When I query their learning signals, Then I can derive: domain preferences, session frequency patterns, engagement depth trends.

4. **AC-4: Query performance** — Given learning signals accumulate, When the system queries them, Then queries return within 200ms for prompt injection use.

## Tasks / Subtasks

- [x] Task 1: Create Supabase migration for `learning_signals` table (AC: #1, #2, #3, #4)
  - [x] 1.1 Create migration file `20260210000001_learning_signals.sql`
  - [x] 1.2 Define table: `id`, `user_id`, `signal_type` (text with CHECK), `signal_data` (JSONB), `created_at`
  - [x] 1.3 Add RLS policies (users read/insert own signals only)
  - [x] 1.4 Add indexes on `(user_id, signal_type)` and `(user_id, created_at DESC)` for query performance
  - [x] 1.5 Add `updated_at` trigger

- [x] Task 2: Create Supabase migration to extend `context_profiles` with `coaching_preferences` (AC: #3)
  - [x] 2.1 Create migration file `20260210000002_coaching_preferences.sql`
  - [x] 2.2 `ALTER TABLE context_profiles ADD COLUMN coaching_preferences JSONB DEFAULT '{}'::jsonb`
  - [x] 2.3 Add column comment documenting expected structure

- [x] Task 3: Create Swift data models (AC: #1, #2, #3)
  - [x] 3.1 Create `LearningSignal.swift` in `Core/Data/Remote/` — Codable struct with CodingKeys for snake_case
  - [x] 3.2 Create `LearningSignalInsert.swift` in `Core/Data/Remote/` — minimal insert struct
  - [x] 3.3 Create `CoachingPreferences.swift` in `Features/Context/Models/` — Codable struct for JSONB column
  - [x] 3.4 Extend `ContextProfile` with `coachingPreferences: CoachingPreferences` property + CodingKey

- [x] Task 4: Create `LearningSignalService.swift` (AC: #1, #2, #3, #4)
  - [x] 4.1 Create `Core/Services/LearningSignalService.swift` — `@MainActor final class`
  - [x] 4.2 Implement `recordInsightFeedback(insightId:action:category:)` — non-blocking write
  - [x] 4.3 Implement `recordSessionEngagement(conversationId:messageCount:avgMessageLength:durationSeconds:domain:)`
  - [x] 4.4 Implement `fetchSignals(userId:signalType:limit:)` — for downstream consumers
  - [x] 4.5 Implement `fetchAggregates(userId:)` — domain preferences, session frequency, engagement depth

- [x] Task 5: Integrate signal recording into existing flows (AC: #1, #2)
  - [x] 5.1 Hook insight confirmation/dismissal in `ContextRepository` to also record a learning signal
  - [x] 5.2 Hook session end detection in `ChatViewModel` to record session engagement metrics
  - [x] 5.3 Ensure all signal writes are non-blocking (fire-and-forget with Task { })

- [x] Task 6: Write unit tests (AC: #1, #2, #3, #4)
  - [x] 6.1 Create `CoachMeTests/LearningSignalServiceTests.swift`
  - [x] 6.2 Test signal recording (insight feedback, session engagement)
  - [x] 6.3 Test aggregate queries return expected structure
  - [x] 6.4 Test non-blocking behavior (signal failure doesn't crash app)

## Dev Notes

### Architecture Pattern

This story creates **foundational infrastructure only**. No UI changes. No prompt modifications. The learning signals are consumed by Stories 8.4 (pattern recognition), 8.5 (reflections), 8.6 (style adaptation), 8.7 (push notifications), and 8.8 (profile display). Build for extensibility.

### Critical: Non-Blocking Signal Writes

Signal capture MUST NEVER slow down the user experience. All writes to `learning_signals` must be fire-and-forget:

```swift
// CORRECT — non-blocking
Task {
    try? await LearningSignalService.shared.recordInsightFeedback(
        insightId: insightId, action: .confirmed, category: "values"
    )
}

// WRONG — blocking the UI
try await LearningSignalService.shared.recordInsightFeedback(...)
```

### Signal Types (Enum Values)

Use text column with CHECK constraint (not Postgres enum — easier to extend):

| signal_type | Trigger | signal_data (JSONB) |
|---|---|---|
| `insight_confirmed` | User confirms extracted insight | `{ "insight_id": "...", "category": "values\|goals\|situation" }` |
| `insight_dismissed` | User dismisses extracted insight | `{ "insight_id": "...", "category": "..." }` |
| `session_completed` | Conversation reaches natural end | `{ "conversation_id": "...", "message_count": N, "avg_message_length": N, "duration_seconds": N, "domain": "career" }` |
| `domain_used` | Domain routed during session | `{ "conversation_id": "...", "domain": "career" }` |

### Session End Detection

There is no explicit "end session" action. Detect session completion when:
1. User navigates away from chat (ChatView disappears) AND conversation has 2+ messages
2. App enters background with active conversation AND conversation has 2+ messages
3. User starts a new conversation (previous one is complete)

Use `ChatViewModel.onDisappear()` or `scenePhase` changes as triggers. Calculate duration from first message timestamp to last message timestamp in the conversation.

### coaching_preferences JSONB Structure

```json
{
  "preferred_style": null,
  "domain_usage": {},
  "session_patterns": {},
  "last_reflection_at": null
}
```

This is a future-facing structure. Story 8.1 only adds the column with `DEFAULT '{}'::jsonb`. Stories 8.4-8.8 populate it.

### Existing Code to Hook Into

**Insight confirmation/dismissal** — `ContextRepository.swift`:
- `confirmInsight(userId:insightId:)` — after confirming, also fire `recordInsightFeedback(.confirmed)`
- `dismissInsight(userId:insightId:)` — after dismissing, also fire `recordInsightFeedback(.dismissed)`
- Both are `@MainActor` async methods — add non-blocking `Task {}` at the end

**Session engagement** — `ChatViewModel.swift`:
- Track session start time when first message is sent
- On disappear/background, compute duration and fire `recordSessionEngagement()`
- `messageCount` available from `messages.count`
- `avgMessageLength` from user messages only: `messages.filter { $0.role == .user }.map { $0.content.count }.average`
- `domain` available from `conversation.domain` (may be nil for first message)

### Project Structure Notes

New files to create:
```
CoachMe/CoachMe/Core/Data/Remote/LearningSignal.swift
CoachMe/CoachMe/Core/Data/Remote/LearningSignalInsert.swift
CoachMe/CoachMe/Core/Services/LearningSignalService.swift
CoachMe/CoachMe/Features/Context/Models/CoachingPreferences.swift
CoachMe/Supabase/supabase/migrations/20260210000001_learning_signals.sql
CoachMe/Supabase/supabase/migrations/20260210000002_coaching_preferences.sql
CoachMe/CoachMeTests/LearningSignalServiceTests.swift
```

Files to modify:
```
CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift  — add signal recording to confirm/dismiss
CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift     — add coachingPreferences property + CodingKey
CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift     — add session engagement tracking
```

### Migration File Pattern

Follow existing migration conventions exactly:

```sql
-- Migration: 20260210000001_learning_signals.sql
-- Description: Create learning_signals table for behavioral signal tracking
-- Author: Coach App Development Team
-- Date: 2026-02-10
-- Story: 8.1 - Learning Signals Infrastructure

CREATE TABLE IF NOT EXISTS public.learning_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL CHECK (signal_type IN (
        'insight_confirmed', 'insight_dismissed', 'session_completed', 'domain_used'
    )),
    signal_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.learning_signals ENABLE ROW LEVEL SECURITY;

-- RLS: users can only read/insert their own signals
CREATE POLICY "Users can view own learning signals"
    ON public.learning_signals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learning signals"
    ON public.learning_signals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Performance indexes for 200ms query target (AC-4)
CREATE INDEX idx_learning_signals_user_type
    ON public.learning_signals(user_id, signal_type);
CREATE INDEX idx_learning_signals_user_created
    ON public.learning_signals(user_id, created_at DESC);

COMMENT ON TABLE public.learning_signals IS 'Behavioral signals from user interactions for coaching intelligence';
```

### Service Pattern (Must Follow)

```swift
@MainActor
final class LearningSignalService {
    static let shared = LearningSignalService()

    private let supabase: SupabaseClient

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    // Testing constructor
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    private func getCurrentUserId() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }
}
```

### Model Pattern (Must Follow)

```swift
struct LearningSignal: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let signalType: String
    let signalData: [String: AnyJSON]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case signalType = "signal_type"
        case signalData = "signal_data"
        case createdAt = "created_at"
    }
}

struct LearningSignalInsert: Codable, Sendable {
    let userId: UUID
    let signalType: String
    let signalData: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case signalType = "signal_type"
        case signalData = "signal_data"
    }
}
```

**Note on JSONB encoding**: Use `AnyJSON` from the Supabase Swift SDK (already a dependency) for flexible JSONB signal_data. Import via `import Supabase`.

### Error Pattern (Must Follow)

```swift
enum LearningSignalError: LocalizedError, Equatable {
    case recordFailed(String)
    case fetchFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .recordFailed(let reason):
            return "I couldn't save that learning signal. \(reason)"
        case .fetchFailed(let reason):
            return "I couldn't load your learning data. \(reason)"
        case .notAuthenticated:
            return "I need you to sign in before I can track your progress."
        }
    }
}
```

### Anti-Patterns to Avoid

1. **DO NOT create a SwiftData `CachedLearningSignal` model** — signals are write-heavy, read-rare infrastructure. No local caching needed for this story. Future stories may add caching if needed.
2. **DO NOT add UI** — this is pure infrastructure. No views, no view models.
3. **DO NOT modify Edge Functions** — signal recording happens client-side via Supabase REST. Server-side consumption is a future story (8.4+).
4. **DO NOT use Postgres ENUM** for signal_type — use TEXT with CHECK constraint for easier extensibility.
5. **DO NOT add update/delete RLS policies** on `learning_signals` — signals are append-only. No updates, no deletes by users.
6. **DO NOT block on signal writes** — always use `Task { try? await ... }` pattern.

### References

- [Source: _bmad-output/planning-artifacts/epics.md, Epic 8, Story 8.1]
- [Source: _bmad-output/planning-artifacts/architecture.md, Data Architecture section]
- [Source: _bmad-output/planning-artifacts/architecture.md, Frontend Architecture (MVVM + Repository)]
- [Source: CoachMe/Core/Data/Repositories/ContextRepository.swift — insight confirm/dismiss pattern]
- [Source: CoachMe/Core/Services/ConversationService.swift — @MainActor service pattern]
- [Source: CoachMe/Features/Context/Models/ContextProfile.swift — Codable model with CodingKeys]
- [Source: CoachMe/Supabase/supabase/migrations/20260206000003_context_profiles.sql — migration pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build failure 1: Supabase query builder — `.eq()` called after `.limit()` on `PostgrestTransformBuilder`. Fixed by reordering filters before transforms.
- Build failure 2: Custom `init(from:)` inside struct body suppressed memberwise init. Fixed by moving decoder to extension.
- Build failure 3: ChatViewModel used `AppEnvironment.shared.supabase` directly without `import Supabase`. Fixed by moving domain lookup into `LearningSignalService`.
- Build failure 4: Existing tests missing `coachingPreferences` param. Fixed by giving property a default value (`.empty`).

### Completion Notes List

- **Task 1**: Created `learning_signals` table with RLS (SELECT/INSERT for own signals), composite indexes for 200ms query target, `updated_at` trigger, TEXT+CHECK for signal_type extensibility.
- **Task 2**: Added `coaching_preferences JSONB DEFAULT '{}'` column to `context_profiles` with documentation comment. Column populated by future Stories 8.4-8.8.
- **Task 3**: Created `LearningSignal`, `LearningSignalInsert` (Codable+Sendable with snake_case CodingKeys), `CoachingPreferences` struct. Extended `ContextProfile` with backward-compatible decoding (existing cached profiles without `coaching_preferences` get `.empty` default).
- **Task 4**: Created `LearningSignalService` singleton following project conventions — `@MainActor`, private init, testing init, warm error messages per UX-11. Includes `recordInsightFeedback`, `recordSessionEngagement` (with best-effort domain lookup), `fetchSignals`, `fetchAggregates` with client-side aggregate computation.
- **Task 5**: Hooked `ContextRepository.confirmInsight/dismissInsight` to fire non-blocking `Task { try? await ... }` signal recording. Added `onSessionEnd()` to `ChatViewModel` — records session engagement when conversation has 2+ messages, triggered on `startNewConversation()` and available for `onDisappear` calls from ChatView.
- **Task 6**: 16 unit tests covering model decoding/encoding, aggregate computation (empty, sessions, insights, mixed), error descriptions, equatable conformance, backward compatibility for ContextProfile, and non-blocking pattern verification.

### Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 — Adversarial Code Review
**Date:** 2026-02-09
**Issues Found:** 3 High, 3 Medium, 3 Low
**Issues Fixed:** 6 (3 High + 3 Medium)

**Fixes Applied:**
- **H1** (AC-2 partial): Wired `onSessionEnd()` to `ChatView.onDisappear` — session engagement now captured when user navigates away
- **H2** (data integrity): Added `sessionStartTime != nil` guard to `onSessionEnd()` — prevents stale metrics from loaded conversations
- **H3** (test effectiveness): Extracted `computeAggregates` to `LearningSignalAggregates.compute(from:)` static method — tests now verify real service logic
- **M1** (AC-4 performance): Added `.order("created_at", ascending: false).limit(500)` to `fetchAggregates` — prevents unbounded queries
- **M2** (documentation): Added `project.pbxproj` to File List
- **M3** (schema/model alignment): Added `updatedAt` property to `LearningSignal` model to match DB schema

**Remaining (Low — accepted):**
- L1: Test decoder strategy uses `.convertFromSnakeCase` which may differ from runtime Supabase decoder (mitigated by explicit CodingKeys)
- L2: `domain_used` signal type in CHECK constraint but never written (forward-looking for downstream stories)
- L3: `LearningSignalService` references `ConversationService.Conversation` for domain lookup (acceptable coupling for v1)

### Change Log

- 2026-02-09: Story 8.1 implementation complete — learning signals infrastructure with DB migrations, Swift models, service layer, integration hooks, and unit tests.
- 2026-02-09: Code review fixes — wired onSessionEnd to ChatView.onDisappear, guarded on sessionStartTime, extracted testable aggregate computation, added fetchAggregates limit(500), added updatedAt to LearningSignal model, updated File List.

### File List

**New files:**
- `CoachMe/Supabase/supabase/migrations/20260210000001_learning_signals.sql`
- `CoachMe/Supabase/supabase/migrations/20260210000002_coaching_preferences.sql`
- `CoachMe/CoachMe/Core/Data/Remote/LearningSignal.swift`
- `CoachMe/CoachMe/Core/Data/Remote/LearningSignalInsert.swift`
- `CoachMe/CoachMe/Core/Services/LearningSignalService.swift`
- `CoachMe/CoachMe/Features/Context/Models/CoachingPreferences.swift`
- `CoachMe/CoachMeTests/LearningSignalServiceTests.swift`

**Modified files:**
- `CoachMe/CoachMe.xcodeproj/project.pbxproj` — added new Swift files to Xcode project
- `CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift` — added `coachingPreferences` property, CodingKey, default value, and backward-compatible decoder extension
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` — added non-blocking learning signal recording to `confirmInsight` and `dismissInsight`
- `CoachMe/CoachMe/Features/Chat/ViewModels/ChatViewModel.swift` — added `sessionStartTime` tracking, `onSessionEnd()` method, session engagement recording on conversation end
- `CoachMe/CoachMe/Features/Chat/Views/ChatView.swift` — wired `onDisappear` to call `viewModel.onSessionEnd()` for session end detection
