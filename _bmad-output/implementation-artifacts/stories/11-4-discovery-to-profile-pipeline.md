# Story 11.4: Discovery-to-Profile Pipeline

Status: review

## Story

As a **system**,
I want **the context profile to be automatically populated from the discovery conversation**,
So that **paid coaching sessions immediately benefit from everything learned during onboarding**.

## Acceptance Criteria

1. **Given** the discovery conversation completes, **When** the `[DISCOVERY_COMPLETE]` signal includes extracted context data, **Then** the Edge Function writes the context profile fields to the `context_profiles` table — including `coaching_domains`, `current_challenges`, `emotional_baseline`, `communication_style`, `key_themes`, `strengths_identified`, `values`, `vision`, and `aha_insight`.

2. **Given** a user subscribes after discovery, **When** their first paid coaching session begins, **Then** the coaching system prompt includes all context from the discovery conversation — the coach references the aha insight and coaching domains naturally.

3. **Given** the discovery extracted context fields, **When** the user views their profile in Settings, **Then** all discovered context is visible and editable in a "Your Discovery Session" section.

4. **Given** the AI's aha insight was delivered during discovery, **When** the first paid session begins, **Then** the coach references it naturally: e.g., "Last time we talked, something stood out to me — [aha insight]. I've been thinking about that. Let's dig deeper."

5. **Given** the `[DISCOVERY_COMPLETE]` JSON payload is malformed or missing fields, **When** the Edge Function attempts to parse it, **Then** it logs the error, saves whatever fields were successfully extracted, and does NOT block the user from continuing — the conversation transitions to the paywall regardless.

6. **Given** a user completed discovery and their profile was populated, **When** they manually edit a discovered field in Settings, **Then** the edit is persisted normally (discovery data is not read-only) and the `updated_at` timestamp reflects the edit.

7. **Given** the user is offline when discovery completes, **When** they come back online, **Then** the discovery profile data syncs via the existing offline sync pipeline (Story 7.3).

## Tasks / Subtasks

