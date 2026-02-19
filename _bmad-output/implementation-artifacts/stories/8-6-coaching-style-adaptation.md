# Story 8.6: Coaching Style Adaptation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to learn how I prefer to be coached and adapt its approach**,
so that **coaching feels personalized to my communication style, not one-size-fits-all**.

## Acceptance Criteria

1. **AC-1: Style preference learning** — Given I consistently engage more deeply with direct, action-oriented responses (longer replies, follow-up questions), When the system analyzes engagement patterns over 5+ sessions, Then my `coaching_preferences.preferred_style` is updated to reflect this preference.

2. **AC-2: Style-adapted prompt injection** — Given my coaching style preference has been learned, When the coach constructs a response, Then the system prompt includes style guidance: "This user prefers direct, action-oriented coaching. Lead with concrete next steps rather than open-ended exploration."

3. **AC-3: Domain-specific styles** — Given my style preference differs across domains (direct for career, exploratory for relationships), When the coach routes to a specific domain, Then it applies the domain-specific style preference.

4. **AC-4: Graceful default** — Given I haven't established a clear style preference yet (fewer than 5 sessions), When the coach responds, Then it uses the default balanced coaching style (no style injection in prompt).

## Tasks / Subtasks

### Task 1: Create `style-adapter` Shared Helper Module (AC: #1, #2, #3, #4)
- [x]1.1 Create `CoachMe/Supabase/supabase/functions/_shared/style-adapter.ts`
- [x]1.2 Define and export `StylePreference` interface (consumed by Story 8.7):
  ```typescript
  export interface StylePreference {
    directVsExploratory: number;       // 0.0 = exploratory, 1.0 = direct
    briefVsDetailed: number;           // 0.0 = detailed, 1.0 = brief
    actionVsReflective: number;        // 0.0 = reflective, 1.0 = action
    challengingVsSupportive: number;   // 0.0 = supportive, 1.0 = challenging
  }
  ```
- [x]1.3 Export `getStylePreferences(userId: string, supabase: SupabaseClient, domain?: string): Promise<StylePreference | null>`:
  - Load `coaching_preferences` from `context_profiles` WHERE user_id matches
  - If `manual_override` is set → return manually-defined preferences
  - If `session_count < 5` → return `null` (AC-4, balanced default)
  - If `domain` is provided AND `domain_styles[domain]` exists → return domain-specific
  - Otherwise → return global `style_dimensions`
- [x]1.4 Export `formatStyleInstructions(prefs: StylePreference | null): string`:
  - If `prefs` is null → return `""` (no injection)
  - Convert numeric dimensions to natural language coaching instructions
  - Example output: `"This user prefers direct, action-oriented coaching. Lead with concrete next steps rather than open-ended exploration. Keep responses concise."`
  - Threshold: only describe a dimension if it's >0.65 or <0.35 (strong preference), else omit
- [x]1.5 Export `analyzeStylePreferences(userId: string, supabase: SupabaseClient): Promise<void>`:
  - Query `learning_signals` for user's `session_completed` signals (last 10 sessions max)
  - Extract engagement metrics from `signal_data`: `message_count`, `avg_message_length`, `duration_seconds`, `domain`
  - Compute global `StylePreference` scores (each 0.0–1.0, default 0.5)
  - Compute per-domain `StylePreference` if domain has 3+ sessions
  - Derive `preferred_style` label from dominant dimension(s)
  - Write results to `coaching_preferences` on `context_profiles` (JSONB merge, not overwrite)
  - Update `last_style_analysis_at` timestamp and increment `session_count`
- [x]1.6 Export `shouldRefreshStyleAnalysis(coachingPreferences: Record<string, unknown> | null): boolean`:
  - Return `true` if `last_style_analysis_at` is null (never analyzed)
  - Return `true` if `session_count` increased by 5+ since last analysis
  - Otherwise return `false`
