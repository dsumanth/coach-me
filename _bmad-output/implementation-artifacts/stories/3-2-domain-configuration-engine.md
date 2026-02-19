# Story 3.2: Domain Configuration Engine

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an **operator**,
I want **coaching domains driven by JSON config files that I can modify and extend with minimal code changes**,
So that **I can tune domain behavior (tone, methodology, system prompt, personality) and add new domains through config data additions — no logic changes required**.

## Acceptance Criteria

1. **Given** a domain config file exists in `Resources/DomainConfigs/`, **When** I read `career.json`, **Then** I see complete domain definition: `id`, `name`, `description`, `systemPromptAddition`, `tone`, `methodology`, `personality`, `domainKeywords`, `focusAreas`, `enabled`.

2. **Given** I want to adjust a domain's coaching style, **When** I modify the JSON config and redeploy the Edge Function, **Then** new conversations use the updated tone/methodology/prompt — no TypeScript or Swift code changes required.

3. **Given** I want to add a new coaching domain (e.g., "finance"), **When** I create `finance.json` in both `Resources/DomainConfigs/` (iOS Bundle) and `_shared/domain-configs/` (Edge Functions), **Then** the routing system auto-discovers and uses it on next deploy — no code changes required, only adding JSON files.

4. **Given** the iOS app initializes, **When** `DomainConfigService` loads configs from the Bundle, **Then** all domain configs are available in memory within 100ms.

5. **Given** `prompt-builder.ts` builds a system prompt for a domain, **When** it receives `domain='career'`, **Then** the system prompt is constructed from the config's `systemPromptAddition`, `tone`, `methodology`, and `personality` fields — NOT from hardcoded prompt text.

6. **Given** a domain config file is malformed or missing, **When** the service loads configs, **Then** it logs a warning and falls back to the `general` domain config without crashing.

7. **Given** `domain-router.ts` classifies a message, **When** it needs domain keyword lists, **Then** it reads `domainKeywords` from the config objects — NOT from hardcoded keyword arrays.

8. **Given** an operator adds or modifies a JSON config in `_shared/domain-configs/`, **When** an iOS build runs, **Then** the build-phase sync script copies the updated configs to `Resources/DomainConfigs/` automatically, ensuring both locations are identical without manual intervention.

## Tasks / Subtasks