- [x] Task 1: Database migration — add discovery fields to `context_profiles` (AC: #1, #6)
  - [x] 1.1 Create migration `20260211000002_discovery_profile_fields.sql` — ALTER TABLE `context_profiles` to add: `discovery_completed_at TIMESTAMPTZ`, `aha_insight TEXT`, `coaching_domains JSONB DEFAULT '[]'`, `current_challenges JSONB DEFAULT '[]'`, `emotional_baseline TEXT`, `communication_style TEXT`, `key_themes JSONB DEFAULT '[]'`, `strengths_identified JSONB DEFAULT '[]'`, `vision TEXT`, `raw_discovery_data JSONB`
  - [x] 1.2 Add index: `CREATE INDEX IF NOT EXISTS idx_context_profiles_discovery ON context_profiles(discovery_completed_at) WHERE discovery_completed_at IS NOT NULL`
  - [x] 1.3 Add column comments documenting each field's purpose and expected format
  - [x] 1.4 Existing RLS policies already cover new columns (they're on the same table) — verified no policy changes needed

- [x] Task 2: Edge Function — parse `[DISCOVERY_COMPLETE]` and write profile (AC: #1, #5)
  - [x] 2.1 Reused existing `extractDiscoveryProfile()` from Story 11.1 (already follows the tag helper pattern). Added optional `confidence` field to `DiscoveryProfile` interface.
  - [x] 2.2 `DiscoveryProfile` TypeScript interface updated with optional `confidence?: number`
  - [x] 2.3 In `chat-stream/index.ts`, after stream completes AND `hasDiscoveryComplete(fullResponse)` is true: calls `extractDiscoveryProfile()`, then updates `context_profiles` using admin Supabase client
  - [x] 2.4 The update: sets `discovery_completed_at`, writes all extracted fields, stores raw JSON in `raw_discovery_data`, increments `context_version`
  - [x] 2.5 Handles partial extraction: missing fields default to null/empty arrays
  - [x] 2.6 Returns `discovery_profile_saved: true/false` in SSE done event metadata

- [x] Task 3: Swift model updates — ContextProfile.swift (AC: #3, #6)
  - [x] 3.1 Added 9 discovery properties to ContextProfile struct
  - [x] 3.2 Added 9 CodingKeys entries with snake_case mapping
  - [x] 3.3 Used `decodeIfPresent` for ALL new fields in custom `init(from:)` with array defaults to `[]`
  - [x] 3.4 Added `hasDiscoveryData: Bool` computed property
  - [x] 3.5 Updated `.empty(userId:)` factory with nil/empty defaults

- [x] Task 4: ContextRepository — discovery profile write method (AC: #1, #7)
  - [x] 4.1 Added `saveDiscoveryProfile(userId:discoveryData:)` to `ContextRepositoryProtocol` and `ContextRepository`
  - [x] 4.2 Implementation: fetch profile → merge discovery fields → increment contextVersion → update remote → cache locally. If offline, queue via `OfflineSyncService`
  - [x] 4.3 `fetchProfile()` needs no changes — existing decode picks up new fields via `decodeIfPresent`

- [x] Task 5: iOS profile view — show discovery data (AC: #3, #6)
  - [x] 5.1 Added `discoverySection()` in `ContextProfileView.swift` — appears only when `profile.hasDiscoveryData`
  - [x] 5.2 Aha insight displayed as prominent warm-styled callout in adaptive container
  - [x] 5.3 Coaching domains displayed as horizontal FlowLayout chip/tag views
  - [x] 5.4 Key themes, strengths, vision displayed as formatted lists
  - [x] 5.5 Shows `discoveryCompletedAt` formatted as "Discovered on [date]" caption
  - [x] 5.6 Text fields (aha insight, vision, communication style, emotional baseline) editable via pencil buttons → existing `ContextEditorSheet` → `updateProfile()` flow

- [x] Task 6: Prompt builder — inject discovery context into first paid session (AC: #2, #4)
  - [x] 6.1 Added `formatDiscoverySessionContext()` called in both has-context and no-context branches of `buildCoachingPrompt()`
  - [x] 6.2 Section included when `discoveryCompletedAt` AND `ahaInsight` are non-null
  - [x] 6.3 Section content includes key insight, coaching domains, vision, and natural reference instruction
  - [x] 6.4 Includes `communicationStyle` when present

- [x] Task 7: Write tests (AC: #1-#7)
  - [x] 7.1 TypeScript: Discovery profile `confidence` field tests (existing Story 11.1 tests cover core parsing)
  - [x] 7.2 TypeScript: 12 new tests for discovery context section in `buildCoachingPrompt()` — present/absent logic, optional fields, empty context path, confidence field
  - [x] 7.3 Swift: 8 new tests for ContextProfile discovery field decoding — full fields, backward compatibility, partial fields, encoding, round-trip, empty profile, hasDiscoveryData, hasDiscoveryData substantive fields
  - [x] 7.4 Swift: DiscoveryProfileData DTO tests (creation, nil fields)
  - [ ] 7.5 TODO: Swift integration test for `ContextRepository.saveDiscoveryProfile()` — requires Supabase/ModelContext mocks (test gap identified in code review)

## Dev Notes

### Architecture & Patterns

- **Edge Function pipeline**: The `[DISCOVERY_COMPLETE]` signal is detected by `hasDiscoveryComplete()` (created in Story 11.1) AFTER the full SSE stream completes. This story adds the DB write step — it does NOT modify the detection logic itself.

- **Prompt composition order**: Discovery session context goes AFTER regular user context (values, goals, situation) and BEFORE cross-session history. This ensures the coach has both the structured profile AND the discovery narrative. The position in `buildCoachingPrompt()` is:
  1. Base coaching prompt + tone guardrails (always)
  2. Crisis prompt (if applicable)
  3. Domain config
  4. User context section (values, goals, situation)
  5. **Discovery session context** ← NEW (this story)
  6. Memory tag instruction
  7. Cross-session history
  8. Pattern recognition
  9. Reflections

- **Upsert pattern**: Use `supabase.from('context_profiles').update({...}).eq('user_id', userId)` — the profile row already exists (created at signup via Story 2.1's `createProfile()`). Do NOT use insert.

- **Swift model backward compatibility**: All new fields MUST use `decodeIfPresent` because existing users have profiles without discovery data. The `CachedContextProfile` stores the profile as a JSON Data blob, so new fields are automatically handled — no changes needed to the SwiftData model itself.

- **Offline handling**: If the user completes discovery while offline (unlikely but possible), the Edge Function write fails silently (server-side). The iOS client should cache the discovery data locally via `ContextRepository.saveDiscoveryProfile()` and queue for sync. The `OfflineSyncService` (Story 7.3) will push it when connectivity returns.

### Key Design Decisions

1. **Discovery fields live on `context_profiles`, NOT a separate table.** The discovery data IS context — coaching domains, values, vision, etc. map directly to what the coaching prompt needs. A separate table would require joins and complicate the prompt-builder's context loading.

2. **`raw_discovery_data` JSONB for audit trail.** Store the complete AI extraction JSON untouched. This allows debugging, A/B testing different prompt versions, and re-extracting fields if the schema evolves.

3. **No separate "discovery profile" in the iOS app.** The discovery data merges into the existing ContextProfileView as a new section. The user sees one unified profile, not two views. Discovery fields are editable just like manually-entered fields.

4. **The aha insight is ephemeral in the prompt.** After the first few paid sessions, the discovery context section's weight naturally diminishes as the coach accumulates more cross-session history. No explicit "expire" logic needed — the prompt's token budget naturally deprioritizes older context.

### Dependencies (must be implemented BEFORE this story)

| Story | What it provides | What 11.4 consumes |
|-------|-----------------|---------------------|
| **11.1** | `hasDiscoveryComplete()`, `extractDiscoveryProfile()`, `stripDiscoveryTags()` in prompt-builder.ts | Tag detection and JSON extraction helpers |
| **11.2** | Discovery mode routing in chat-stream (Haiku model, discovery prompt) | The conversation that produces `[DISCOVERY_COMPLETE]` signal |
| **Epic 2** | `context_profiles` table, `ContextRepository`, `ContextProfile` model | Existing profile schema and CRUD operations |
| **Story 7.3** | `OfflineSyncService` with queue operations | Offline sync pipeline for discovery data |

### File Paths

| File | Action | Purpose |
|------|--------|---------|
| `supabase/migrations/20260210000008_discovery_profile_fields.sql` | NEW | Add discovery columns to context_profiles |
| `CoachMe/Supabase/supabase/migrations/20260210000008_discovery_profile_fields.sql` | NEW | Copy for CoachMe project migrations |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` | MODIFY | Add `parseDiscoveryProfile()`, add discovery context section to `buildCoachingPrompt()` |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` | MODIFY | Add tests for discovery profile parsing and prompt injection |
| `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` | MODIFY | After stream complete, detect signal → parse → write to DB |
| `CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift` | MODIFY | Add 9 discovery fields + CodingKeys + backward-compatible decode |
| `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` | MODIFY | Add `saveDiscoveryProfile()` method |
| `CoachMe/CoachMe/Features/Context/Views/ContextProfileView.swift` | MODIFY | Add "Your Discovery Session" section |
| `CoachMe/CoachMeTests/` | MODIFY | Add discovery profile decoding + repository tests |

### Existing Code Patterns to Follow

**Tag helper pattern** (prompt-builder.ts):
```typescript
// Follow this existing pattern for parseDiscoveryProfile():
export function hasMemoryMoments(text: string): boolean {
  return text.includes('[MEMORY:');
}
export function extractMemoryMoments(text: string): string[] {
  const matches = text.match(/\[MEMORY:\s*(.*?)\]/g);
  return matches ? matches.map(m => m.replace(/\[MEMORY:\s*|\]/g, '').trim()) : [];
}
```

**CodingKeys pattern** (ContextProfile.swift):
```swift
enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case extractedInsights = "extracted_insights"
    // Add: discoveryCompletedAt = "discovery_completed_at", etc.
}
```

**Supabase update pattern** (ContextRepository.swift):
```swift
try await supabase
    .from("context_profiles")
    .update(updatedFields)
    .eq("user_id", value: userId.uuidString)
    .execute()
```

**SwiftData fetch pattern** (must use fetch-all-and-filter):
```swift
let descriptor = FetchDescriptor<CachedContextProfile>()
let results = try modelContext.fetch(descriptor)
let matching = results.first { $0.userId == userId }
```

### What This Story Does NOT Include

- **Discovery session UI** (welcome screen, onboarding flow) — Story 11.3
- **Model routing** (Haiku for discovery, Sonnet for paid) — Story 11.2
- **Discovery system prompt** — Story 11.1
- **Personalized paywall** with discovery-derived copy — Story 11.5
- **Message counting bypass** for discovery — Epic 10 / Story 11.2
- **New Edge Function endpoint** — discovery runs through existing `chat-stream`

### Migration SQL Reference

```sql
-- 20260210000008_discovery_profile_fields.sql
ALTER TABLE public.context_profiles
  ADD COLUMN IF NOT EXISTS discovery_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS aha_insight TEXT,
  ADD COLUMN IF NOT EXISTS coaching_domains JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS current_challenges JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS emotional_baseline TEXT,
  ADD COLUMN IF NOT EXISTS communication_style TEXT,
  ADD COLUMN IF NOT EXISTS key_themes JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS strengths_identified JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS vision TEXT,
  ADD COLUMN IF NOT EXISTS raw_discovery_data JSONB;

CREATE INDEX IF NOT EXISTS idx_context_profiles_discovery
  ON public.context_profiles(discovery_completed_at)
  WHERE discovery_completed_at IS NOT NULL;

COMMENT ON COLUMN public.context_profiles.discovery_completed_at IS 'Timestamp when discovery session completed and profile was extracted';
COMMENT ON COLUMN public.context_profiles.aha_insight IS 'Key synthesized insight from discovery conversation (Phase 4 peak moment)';
COMMENT ON COLUMN public.context_profiles.coaching_domains IS 'Array of coaching domains identified: ["career","relationships","mindset",...]';
COMMENT ON COLUMN public.context_profiles.current_challenges IS 'Array of specific challenges in user own words';
COMMENT ON COLUMN public.context_profiles.emotional_baseline IS 'General emotional state/pattern observed during discovery';
COMMENT ON COLUMN public.context_profiles.communication_style IS 'Preferred communication style: direct/gentle, analytical/emotional';
COMMENT ON COLUMN public.context_profiles.key_themes IS 'Recurring topics and patterns from the conversation';
COMMENT ON COLUMN public.context_profiles.strengths_identified IS 'Strengths the coach noticed during discovery';
COMMENT ON COLUMN public.context_profiles.vision IS 'User ideal future in their own words';
COMMENT ON COLUMN public.context_profiles.raw_discovery_data IS 'Complete JSON extraction from AI for audit/debugging';
```

### Project Structure Notes

- Migration goes in BOTH `supabase/migrations/` (root) and `CoachMe/Supabase/supabase/migrations/` (project copy) — follow the dual-migration convention established in prior stories
- All Swift changes are in existing files — no new Swift files for this story
- The `parseDiscoveryProfile()` function lives in `prompt-builder.ts` alongside the existing tag helpers — it's NOT a separate module
- The discovery context section in `buildCoachingPrompt()` is conditional and lightweight (~200 tokens when present)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11, Story 11.4] — User story, AC, technical notes, field list
- [Source: _bmad-output/planning-artifacts/architecture.md] — Context profiles schema, Edge Function pipeline, prompt composition order, SwiftData patterns
- [Source: _bmad-output/implementation-artifacts/stories/11-1-discovery-session-system-prompt.md] — Discovery prompt design, tag helpers (hasDiscoveryComplete, extractDiscoveryProfile, stripDiscoveryTags), context extraction fields
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts] — Existing tag helper pattern (hasMemoryMoments, extractMemoryMoments), buildCoachingPrompt() composition order
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — SSE pipeline, post-stream processing, Supabase admin client usage
- [Source: CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift] — CodingKeys pattern, decodeIfPresent usage, Sendable conformance
- [Source: CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift] — @MainActor singleton, remote-first+cache, offline queueing pattern
- [Source: CoachMe/CoachMe/Features/Context/Views/ContextProfileView.swift] — Section layout, adaptive container pattern, edit flow
- [Source: supabase/migrations/20260206000003_context_profiles.sql] — Original table schema, RLS policies, indexes

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- sprint-status.yaml edit required re-read due to concurrent modification
- `discoveryProfileSaved` unused variable — fixed by adding to SSE done event
- UserContext interface expansion required cascading updates to emptyContext and return statement in context-loader.ts

### Completion Notes List

- Reused existing `extractDiscoveryProfile()` from Story 11.1 instead of creating separate `parseDiscoveryProfile()` — same functionality, avoids duplication
- Migration numbered `20260211000002` (not `20260210000008` per story spec) because `20260211000001` already existed
- Discovery fields added to `context-loader.ts` UserContext interface for end-to-end pipeline (interface → SELECT → emptyContext → return mapping)
- FlowLayout for chip views reused from existing `MemoryMomentText.swift`
- Test fixtures updated with new discovery fields (null/empty defaults) to maintain backward compatibility

### Change Log

| File | Change Type | Description |
|------|-------------|-------------|
| `supabase/migrations/20260211000002_discovery_profile_fields.sql` | NEW | ALTER TABLE adds 10 discovery columns, partial index, column comments |
| `CoachMe/Supabase/supabase/migrations/20260211000002_discovery_profile_fields.sql` | NEW | Dual-copy of migration |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` | MODIFY | Added `confidence` to DiscoveryProfile, `formatDiscoverySessionContext()`, injected in buildCoachingPrompt |
| `CoachMe/Supabase/supabase/functions/_shared/context-loader.ts` | MODIFY | Added discovery fields to UserContext, ContextProfileRow, SELECT query, emptyContext |
| `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` | MODIFY | Full discovery profile DB write after stream complete, SSE metadata |
| `CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift` | MODIFY | 9 discovery properties, CodingKeys, decodeIfPresent, hasDiscoveryData, DiscoveryProfileData DTO |
| `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` | MODIFY | saveDiscoveryProfile() method with fetch→merge→update→cache + offline queueing |
| `CoachMe/CoachMe/Features/Context/Views/ContextProfileView.swift` | MODIFY | discoverySection() with aha callout, domain chips, themes, strengths, vision |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` | MODIFY | Updated fixtures with discovery fields, 12 new discovery context tests |
| `CoachMe/CoachMeTests/ContextProfileTests.swift` | MODIFY | 9 new tests for discovery decoding, encoding, round-trip, DTO |

### File List

- `supabase/migrations/20260211000002_discovery_profile_fields.sql` — NEW
- `CoachMe/Supabase/supabase/migrations/20260211000002_discovery_profile_fields.sql` — NEW
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` — MODIFIED
- `CoachMe/Supabase/supabase/functions/_shared/context-loader.ts` — MODIFIED
- `CoachMe/Supabase/supabase/functions/chat-stream/index.ts` — MODIFIED
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` — MODIFIED
- `CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift` — MODIFIED
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` — MODIFIED
- `CoachMe/CoachMe/Features/Context/Views/ContextProfileView.swift` — MODIFIED
- `CoachMe/CoachMeTests/ContextProfileTests.swift` — MODIFIED