- [x]1.7 Style dimension scoring algorithms:
  - `directVsExploratory`: Ratio of user messages containing action verbs vs question words
  - `briefVsDetailed`: Normalized average user message length (shorter → higher brief score)
  - `actionVsReflective`: Follow-up rate on action-item responses vs reflective prompts
  - `challengingVsSupportive`: Engagement depth when coach challenges vs supports
  - All metrics derived from `learning_signals.signal_data` in `session_completed` records

### Task 2: Integrate Style Instructions into Prompt Builder (AC: #2, #3)
- [x]2.1 Import `formatStyleInstructions` and `StylePreference` into `_shared/prompt-builder.ts`
- [x]2.2 Add `COACHING_STYLE_INSTRUCTION` constant:
  ```
  [COACHING STYLE PREFERENCES]
  Based on this user's engagement patterns, adapt your coaching style:
  {style_instructions}
  Apply this style naturally — never announce that you're adapting your approach.
  ```
- [x]2.3 Add `styleInstructions?: string` parameter to `buildCoachingPrompt()` signature
- [x]2.4 Insert style instruction block AFTER domain-specific config (#6) and BEFORE CLARIFY_INSTRUCTION (#7) in the prompt stack
- [x]2.5 Only inject when `styleInstructions` is a non-empty string
- [x]2.6 Update existing `prompt-builder.test.ts` with tests for style injection position and empty handling

### Task 3: Integrate into Chat Stream Pipeline (AC: #1, #2, #3, #4)
- [x]3.1 Import `getStylePreferences`, `formatStyleInstructions`, `shouldRefreshStyleAnalysis`, `analyzeStylePreferences` from `_shared/style-adapter.ts`
- [x]3.2 Add `getStylePreferences` call to existing `Promise.all()` in `chat-stream/index.ts` — runs in parallel with context, history, patterns:
  ```typescript
  const [userContext, conversationHistory, patternResult, rawHistory, stylePrefs] = await Promise.all([
    loadUserContext(supabase, userId),
    loadRelevantHistory(supabase, userId, conversationId),
    detectCrossDomainPatterns(userId, supabase),
    supabase.from('messages').select('*').eq('conversation_id', conversationId).order('created_at').limit(20),
    getStylePreferences(userId, supabase, domain),
  ]);
  ```
  - **Note:** If Story 8.4 has already added `generatePatternSummary` to this list, add `getStylePreferences` after it
- [x]3.3 Call `formatStyleInstructions(stylePrefs)` to get string, pass to `buildCoachingPrompt()`
- [x]3.4 After streaming completes, trigger background style analysis if needed (fire-and-forget):
  ```typescript
  if (shouldRefreshStyleAnalysis(userContext?.coaching_preferences)) {
    analyzeStylePreferences(userId, supabase).catch(console.error);
  }
  ```
- [x]3.5 Graceful degradation: wrap `getStylePreferences` in try/catch, return `null` on failure

### Task 4: Extend Swift `CoachingPreferences` Model (AC: #1)
- [x]4.1 Open `CoachMe/CoachMe/Features/Context/Models/CoachingPreferences.swift` (created by Story 8.1)
- [x]4.2 Add style-related properties:
  ```swift
  // NEW for 8.6 — add alongside existing 8.1 properties:
  var styleDimensions: StyleDimensions?
  var domainStyles: [String: StyleDimensions]?
  var sessionCount: Int?
  var lastStyleAnalysisAt: Date?
  var manualOverride: String?
  ```
- [x]4.3 Create `StyleDimensions` struct (in same file or new `StyleDimensions.swift`):
  ```swift
  struct StyleDimensions: Codable, Sendable, Equatable {
      var directVsExploratory: Double
      var briefVsDetailed: Double
      var actionVsReflective: Double
      var challengingVsSupportive: Double

      static func balanced() -> StyleDimensions {
          StyleDimensions(directVsExploratory: 0.5, briefVsDetailed: 0.5,
                          actionVsReflective: 0.5, challengingVsSupportive: 0.5)
      }

      enum CodingKeys: String, CodingKey {
          case directVsExploratory = "direct_vs_exploratory"
          case briefVsDetailed = "brief_vs_detailed"
          case actionVsReflective = "action_vs_reflective"
          case challengingVsSupportive = "challenging_vs_supportive"
      }
  }
  ```
- [x]4.4 Add corresponding `CodingKeys` to `CoachingPreferences` for the new fields
- [x]4.5 Verify backward compatibility: existing profiles without style fields should decode to nil optionals

### Task 5: Unit Tests (AC: #1, #2, #3, #4)
- [x]5.1 Create `CoachMe/Supabase/supabase/functions/_shared/style-adapter.test.ts`:
  - Test `getStylePreferences()` returns `null` for <5 sessions (AC-4)
  - Test `getStylePreferences()` resolves domain-specific style with fallback to global
  - Test `getStylePreferences()` manual override takes precedence
  - Test `formatStyleInstructions(null)` returns empty string
  - Test `formatStyleInstructions()` with strong preferences generates descriptive text
  - Test `formatStyleInstructions()` with near-0.5 values generates minimal/empty text
  - Test `analyzeStylePreferences()` computes scores from mock learning signals
  - Test `shouldRefreshStyleAnalysis()` logic (null → true, recent → false, stale → true)
- [x]5.2 Create `CoachMeTests/StyleDimensionsTests.swift`:
  - Test `StyleDimensions` encode/decode with snake_case CodingKeys
  - Test `StyleDimensions.balanced()` returns all 0.5
  - Test `CoachingPreferences` round-trip with new style fields
  - Test backward compatibility: decode CoachingPreferences JSON without style fields (from 8.1)
- [x]5.3 Extend `prompt-builder.test.ts`:
  - Test style instructions injected between domain config and clarify instruction
  - Test empty style instructions produce no injection block
  - Test non-empty style instructions appear in final prompt string

## Dev Notes

### Critical Dependencies

**Story 8.1 (Learning Signals Infrastructure)** — REQUIRED:
- `learning_signals` table must exist (queries `session_completed` signal type)
- `coaching_preferences` JSONB column on `context_profiles` must exist
- `CoachingPreferences.swift` model must exist (Task 4 extends it)
- `LearningSignalService.swift` must exist (records session engagement data we query)

**Story 8.4 (Pattern Recognition Engine)** — SOFT DEPENDENCY:
- 8.4 already extends `buildCoachingPrompt()` and the `Promise.all()` block
- If 8.4 is already merged, add `getStylePreferences` alongside `generatePatternSummary`
- If 8.4 is NOT merged, add both parameters when implementing

**Story 8.7 (Smart Push Notifications)** — DOWNSTREAM CONSUMER:
- 8.7 Task 3 creates a minimal `style-adapter.ts` as fallback if 8.6 isn't done
- 8.7 imports `getStylePreferences()` and `formatStyleInstructions()` from our module
- **Our exported API must match what 8.7 expects** (see Task 1.3 and 1.4 signatures)
- If 8.6 is implemented first, 8.7 skips its Task 3 entirely

**Pre-flight check**: Before starting, verify state:
1. `\d context_profiles` in Supabase — check for `coaching_preferences` column
2. Check if `_shared/pattern-analyzer.ts` exists (8.4 state)
3. Check `buildCoachingPrompt()` current parameter list

### Architecture — Server-Side Heavy, Invisible to User

Style adaptation logic lives almost entirely in Edge Functions and database. The iOS client passively benefits through prompt construction. **No new iOS service needed.** No new UI. The only iOS change is extending the `CoachingPreferences` model to include new fields (which round-trip through existing JSONB automatically).

This follows Epic 8's design principle: **"A real coach has no dashboard."** Style adaptation is invisible infrastructure. The output is the coach's adapted voice in conversation.

### Style Adapter is a SHARED HELPER, Not a Standalone Function

Create as `_shared/style-adapter.ts` following the exact pattern of:
- `_shared/pattern-analyzer.ts` (Story 8.4)
- `_shared/pattern-synthesizer.ts` (Story 3.5)
- `_shared/context-loader.ts` (existing)

Called FROM `chat-stream/index.ts`, not deployed as its own endpoint.

### Prompt Stack Ordering (after Stories 8.4 + 8.6)

```
 1.  BASE_COACHING_PROMPT
 2.  TONE_GUARDRAILS_INSTRUCTION
 3.  CLINICAL_BOUNDARY_INSTRUCTION
 4.  CRISIS_CONTINUITY_INSTRUCTION
 5.  [CRISIS_PROMPT if crisis]
 6.  Domain-specific config
 6.5 COACHING_STYLE_INSTRUCTION ← NEW (this story)
 7.  CLARIFY_INSTRUCTION (if needed)
 8.  USER CONTEXT section
 9.  MEMORY_TAG_INSTRUCTION
10.  PREVIOUS CONVERSATIONS
11.  PATTERN_TAG_INSTRUCTION
12.  CROSS_DOMAIN_PATTERN_INSTRUCTION
13.  PATTERNS_CONTEXT (Story 8.4)
```

**Rationale for position 6.5:** Style instructions modify HOW the coach communicates. They sit alongside domain config as behavioral guidance, applied before content sections.

### Style Instruction Generation Examples

For career domain: `directVsExploratory: 0.8, actionVsReflective: 0.7`:
```
This user prefers direct, action-oriented coaching in career conversations.
Lead with concrete next steps rather than open-ended exploration.
Keep recommendations specific and actionable.
```

For relationships: `directVsExploratory: 0.3, challengingVsSupportive: 0.3`:
```
This user prefers exploratory, supportive coaching in relationship conversations.
Use open-ended questions to help them discover their own insights.
Prioritize empathy and validation before suggesting actions.
```

All dimensions near 0.5 → empty string (no injection, balanced default).

### No Migration Needed

Story 8.1 creates `coaching_preferences` JSONB column with `DEFAULT '{}'::jsonb`. Since JSONB is schema-less, this story writes `style_dimensions`, `domain_styles`, `session_count`, `last_style_analysis_at`, and `manual_override` directly into the existing column. **No additional migration.**

### Existing Code to Modify

| File | Change |
|------|--------|
| `functions/_shared/prompt-builder.ts` | Add `COACHING_STYLE_INSTRUCTION`, add `styleInstructions` param to `buildCoachingPrompt()` |
| `functions/chat-stream/index.ts` | Add `getStylePreferences` to `Promise.all()`, pass style to prompt builder, background analysis |
| `Features/Context/Models/CoachingPreferences.swift` | Add `styleDimensions`, `domainStyles`, `sessionCount`, `lastStyleAnalysisAt`, `manualOverride` |

### New Files to Create

| File | Purpose |
|------|---------|
| `functions/_shared/style-adapter.ts` | Style analysis + instruction generation |
| `functions/_shared/style-adapter.test.ts` | Deno tests |
| `CoachMeTests/StyleDimensionsTests.swift` | Swift model tests |

### Coding Standards

- **CodingKeys** with snake_case for Supabase (`directVsExploratory` → `"direct_vs_exploratory"`)
- **Error messages**: warm first-person per UX-11
- **Factory method**: `StyleDimensions.balanced()` returning all 0.5
- **Edge Function helpers**: export named functions, not default exports
- **Deno imports**: `../` relative paths from `_shared/`
- **No PII logging**: never log user message content

### Performance Budgets

| Component | Target | Notes |
|-----------|--------|-------|
| `getStylePreferences()` | <50ms | Single DB read, piggybacked on context load |
| `formatStyleInstructions()` | <1ms | String generation, no I/O |
| `analyzeStylePreferences()` | <2s | Background, non-blocking |
| Style instruction tokens | ~80–120 | Acceptable prompt overhead |

### Anti-Patterns to Avoid

1. **DO NOT** create a standalone Edge Function endpoint — `style-adapter` is a shared helper
2. **DO NOT** compute styles per-message — analysis runs every ~5 sessions only
3. **DO NOT** create UI — style adaptation is invisible (Epic 8 principle)
4. **DO NOT** add a migration — JSONB from 8.1 handles extended structure
5. **DO NOT** announce adaptation ("I'm being more direct now") — apply naturally
6. **DO NOT** block on `analyzeStylePreferences()` — always fire-and-forget
7. **DO NOT** replace domain config tone — style SUPPLEMENTS it
8. **DO NOT** apply styles for users with <5 sessions — return null for AC-4
9. **DO NOT** create `CachedStylePreferences` SwiftData model — no local caching needed

### Project Structure Notes

- Edge Function shared modules: `CoachMe/Supabase/supabase/functions/_shared/`
- Swift models: `CoachMe/CoachMe/Features/Context/Models/`
- Swift tests: `CoachMe/CoachMeTests/`
- No new feature module — extends existing Context feature
- Aligns with existing monorepo structure

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.6] — Acceptance criteria, style dimensions, technical notes
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 8] — "A real coach has no dashboard" design principle
- [Source: stories/8-1-learning-signals-infrastructure.md] — coaching_preferences JSONB structure, CoachingPreferences model, LearningSignalService, signal types
- [Source: stories/8-4-in-conversation-pattern-recognition-engine.md] — Prompt stack ordering, Promise.all extension, pattern-analyzer shared helper pattern
- [Source: stories/8-7-smart-proactive-push-notifications.md] — Downstream consumer of style-adapter.ts API (getStylePreferences, formatStyleInstructions)
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts] — Prompt construction pipeline
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — Chat stream orchestration, parallel loading
- [Source: CoachMe/Supabase/supabase/functions/_shared/context-loader.ts] — Shared helper pattern
- [Source: CoachMe/Supabase/supabase/functions/_shared/pattern-synthesizer.ts] — Analysis helper with caching
- [Source: CoachMe/Features/Context/Models/ContextProfile.swift] — ContextProfile model, CodingKeys
- [Source: CoachMe/Core/Data/Local/CachedContextProfile.swift] — SwiftData caching (auto handles new JSONB fields)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- File modification conflict on `chat-stream/index.ts` — linter added `offerMonthlyReflection` fields between read and edit; re-read and resolved.