- [x] Task 1: Enhance domain JSON configs with full schema (AC: #1)
  - [x] 1.1 Extend each of the 7 domain JSON files (created by Story 3-1) with: `systemPromptAddition`, `personality`, `focusAreas`, `enabled` fields
  - [x] 1.2 Create `Resources/DomainConfigs/general.json` as explicit fallback config
  - [x] 1.3 Validate all 8 JSON files parse correctly
- [x] Task 2: Enhance DomainConfig Swift model (AC: #1, #4)
  - [x] 2.1 Extend `DomainConfig.swift` (created by 3-1 in `Core/Constants/`) with full schema fields
  - [x] 2.2 Add `CoachingDomain` enum if not already created, with `rawValue` matching JSON `id` fields
  - [x] 2.3 Add factory method `DomainConfig.general()` for fallback
- [x] Task 3: Create DomainConfigService (AC: #4, #6)
  - [x] 3.1 Create `DomainConfigServiceProtocol` for testability
  - [x] 3.2 Create `Core/Services/DomainConfigService.swift` — loads JSON from Bundle, caches in-memory dictionary
  - [x] 3.3 Implement `config(for domain: CoachingDomain) -> DomainConfig` with `general` fallback
  - [x] 3.4 Handle malformed/missing JSON: log warning, skip, use general fallback
- [x] Task 4: Create `_shared/domain-configs.ts` Edge Function config loader (AC: #2, #5, #7)
  - [x] 4.1 Create `_shared/domain-configs/` directory and copy all JSON config files (same files as iOS Bundle) as the single source of truth for Edge Functions
  - [x] 4.2 Create `domain-configs.ts` with `DomainConfig` TypeScript interface mirroring the JSON schema
  - [x] 4.3 Implement `loadDomainConfigs()` — reads all JSON files from `_shared/domain-configs/` using `Deno.readTextFile()`, parses, validates, and caches in a module-level `Map<string, DomainConfig>`
  - [x] 4.4 Export `getDomainConfig(domain: string): DomainConfig` function with `general` fallback (reads from cached map)
  - [x] 4.5 Export `getDomainKeywords(domain: string): string[]` for domain-router.ts consumption
  - [x] 4.6 Call `loadDomainConfigs()` once at module import (top-level await) so configs are cached for all subsequent requests
- [x] Task 5: Refactor prompt-builder.ts to be config-driven (AC: #2, #5)
  - [x] 5.1 Import `getDomainConfig` from `domain-configs.ts`
  - [x] 5.2 In `buildCoachingPrompt()`, load domain config and append `systemPromptAddition` to base prompt
  - [x] 5.3 Add tone/methodology/personality instructions from config to prompt
  - [x] 5.4 Remove any hardcoded domain-specific prompt text that Story 3-1 may have added inline — move to config objects
  - [x] 5.5 Ensure `general` domain uses base prompt only (no additions)
- [x] Task 6: Update domain-router.ts to use config keywords (AC: #7)
  - [x] 6.1 Import `getDomainKeywords` from `domain-configs.ts`
  - [x] 6.2 Replace any hardcoded keyword arrays with config-driven keyword loading
  - [x] 6.3 Verify dynamically-added domains work end-to-end: operator adds a new JSON config file to `_shared/domain-configs/` (canonical source for Edge Functions) → Xcode build-phase sync script copies it to `Resources/DomainConfigs/` (iOS Bundle) → `loadDomainConfigs()` discovers the new file at next Edge Function cold start → `DomainConfigService` discovers the new file at next iOS app launch → keywords available to router → routing works on both iOS and Edge Functions → no Swift or TypeScript code changes needed, only a new JSON file addition per AC #3
- [x] Task 7: Config synchronization between iOS and Edge Functions (AC: #3)
  - [x] 7.1 Designate `_shared/domain-configs/` as the canonical source directory; `Resources/DomainConfigs/` contains copies for iOS Bundle inclusion
  - [x] 7.2 Create `scripts/sync-domain-configs.sh` — copies all JSON files from `_shared/domain-configs/` to `Resources/DomainConfigs/`, logs diff if files diverge
  - [x] 7.3 Add an Xcode "Run Script" build phase (or pre-build script) that runs `sync-domain-configs.sh` to auto-copy configs into the iOS Bundle at build time
  - [x] 7.4 Create `scripts/validate-domain-configs.sh` — byte-for-byte comparison of both directories, exits non-zero on mismatch (CI/CD ready)
  - [x] 7.5 Document the sync process in Dev Notes: operators add/edit JSON in `_shared/domain-configs/` only, build phase propagates to iOS
- [x] Task 8: Write unit tests (AC: all)
  - [x] 8.1 Test `DomainConfigService` loads all configs from Bundle
  - [x] 8.2 Test fallback to `general` on unknown/missing domain
  - [x] 8.3 Test `DomainConfig` model decoding from JSON
  - [x] 8.4 Test `getDomainConfig()` in Edge Function returns correct config per domain
  - [x] 8.5 Test `buildCoachingPrompt()` with specific domain includes config-driven prompt additions

## Dev Notes

### Architecture Compliance

**This story depends on Story 3-1 (Invisible Domain Routing) which creates:**
- `domain-router.ts` — LLM-based domain classification
- `prompt-builder.ts` updates — domain-specific prompt sections (possibly hardcoded)
- 7 JSON config files in `Resources/DomainConfigs/` with basic schema (`domain_id`, `display_name`, `description`, `keywords`, `tone`, `methodology_summary`)
- `DomainConfig.swift` in `Core/Constants/` — basic Swift model
- `chat-stream/index.ts` integration — passes domain to prompt builder

**This story's job:** Make all of the above **config-driven** instead of hardcoded. The configuration engine means:
1. Prompt text comes from JSON config files, not inline TypeScript strings
2. Domain keywords come from JSON config, not hardcoded arrays
3. New domains require: adding a JSON file to `_shared/domain-configs/` (the canonical source) — no code changes, only JSON file additions. The Xcode build phase auto-copies configs to `Resources/DomainConfigs/` for iOS Bundle inclusion. `loadDomainConfigs()` auto-discovers all files in the directory.
4. Operators modify JSON to change behavior, redeploy Edge Function, and behavior changes automatically
5. **Single source of truth**: `_shared/domain-configs/` is the canonical location. iOS `Resources/DomainConfigs/` is a build-time copy. A sync script ensures they never drift. A validation script can run in CI/CD for byte-for-byte verification.

**MVVM + Repository Pattern:**
- `DomainConfigService` follows `@MainActor` singleton pattern like `ConversationService.shared`
- Must create `DomainConfigServiceProtocol` for mock-based testing (lesson from Story 2.6 code review)

**Swift 6 Strict Concurrency:**
- `DomainConfig` model must conform to `Sendable`
- `DomainConfigService` must be `@MainActor`

**Edge Function Pattern:**
- New shared helper: `_shared/domain-configs.ts`
- Follows existing pattern from `context-loader.ts` and `prompt-builder.ts`

### Domain Config JSON Schema (Full)

Story 3-1 creates initial configs with basic fields. This story extends them to the full schema. **All Bundle JSON config keys use camelCase** (e.g., `systemPromptAddition`, `domainKeywords`). Reserve `snake_case` exclusively for Supabase database model columns. See Coding Standards section below for details.

```json
{
  "id": "career",
  "name": "Career Coaching",
  "description": "Professional growth, career transitions, and workplace challenges",
  "systemPromptAddition": "You are specializing in career coaching. Focus on professional development, career transitions, workplace dynamics, and goal-setting. Use frameworks like SMART goals and strengths-based coaching. Help users identify transferable skills and create action plans.",
  "tone": "professional, encouraging, action-oriented",
  "methodology": "goal-setting, accountability, strengths-based, SMART framework",
  "personality": "experienced career mentor who has coached hundreds of professionals through transitions",
  "domainKeywords": ["career", "job", "work", "promotion", "interview", "resume", "salary", "manager", "workplace", "professional", "transition", "boss", "colleague"],
  "focusAreas": ["career growth", "leadership development", "work-life balance", "skill development", "networking"],
  "enabled": true
}
```

### General (Fallback) Config Schema

`general.json` is the explicit fallback used when a domain is unknown, config is malformed, or classification is indeterminate. It should provide broad coaching guidance without domain-specific focus:

```json
{
  "id": "general",
  "name": "General Coaching",
  "description": "Broad personal coaching covering any topic",
  "systemPromptAddition": "",
  "tone": "warm, supportive, curious",
  "methodology": "active listening, open-ended questions, reflective coaching",
  "personality": "empathetic coach who adapts to whatever the user needs",
  "domainKeywords": [],
  "focusAreas": [],
  "enabled": true
}
```

**Key design decisions for `general.json`:**
- `systemPromptAddition`: **empty string** — the base coaching prompt already covers general coaching behavior. No additional domain-specific text needed.
- `tone`/`methodology`/`personality`: populated with broad coaching defaults — these still get injected into the prompt to maintain consistent tone even in fallback.
- `domainKeywords`: **empty array** — general is never matched by keyword routing; it's only selected as fallback.
- `focusAreas`: **empty array** — no specific focus for the general domain.

**Fields added by this story (beyond what 3-1 creates):**
- `systemPromptAddition` — domain-specific text appended to base coaching prompt
- `personality` — coach persona description injected into prompt
- `focusAreas` — coaching focus areas for this domain
- `enabled` — allows disabling a domain without deleting config

### Anti-Pattern Prevention

- **DO NOT hardcode domain config data as TypeScript objects** — `domain-configs.ts` must read from JSON files at init (using top-level await at module load), not contain inline config objects. Caching the parsed results in a `Map` after reading is correct; hardcoding config values in the source code is not. This preserves a single source of truth (JSON files) shared between iOS and Edge Functions
- **DO NOT hardcode domain prompts in TypeScript** — all domain-specific text must come from parsed JSON configs, loadable/modifiable without logic changes
- **DO NOT create a database table for configs** — use JSON files/objects (DB-backed config is Story 9.3)
- **DO NOT add domain selection UI** — domains are invisible to users (Story 3.1 handles routing)
- **DO NOT modify database migrations** — domain column already exists on conversations table
- **DO NOT break Story 3-1's work** — extend/refactor, don't delete
- **DO NOT duplicate domain keyword lists** — single source of truth in config objects, consumed by both router and prompt builder

### Existing Integration Points (Post Story 3-1)

**prompt-builder.ts:** After Story 3-1, this file will have domain-specific prompts. This story refactors them into config objects so they're modifiable without code:

```typescript
// BEFORE (3-1 may add inline):
if (domain === 'career') {
  prompt += '\nYou are a career coaching specialist...';
}

// AFTER (3-2 config-driven):
const domainConfig = getDomainConfig(domain);
if (domainConfig.systemPromptAddition) {
  prompt += `\n\n${domainConfig.systemPromptAddition}`;
}
if (domainConfig.tone) {
  prompt += `\nCoaching tone: ${domainConfig.tone}`;
}
```

**domain-router.ts:** After Story 3-1, this file will classify domains using keywords. This story makes keywords config-driven:

```typescript
// BEFORE (3-1 may hardcode):
const careerKeywords = ['career', 'job', 'promotion', ...];

// AFTER (3-2 config-driven):
const keywords = getDomainKeywords('career'); // from domain-configs.ts
```

**chat-stream/index.ts:** Already integrated by Story 3-1. No additional changes needed in this story unless passing domain to a new helper.

### Performance Requirements

- **iOS**: Domain config loading **<100ms** total for all 8 configs (NFR3). Loaded once at service init, cached in-memory dictionary. No network calls (bundled JSON).
- **Edge Function cold start**: JSON files read from disk + parsed once at module init. Expected **<50ms** for 8 small JSON files on Deno. Cached in module-level `Map` after first load.
- **Edge Function warm request**: O(1) map access, **<1ms** — reads from cached `Map`, no file I/O on subsequent requests. Note: Edge Functions load and parse JSON files once at cold start (top-level `await loadDomainConfigs()`), then cache the parsed configs in a module-level `Map` for the lifetime of the instance. The O(1) / <1ms claim applies only to warm requests reading from this in-memory cache, not to the initial cold-start load.
- **Single source of truth**: `_shared/domain-configs/` is the canonical directory. An Xcode build-phase script copies configs into `Resources/DomainConfigs/` for iOS Bundle inclusion. A CI validation script (`scripts/validate-domain-configs.sh`) verifies both locations contain identical files. Edge Functions read from `_shared/domain-configs/` at deploy/init.

### Project Structure Notes

**Files to CREATE:**

```
CoachMe/CoachMe/Core/Services/
└── DomainConfigService.swift            # NEW — Loads/caches domain configs from Bundle

CoachMe/CoachMe/Resources/DomainConfigs/
└── general.json                         # NEW — Explicit fallback domain config
    (other 7 files extended from Story 3-1's versions)

CoachMe/Supabase/supabase/functions/_shared/
├── domain-configs.ts                    # NEW — JSON loader + getDomainConfig() (reads from domain-configs/)
└── domain-configs/                      # NEW — Canonical JSON config files (single source of truth)
    ├── general.json
    ├── life.json
    ├── career.json
    ├── relationships.json
    ├── mindset.json
    ├── creativity.json
    ├── fitness.json
    └── leadership.json

CoachMeTests/
└── DomainConfigServiceTests.swift       # NEW — Unit tests

scripts/
├── sync-domain-configs.sh               # NEW — Copies _shared/domain-configs/ → Resources/DomainConfigs/
└── validate-domain-configs.sh           # NEW — Byte-for-byte comparison for CI/CD validation
```

**Files to MODIFY:**

```
CoachMe/CoachMe/Resources/DomainConfigs/
├── life.json                            # MODIFY — Add systemPromptAddition, personality, focusAreas, enabled
├── career.json                          # MODIFY
├── relationships.json                   # MODIFY
├── mindset.json                         # MODIFY
├── creativity.json                      # MODIFY
├── fitness.json                         # MODIFY
└── leadership.json                      # MODIFY

CoachMe/CoachMe/Core/Constants/
└── DomainConfig.swift                   # MODIFY — Extend model with full schema fields

CoachMe/Supabase/supabase/functions/_shared/
├── prompt-builder.ts                    # MODIFY — Use getDomainConfig() instead of inline prompts
└── domain-router.ts                     # MODIFY — Use getDomainKeywords() instead of hardcoded arrays
```

**Files NOT to touch:**
```
chat-stream/index.ts                     # Already integrated by Story 3-1
ConversationService.swift                # domain: String? already exists
ChatViewModel.swift                      # No changes needed
Any UI files                             # Domain config is backend/data-layer only
```

### Coding Standards

- **CodingKeys:** Domain config JSON files use **camelCase** keys throughout (e.g., `systemPromptAddition`, `domainKeywords`) since these are standalone config files read by both Swift and TypeScript — not database columns. Reserve `snake_case` CodingKeys exclusively for Supabase database models (e.g., `Conversation`, `ChatMessage`). For Swift decoding, use `.convertFromSnakeCase` only on DB models; config files decode with default camelCase matching.
- **Error Messages:** Warm, first-person per UX-11 — "I couldn't load that coaching style. Using general coaching instead."
- **Factory Methods:** `DomainConfig.general()` for default fallback
- **Protocol-First:** `DomainConfigServiceProtocol` before implementation

### Testing Requirements

**iOS tests in `CoachMeTests/DomainConfigServiceTests.swift`:**

1. `testLoadAllDomainConfigs` — All 8 configs (7 domains + general) load from Bundle
2. `testFallbackToGeneralOnMissingDomain` — Request unknown domain, get `general` config
3. `testDomainConfigDecoding` — Decode sample JSON, verify all fields including new ones
4. `testCoachingDomainEnum` — All enum cases have matching JSON files
5. `testMalformedConfigHandling` — Malformed JSON skipped, warning logged, other configs still load
6. `testDomainConfigServiceProtocol` — Mock returns expected configs

**Edge Function tests (manual/Deno tests):**
- `loadDomainConfigs()` reads and parses all JSON files from `_shared/domain-configs/`
- `getDomainConfig('career')` returns career config with `systemPromptAddition` (from cached map)
- `getDomainConfig('unknown')` returns general fallback
- `buildCoachingPrompt(context, 'career')` includes career-specific prompt from config
- `getDomainKeywords('career')` returns keyword array from config
- Adding a new JSON file to `_shared/domain-configs/` makes it available after re-init

### Previous Story Intelligence

**From Story 3-1 (Invisible Domain Routing) — direct prerequisite:**
- Creates `domain-router.ts` with LLM-based classification
- Creates initial JSON configs in `Resources/DomainConfigs/` with basic schema
- Creates `DomainConfig.swift` model in `Core/Constants/`
- Adds domain-specific prompts to `prompt-builder.ts` (may be inline/hardcoded)
- Integrates domain into `chat-stream/index.ts` pipeline
- **This story refactors 3-1's inline prompts into config-driven objects**

**From Epic 2 (Stories 2.1-2.6):**
- **Protocol-first testing** — critical finding from Story 2.6 code review
- **@Observable not @ObservableObject** — established ViewModel pattern
- **File list accuracy** — Story 2.6 review caught mislabeled files
- **Warm error messages** — "I couldn't..." not "Failed to..."
- **Fetch-all-and-filter** for SwiftData queries to avoid Sendable issues

### Git Intelligence

```
ad8abd3 checkpoint (Epic 2 complete)
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Story 3-1 work will be committed between this story's creation and implementation. Check latest commits before starting dev.

### Cross-Story Dependencies

**Depends on:**
- **Story 3-1** (Invisible Domain Routing) — creates initial configs, router, prompt integration

**Enables:**
- **Story 3.3** (Cross-Session Memory References) — domain-aware context loading
- **Story 3.4** (Pattern Recognition) — domain-specific pattern detection
- **Story 9.3** (Domain Configuration Management) — operator UI to edit configs (uses DB-backed version)

### References

- [Source: epics.md#Story-3.2] — Story requirements (FR43, FR44)
- [Source: epics.md#FR43] — Modify coaching domain configurations without code changes
- [Source: epics.md#FR44] — Add new coaching domains through configuration files
- [Source: 3-1-invisible-domain-routing.md] — Prerequisite story, creates initial configs and routing
- [Source: architecture.md#Real-Time-Streaming-Pipeline] — Steps 4-6: classify domain, load config, construct prompt
- [Source: prompt-builder.ts] — Current `buildCoachingPrompt()` with unused domain parameter
- [Source: chat-stream/index.ts] — Current pipeline with domain routing TODO
- [Source: ConversationService.swift] — Existing `domain: String?` field on Conversation model
- [Source: 2-6-conversation-deletion.md] — Protocol-first testing, file accuracy lessons
- [Source: ContextRepository.swift] — Service pattern, error handling pattern

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 via Claude Code

### Debug Log References
- Build succeeded after all changes (Xcode 26.2, Swift 6.0, iOS 18.0)
- SourceKit cross-file diagnostics for CoachingDomain/DomainConfig resolve at build time
- Build warning about Run Script phase not specifying outputs (non-blocking, sync script runs every build intentionally)

### Completion Notes List
- Removed CodingKeys from DomainConfig.swift — config JSON uses camelCase (not snake_case DB models)
- Renamed Story 3-1's `life-coaching.json`/`career-coaching.json` to `life.json`/`career.json` to match `id` field values
- Removed hardcoded `DOMAIN_PROMPTS` record from prompt-builder.ts, replaced with `getDomainConfig()` calls
- Removed hardcoded `DOMAIN_KEYWORDS` record from domain-router.ts, replaced with `getDomainKeywords()`/`getAllDomainConfigs()`
- Added `ENABLE_USER_SCRIPT_SANDBOXING = NO` to CoachMe target for sync script to write to source tree
- General domain: empty `systemPromptAddition` (no specialization text appended), but tone/methodology/personality are populated for consistent coaching tone in fallback
- domain-configs.ts uses top-level `await loadDomainConfigs()` for one-time init at module import
- Updated domain-router.test.ts and prompt-builder.test.ts to use config-driven assertions (Story 3.2)

### Change Log
- Created 8 JSON config files in `_shared/domain-configs/` (canonical source) with full schema
- Copied 8 JSON config files to `Resources/DomainConfigs/` (iOS Bundle)
- Rewrote `DomainConfig.swift` with full schema, removed CodingKeys, added `general()` factory
- Created `DomainConfigService.swift` with protocol, @MainActor singleton, Bundle loading, caching
- Created `domain-configs.ts` with TypeScript interface, file loader, module-level Map cache, public API
- Refactored `prompt-builder.ts` to build prompts from config fields instead of hardcoded DOMAIN_PROMPTS
- Refactored `domain-router.ts` to use config-driven keywords instead of hardcoded DOMAIN_KEYWORDS
- Created `scripts/sync-domain-configs.sh` and `scripts/validate-domain-configs.sh`
- Added Xcode Run Script build phase for automatic config sync
- Created `DomainConfigServiceTests.swift` (Swift Testing framework)
- Updated `domain-router.test.ts` with config-driven keyword tests
- Updated `prompt-builder.test.ts` with config-driven prompt assertions

### File List

**Created:**
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/life.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/career.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/relationships.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/mindset.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/creativity.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/fitness.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/leadership.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs/general.json`
- `CoachMe/Supabase/supabase/functions/_shared/domain-configs.ts`
- `CoachMe/CoachMe/Core/Services/DomainConfigService.swift`
- `CoachMe/CoachMeTests/DomainConfigServiceTests.swift`
- `scripts/sync-domain-configs.sh`
- `scripts/validate-domain-configs.sh`

**Modified:**
- `CoachMe/CoachMe/Core/Constants/DomainConfig.swift` — full schema, removed CodingKeys
- `CoachMe/CoachMe/Resources/DomainConfigs/*.json` — synced copies from canonical source
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` — config-driven prompts
- `CoachMe/Supabase/supabase/functions/_shared/domain-router.ts` — config-driven keywords
- `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` — updated assertions
- `CoachMe/Supabase/supabase/functions/_shared/domain-router.test.ts` — updated assertions
- `CoachMe/CoachMe.xcodeproj/project.pbxproj` — Run Script build phase, disabled script sandboxing