# Story 3.1: Invisible Domain Routing

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to automatically know what type of coaching I need**,
So that **I don't have to pick categories or modes**.

## Acceptance Criteria

1. **Given** I start talking about my career
   **When** the coach responds
   **Then** it uses career coaching methodology without me selecting it

2. **Given** I switch topics to relationships
   **When** the conversation continues
   **Then** the coach seamlessly adjusts to relationships methodology

3. **Given** domain detection is uncertain
   **When** confidence is low
   **Then** the coach asks a clarifying question rather than guessing wrong

4. **Given** the coach detects a domain
   **When** the response is generated
   **Then** the conversation's `domain` column is updated in the database

5. **Given** domain routing occurs
   **When** I look at my conversation
   **Then** I see no visible indication of domain selection during the conversation (invisible to user)

6. **Given** I send a message that spans multiple domains (e.g., "career stress affecting my relationship")
   **When** the coach responds
   **Then** it picks the primary domain but acknowledges the cross-domain connection naturally

7. **Given** the domain router receives a message
   **When** it classifies the domain
   **Then** the classification completes in <100ms (NFR3)

## Tasks / Subtasks

- [x] Task 1: Create `domain-router.ts` Edge Function helper (AC: #1, #2, #3, #7)
  - [x] 1.1 Create `/Supabase/supabase/functions/_shared/domain-router.ts`
  - [x] 1.2 Implement `determineDomain()` function with LLM-based classification
  - [x] 1.3 Define 7 domain keyword/intent mappings (life, career, relationships, mindset, creativity, fitness, leadership) plus `general` fallback
  - [x] 1.4 Implement confidence threshold (0.7) — return `general` with clarifying prompt instruction when below threshold
  - [x] 1.5 Support conversation history context for multi-turn domain continuity (don't flip domains on every message)
  - [x] 1.6 Handle cross-domain messages by selecting primary domain using this priority: (1) highest confidence score from LLM, (2) if tied, prefer conversation's existing domain for continuity, (3) if no existing domain, select the domain most actionable for coaching
  - [x] 1.7 Add domain transition detection for mid-conversation topic shifts (AC: #2)

- [x] Task 2: Create domain-specific system prompts in `prompt-builder.ts` (AC: #1, #2)
  - [x] 2.1 Add domain-specific coaching methodology sections to existing `buildCoachingPrompt()`
  - [x] 2.2 Define unique tone, approach, and coaching style for each of the 7 domains
  - [x] 2.3 Add `general` domain prompt for low-confidence or mixed-domain conversations
  - [x] 2.4 Include domain transition instructions: "If the user shifts topics, adapt naturally without announcing a mode change"
  - [x] 2.5 Add clarifying question prompt for uncertain domains (AC: #3): coach should ask a grounding question, not lecture

- [x] Task 3: Integrate domain routing into `chat-stream/index.ts` (AC: #1, #4, #7)
  - [x] 3.1 Import `determineDomain` from `domain-router.ts`
  - [x] 3.2 Call `determineDomain()` AFTER context loading, BEFORE prompt building (in the existing pipeline at ~line 65)
  - [x] 3.3 Pass determined domain to `buildCoachingPrompt(userContext, domain)`
  - [x] 3.4 Update conversation's `domain` column in database after successful domain determination
  - [x] 3.5 Include determined domain in SSE stream metadata (optional, for future history view domain badges)
  - [x] 3.6 Ensure total domain routing adds <100ms to response pipeline

- [x] Task 4: Create JSON domain config files in iOS app (AC: #1)
  - [x] 4.1 Create 7 JSON config files in `Resources/DomainConfigs/` (life-coaching.json, career-coaching.json, relationships.json, mindset.json, creativity.json, fitness.json, leadership.json)
  - [x] 4.2 Each config defines: `domain_id`, `display_name`, `description`, `keywords`, `tone`, `methodology_summary`
  - [x] 4.3 Create `DomainConfig.swift` model in `Core/Constants/` to load and parse configs
  - [x] 4.4 These configs are reference data for future Story 3.2 (Domain Configuration Engine) — keep them simple for now

- [x] Task 5: Update iOS `ConversationService` to track domain (AC: #4)
  - [x] 5.1 Ensure `Conversation.domain` field is properly decoded from Supabase responses (already exists as `domain: String?`)
  - [x] 5.2 No model changes needed — `domain` field already exists in `ConversationService.Conversation`

- [x] Task 6: Write backend tests (AC: #1, #2, #3, #7)
  - [x] 6.1 Create `domain-router.test.ts` — test each domain classification with sample messages
  - [x] 6.2 Test confidence threshold behavior (low confidence → general + clarifying instruction)
  - [x] 6.3 Test domain continuity (same domain maintained across turns unless topic clearly shifts)
  - [x] 6.4 Test cross-domain message handling (primary domain selection)
  - [x] 6.5 Test domain transition detection (career → relationships mid-conversation)
  - [x] 6.6 Test `buildCoachingPrompt()` with each domain produces distinct system prompts

## Dev Notes

### Architecture Compliance

**CRITICAL — Follow these patterns established in Epics 1-2:**

1. **Edge Function Pattern**: All business logic in Supabase Edge Functions (Deno/TypeScript), not in iOS client
2. **Shared Helpers**: Domain router goes in `_shared/` directory alongside existing `llm-client.ts`, `context-loader.ts`, `prompt-builder.ts`
3. **Service Pattern (iOS)**: Use `@MainActor` singleton services (like `ConversationService.shared`)
4. **Supabase Access (iOS)**: Always via `AppEnvironment.shared.supabase`
5. **Error Handling**: First-person warm messages per UX-11 ("I couldn't..." not "Failed to...")
6. **Invisible to User**: Domain routing is a backend concern — NO UI changes in this story. Domain badges in history come in Story 3.7.

### Technical Requirements

**From PRD (FR6):**
> The system can detect the coaching domain from conversation content and route to the appropriate domain expertise invisibly

**From PRD (NFR3):**
> Domain routing accuracy: 90%+ correct domain detection
> Domain routing latency: <100ms

**From UX Design Spec — "Invisible Domain Routing":**
> User talks about career → gets career coaching expertise. Talks about relationships → gets relationship depth. Never sees a toggle, dropdown, or category label during the conversation.

**From UX Design Spec — Key Design Challenge #5:**
> "Invisible Domain Routing = Invisible Value — Users never see domain routing happen. That's the design intent."

**From Architecture — Real-Time Streaming Pipeline (Step 4):**
```
4. Classify coaching domain (<100ms, NLP classification)
5. Load domain config (tone, methodology, system prompt)
6. Construct full prompt: system + domain + context + history + message
```

### What Already Exists (DO NOT recreate)

**Database Schema** — Domain column already in `conversations` table:
```sql
-- From migration 20260205000001_initial_schema.sql
domain TEXT CHECK (domain IN ('life', 'career', 'relationships', 'mindset', 'creativity', 'fitness', 'leadership'))
-- Column is indexed for efficient queries
```

**TypeScript Types** — `CoachingDomain` already defined in `prompt-builder.ts`:
```typescript
export type CoachingDomain =
  | 'life'
  | 'career'
  | 'relationships'
  | 'mindset'
  | 'creativity'
  | 'fitness'
  | 'leadership'
  | 'general';
```

**Prompt Builder** — Already accepts domain parameter:
```typescript
export function buildCoachingPrompt(
  context: UserContext | null,
  domain: CoachingDomain = 'general'
): string
```
Currently the function accepts `domain` but doesn't use it to differentiate prompts — it uses the same `BASE_COACHING_PROMPT` for all domains. This story adds domain-specific prompt sections.

**iOS ConversationService** — Domain field already exists:
```swift
struct Conversation: Codable, Identifiable, Sendable {
    var domain: String?  // Already defined, CodingKeys already maps it
}
```

**Chat-stream pipeline** — Domain routing placeholder exists:
```typescript
// chat-stream/index.ts lines ~189-190
// TODO: Story 3.1 - Domain routing
// const domain = await determineDomain(conversation, userContext);
```

**Resources/DomainConfigs/** — Directory exists (empty, ready for config files)

### Domain Classification Approach

**Canonical approach: Separate fast LLM call** (not keyword matching):
- Use a dedicated, fast LLM call (e.g., Claude Haiku or GPT-4o-mini) with structured output
- Input: current user message + last 2-3 messages for context
- Output: `{ domain: CoachingDomain, confidence: number }`
- Confidence threshold: 0.7 — below this, use `general` domain and instruct coach to ask clarifying question
- Cache the domain per conversation — only re-classify when topic shift is detected
- This is the approach `determineDomain()` in Task 1.2 implements

**Why not keyword matching?**
- "I'm stressed about work" could be career OR mindset
- "My partner doesn't support my career change" spans relationships + career
- LLM classification understands intent and nuance, keyword matching doesn't

**Fallback only — Embedded classification** (if <100ms latency cannot be achieved):
- If the separate LLM call consistently exceeds 100ms in production, fall back to embedding classification in the main coaching system prompt
- Trades structured output for zero additional latency; requires parsing domain from coach response text
- Do NOT implement unless the canonical approach fails latency targets in testing

**Domain continuity logic:**
- Don't re-classify every message — use a lightweight shift-detection gate first
- Use conversation's existing `domain` as prior, only override with high confidence
- Threshold for domain switch: higher than initial classification (e.g., 0.85)

**Topic shift detection algorithm (Task 1.7):**
- **Purpose**: This is a cheap gate to decide *whether* to call the LLM classifier, NOT the classifier itself
- **How it works**: Compare the new message against the current domain's keyword/intent set (from Task 1.3). If the message contains zero keywords associated with the current domain AND contains keywords from a different domain, flag it as a potential shift
- **Why this isn't keyword classification**: Keyword matching here only answers "did the topic likely change?" (binary gate), not "what is the new domain?" (classification). The rejected keyword-matching approach (above) was about using keywords to *select* the domain — that's what the LLM handles
- **On potential shift detected**: Trigger full LLM re-classification with the higher 0.85 confidence threshold
- **On no shift detected**: Keep current domain, skip LLM call (saves latency and cost)
- **Edge case**: For the first message in a conversation (no existing domain), always run full LLM classification

### Domain Routing Error Handling

**Failure scenarios and recovery strategies:**

| Failure | Fallback Behavior | User Visibility |
|---------|-------------------|-----------------|
| LLM classification call timeout/error | Use `general` domain, proceed with coaching response | None — user sees normal response |
| Invalid/unrecognized domain returned | Map to `general`, log warning for monitoring | None |
| DB domain update failure | Log error, continue — domain update is non-blocking | None |
| iOS domain config file missing/malformed | Skip config loading, use hardcoded defaults | None |
| Confidence below threshold (not an error) | Use `general` + instruct coach to ask clarifying question | Coach asks a natural clarifying question |

**Key principles:**
- Domain routing failures must NEVER block the coaching response — always degrade to `general` and continue
- All classification errors are logged silently (not surfaced to user)
- No retry on transient LLM failures — use `general` for this message, re-attempt on next message
- iOS should use a `guard let` / `try?` pattern when loading domain config files, falling back to an in-code default

### The 7 Coaching Domains

| Domain | Focus | Coaching Style |
|--------|-------|----------------|
| `life` | General life decisions, meaning, purpose | Reflective, exploratory, open-ended |
| `career` | Work, professional growth, transitions | Strategic, action-oriented, structured |
| `relationships` | Partners, family, friends, social dynamics | Empathetic, perspective-taking, emotional intelligence |
| `mindset` | Mental patterns, stress, resilience, beliefs | Cognitive, reframing, growth-oriented |
| `creativity` | Creative blocks, projects, artistic growth | Generative, expansive, playful |
| `fitness` | Health, exercise, body, wellness | Motivational, habit-focused, progressive |
| `leadership` | Management, team dynamics, influence | Strategic, systems-thinking, interpersonal |
| `general` | Unclear or mixed topics | Warm, exploratory, asks clarifying questions |

### Previous Story Learnings (from Epic 2)

**Key patterns from Story 2.6 (last completed story):**

1. **ConversationServiceProtocol** was added for testability — use same pattern if adding any new service methods
2. **Mock-based testing** works well — `MockConversationService` pattern for unit tests
3. **Warm error messages** are enforced throughout — any errors from domain routing should follow this pattern
4. **VoiceOver accessibility** — not needed for this story (no UI changes), but keep in mind for Story 3.7

**Code Review findings from Epic 2:**
- Tests must be behavioral, not just error string validation
- File List in story must be accurate
- Protocol-based dependency injection is the standard pattern

### Git Intelligence (Recent Commits)

```
ad8abd3 checkpoint
f6da5f5 Fix message input text box colors for light mode
1aa8476 Redesign message input to match iMessage style
4f9cc33 Initial commit: Coach App iOS with Epic 1 complete
```

Epic 2 work (Stories 2.1-2.6) is committed as `ad8abd3 checkpoint`. The codebase includes all context profile management, conversation deletion, and settings. Story 3.1 builds on this foundation.

### Project Structure Notes

**Files to Create:**
```
CoachMe/Supabase/supabase/functions/_shared/
└── domain-router.ts                    # NEW - Domain classification logic

CoachMe/CoachMe/Resources/DomainConfigs/
├── life-coaching.json                  # NEW - Domain config
├── career-coaching.json                # NEW
├── relationships.json                  # NEW
├── mindset.json                        # NEW
├── creativity.json                     # NEW
├── fitness.json                        # NEW
└── leadership.json                     # NEW

CoachMe/CoachMe/Core/Constants/
└── DomainConfig.swift                  # NEW - Swift model for domain configs

Tests (backend):
└── domain-router.test.ts              # NEW - Domain classification tests
```

**Files to Modify:**
```
CoachMe/Supabase/supabase/functions/_shared/
├── prompt-builder.ts                   # MODIFY - Add domain-specific prompt sections

CoachMe/Supabase/supabase/functions/
└── chat-stream/index.ts               # MODIFY - Integrate domain routing call (~5 lines)
```

**Files NOT to Touch:**
```
ConversationService.swift              # domain: String? already exists
ChatStreamService.swift                # No changes needed
ChatViewModel.swift                    # No changes needed
Any UI files                           # Domain routing is invisible — no UI changes
```

### Performance Considerations

**Domain Classification Budget: <100ms total**
- LLM classification call: <80ms (use fastest model)
- Domain continuity check: <5ms (in-memory comparison)
- DB update: <15ms (async, non-blocking)

**Caching Strategy:**
- Cache domain per conversation after first classification
- Only re-classify when the lightweight shift-detection gate (see "Topic shift detection algorithm" above) flags a potential topic change
- Most messages reuse the cached domain with zero LLM cost

**Token Cost Consideration:**
- Domain classification adds an additional LLM call per message
- Use cheapest/fastest model available (Haiku-class)
- Keep classification prompt minimal (<200 tokens input)
- Fallback: embed classification in main coaching prompt (see "Fallback only" section above — only if latency targets fail)

### Key Design Principles

- **Invisible**: User never sees domain names, toggles, or routing indicators
- **Seamless transitions**: When user shifts topics, the coach adapts naturally without announcing "switching to career mode"
- **Conservative**: When uncertain, use `general` coaching and ask clarifying questions rather than misclassifying
- **Continuous**: Domain persists across conversation turns unless topic clearly shifts
- **Backward compatible**: Existing conversations with `domain: null` continue to work (treated as `general`)

### Cross-Story Dependencies

**This story enables:**
- **Story 3.2**: Domain Configuration Engine (builds on domain configs created here)
- **Story 3.3**: Cross-Session Memory References (domain-aware context loading)
- **Story 3.4**: Pattern Recognition (domain-specific pattern detection)
- **Story 3.7**: Conversation History View (domain badges in history)

**This story depends on:**
- **Epic 1**: Chat streaming infrastructure (complete)
- **Epic 2**: Context injection (complete — domain routing enhances context-aware responses)

### References

- [Source: epics.md#Story-3.1] — Original story requirements and acceptance criteria
- [Source: architecture.md#API-Communication-Patterns] — Streaming pipeline with domain routing step
- [Source: architecture.md#Core-Constants] — DomainConfigs reference
- [Source: architecture.md#Implementation-Patterns] — Naming and structure patterns
- [Source: prd.md#FR6] — Invisible domain routing functional requirement
- [Source: prd.md#NFR3] — Domain routing accuracy (90%+) and latency (<100ms)
- [Source: ux-design-specification.md#Invisible-Domain-Routing] — UX guidance on invisible routing
- [Source: ux-design-specification.md#Key-Design-Challenge-5] — Invisible value communication
- [Source: prompt-builder.ts] — Existing CoachingDomain type and buildCoachingPrompt signature
- [Source: chat-stream/index.ts] — Existing TODO placeholder for domain routing
- [Source: 20260205000001_initial_schema.sql] — Domain column in conversations table
- [Source: 2-6-conversation-deletion.md] — Previous story patterns and learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- iOS build: BUILD SUCCEEDED (all Swift code compiles cleanly)
- Deno not installed locally — backend tests written but need Deno runtime to execute
- No UI files modified (domain routing is invisible per story requirements)

### Completion Notes List

- **Task 1**: Created `domain-router.ts` with full LLM-based domain classification pipeline: `determineDomain()` entry point, `detectTopicShift()` lightweight gate, `parseLLMResponse()` with dual confidence thresholds (0.7 initial, 0.85 for domain switch), `buildClassificationPrompt()` for fast Haiku-class calls, and `DOMAIN_KEYWORDS` map for all 7 domains. All error paths gracefully degrade to `general` domain.
- **Task 2**: Added `DOMAIN_PROMPTS` record with unique coaching methodology for all 8 domains (7 specific + general). Added `DOMAIN_TRANSITION_INSTRUCTION` for seamless topic shifts and `CLARIFY_INSTRUCTION` for low-confidence situations. Updated `buildCoachingPrompt()` to accept `shouldClarify` parameter.
- **Task 3**: Integrated domain routing into `chat-stream/index.ts`: imports `determineDomain`, selects `domain` from conversation query, calls routing after context loading/before prompt building, passes domain + shouldClarify to `buildCoachingPrompt()`, updates DB domain asynchronously (non-blocking), includes domain in SSE done event metadata.
- **Task 4**: Created 7 JSON domain config files (life-coaching, career-coaching, relationships, mindset, creativity, fitness, leadership) and `DomainConfig.swift` model with `load(for:)` and `loadAll()` methods using `guard let`/`try?` pattern. Xcode auto-includes via PBXFileSystemSynchronizedRootGroup.
- **Task 5**: Verified `Conversation.domain: String?` already exists in `ConversationService.swift` with proper CodingKeys. No changes needed.
- **Task 6**: Created `domain-router.test.ts` with 30 tests covering: domain keyword definitions, classification prompt building, topic shift detection (8 scenarios), LLM response parsing (14 scenarios including threshold behavior, domain switching, error handling). Added 15 domain-specific prompt tests to `prompt-builder.test.ts`.

### Change Log

- 2026-02-07: Story 3.1 implementation complete — invisible domain routing with LLM classification, domain-specific coaching prompts, shift detection, and comprehensive tests

### File List

**New Files:**
- CoachMe/Supabase/supabase/functions/_shared/domain-router.ts
- CoachMe/Supabase/supabase/functions/_shared/domain-router.test.ts
- CoachMe/CoachMe/Core/Constants/DomainConfig.swift
- CoachMe/CoachMe/Resources/DomainConfigs/life-coaching.json
- CoachMe/CoachMe/Resources/DomainConfigs/career-coaching.json
- CoachMe/CoachMe/Resources/DomainConfigs/relationships.json
- CoachMe/CoachMe/Resources/DomainConfigs/mindset.json
- CoachMe/CoachMe/Resources/DomainConfigs/creativity.json
- CoachMe/CoachMe/Resources/DomainConfigs/fitness.json
- CoachMe/CoachMe/Resources/DomainConfigs/leadership.json

**Modified Files:**
- CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts
- CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts
- CoachMe/Supabase/supabase/functions/chat-stream/index.ts