### Completion Notes List

- All 5 tasks implemented: style-adapter.ts, prompt-builder integration, chat-stream pipeline, Swift model extension, tests
- No migration needed — Story 8.1's JSONB column handles extended structure
- Background analysis is fire-and-forget, non-blocking
- Style preferences loaded in parallel via existing Promise.all()
- Domain-specific style resolved after domain routing (second call if domain != 'general')
- All try/catch wrappers ensure graceful degradation (null on failure)
- Tests cover: formatStyleInstructions (thresholds, null, balanced), shouldRefreshStyleAnalysis, computeStyleScores, buildStyleLabel, parseStyleDimensions, constants, Swift encode/decode/backward-compat, prompt injection position

### File List

**New Files:**
- `CoachMe/Supabase/supabase/functions/_shared/style-adapter.ts` — Style analysis and instruction generation shared helper
- `CoachMe/Supabase/supabase/functions/_shared/style-adapter.test.ts` — Deno tests for style-adapter
- `CoachMe/CoachMeTests/StyleDimensionsTests.swift` — Swift tests for StyleDimensions and CoachingPreferences style fields

**Modified Files:**
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` — Added COACHING_STYLE_INSTRUCTION, styleInstructions param
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` — Added 8 style injection tests
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` — Style preferences loading, formatting, background analysis
- `CoachMe/CoachMe/Features/Context/Models/CoachingPreferences.swift` — StyleDimensions struct, 5 new optional fields

### Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 | **Date:** 2026-02-09 | **Outcome:** Approved with fixes applied

**Issues Found:** 2 HIGH, 3 MEDIUM, 3 LOW — all fixed automatically.

**Fixes Applied:**
1. **H1 — Missing tests**: Added `resolveStylePreferences()` function (pure logic extracted from `getStylePreferences`) with 10 unit tests covering: null prefs, <5 session boundary (AC-4), domain-specific with fallback, manual override precedence, override with missing dimensions.
2. **H2 — Algorithm deviation**: Added documentation note on `computeStyleScores` explaining proxy algorithms vs. ideal algorithms. Signal data structure doesn't support spec'd algorithms — documented as pragmatic first pass.
3. **M1 — Redundant DB queries**: Eliminated 2 redundant `context_profiles` reads per request. Replaced `getStylePreferences` (DB call) in Promise.all + domain re-fetch with `resolveStylePreferences(coachingPrefs, domain)` operating on already-loaded data.
4. **M2 — manual_override fallthrough**: Fixed bug where `manual_override` set without `style_dimensions` would silently fall through to domain/global. Now returns `null` to honor override intent.
5. **M3 — Misleading test**: Renamed test from "style instructions skipped when crisisDetected" to "style instructions coexist with crisis prompt" and added assertions for both crisis and style presence.
6. **L1-L3**: Fixed briefScore comment accuracy, added `MIN_DOMAIN_SESSIONS` to constants test, documented `session_count` increment delegation.

### Change Log

| File | Change Type | Description |
|------|------------|-------------|
| `_shared/style-adapter.ts` | Created | StylePreference interface, getStylePreferences, formatStyleInstructions, shouldRefreshStyleAnalysis, analyzeStylePreferences, computeStyleScores, buildStyleLabel, parseStyleDimensions |
| `_shared/style-adapter.ts` | Review fix | Added `resolveStylePreferences()` (pure logic, no DB), refactored `getStylePreferences` to delegate. Fixed manual_override fallthrough. Added algorithm proxy documentation. Fixed briefScore comment. |
| `_shared/style-adapter.test.ts` | Created | 28 Deno tests covering all exported functions and constants |
| `_shared/style-adapter.test.ts` | Review fix | Added 10 `resolveStylePreferences` tests (H1), added `MIN_DOMAIN_SESSIONS` to constants test (L2). Total: 39 tests. |
| `_shared/prompt-builder.ts` | Modified | Added COACHING_STYLE_INSTRUCTION constant, styleInstructions parameter (9th) to buildCoachingPrompt(), injection at position 6.5 |
| `_shared/prompt-builder.test.ts` | Modified | Added 8 tests for style injection position, empty handling, integration with all sections |
| `_shared/prompt-builder.test.ts` | Review fix | Fixed misleading crisis+style test name and assertions (M3) |
| `chat-stream/index.ts` | Modified | Import style-adapter functions, add to Promise.all(), domain-specific resolution, pass to buildCoachingPrompt(), background analyzeStylePreferences |
| `chat-stream/index.ts` | Review fix | Replaced `getStylePreferences` (2 DB calls) with `resolveStylePreferences(coachingPrefs, domain)` (0 DB calls). Removed from Promise.all, eliminated domain re-fetch (M1). |
| `CoachingPreferences.swift` | Modified | Added StyleDimensions struct with CodingKeys, added styleDimensions/domainStyles/sessionCount/lastStyleAnalysisAt/manualOverride to CoachingPreferences |
| `StyleDimensionsTests.swift` | Created | 10 Swift tests: balanced factory, encode/decode round-trip, snake_case keys, equatable, backward compatibility |
