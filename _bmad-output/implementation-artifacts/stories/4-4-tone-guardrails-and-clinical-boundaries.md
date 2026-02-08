# Story 4.4: Tone Guardrails & Clinical Boundaries

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **the coach to always be warm and supportive, never dismissive or clinical**,
so that **I never feel judged, dismissed, or given medical advice that could be harmful**.

## Acceptance Criteria

1. **Given** any user message (including provocative, hostile, or testing ones), **When** the coach responds, **Then** the tone is never dismissive, sarcastic, or harsh — always warm and empathetic.

2. **Given** I ask for a diagnosis (e.g., "Do I have anxiety?", "Is this depression?"), **When** the coach responds, **Then** it validates my concern, explains it can't diagnose, and warmly suggests consulting a professional — never assigns clinical labels.

3. **Given** I ask for medication advice (e.g., "Should I take SSRIs?", "What medication helps with anxiety?"), **When** the coach responds, **Then** it declines prescribing, recommends consulting a healthcare provider, and offers to help me prepare for that conversation through coaching.

4. **Given** the coach encounters a topic at the edge of coaching scope (serious mental health concerns, medical issues), **When** it sets a boundary, **Then** it follows the pattern: Empathize → Set boundary → Suggest resource → Keep coaching door open.

5. **Given** tone guardrails and clinical boundary instructions are added to the system prompt, **When** the prompt is constructed via `buildCoachingPrompt()`, **Then** the guardrail instructions are present in every coaching response regardless of domain.

6. **Given** edge case inputs are tested (provocative messages, clinical questions, diagnosis-seeking, medication requests), **When** tests run, **Then** the system prompt includes all required guardrail language and anti-patterns.

## Tasks / Subtasks

- [ ] **Task 1: Expand System Prompt with Tone Guardrails** (AC: #1, #5)
  - [ ] 1.1 Add `TONE_GUARDRAILS_INSTRUCTION` constant to `prompt-builder.ts` with comprehensive anti-tone and positive-tone directives
  - [ ] 1.2 Add `CLINICAL_BOUNDARY_INSTRUCTION` constant to `prompt-builder.ts` with specific boundary rules (no diagnose, no prescribe, no claim expertise)
  - [ ] 1.3 Inject both instructions into `buildCoachingPrompt()` after BASE_COACHING_PROMPT and before domain-specific sections
  - [ ] 1.4 Include explicit boundary reframe pattern: Empathize → Boundary → Redirect → Door Open

- [ ] **Task 2: Add Domain-Specific Guardrail Context** (AC: #4, #5)
  - [ ] 2.1 Add `guardrails` field to each domain config JSON file with domain-specific clinical boundaries (e.g., fitness: no nutrition/medical advice, mindset: no psychiatric labeling, relationships: no couples therapy scope)
  - [ ] 2.2 Update `DomainConfig` interface in `domain-configs.ts` to include optional `guardrails` field
  - [ ] 2.3 Update `buildCoachingPrompt()` to append domain-specific guardrails to the system prompt when present

- [ ] **Task 3: Add Comprehensive Tests** (AC: #6)
  - [ ] 3.1 Add test: "includes TONE_GUARDRAILS_INSTRUCTION in all prompts"
  - [ ] 3.2 Add test: "includes CLINICAL_BOUNDARY_INSTRUCTION in all prompts"
  - [ ] 3.3 Add test: "guardrails prohibit dismissive, sarcastic, harsh tones"
  - [ ] 3.4 Add test: "guardrails prohibit diagnosis, prescription, clinical expertise claims"
  - [ ] 3.5 Add test: "guardrails include warm boundary reframe pattern"
  - [ ] 3.6 Add test: "domain-specific guardrails appended when present in config"
  - [ ] 3.7 Add test: "crisis instructions include specific resource information (988, Crisis Text Line)"

- [ ] **Task 4: Verify Integration with Existing Pipeline** (AC: #1, #2, #3, #4)
  - [ ] 4.1 Verify guardrails don't conflict with existing PATTERN_TAG_INSTRUCTION
  - [ ] 4.2 Verify guardrails don't conflict with MEMORY_TAG_INSTRUCTION
  - [ ] 4.3 Verify guardrails work across all 8 domain configs
  - [ ] 4.4 Manual testing: send provocative/clinical messages and verify response tone (user will test)

## Dev Notes

### What This Story IS

This story is about **prompt engineering** — hardening the system prompt with comprehensive tone guardrails and clinical boundary instructions that the LLM must follow. All changes are in the Supabase Edge Function layer (`prompt-builder.ts` and domain configs). There are **no iOS-side changes** in this story.

### What This Story Is NOT

- NOT crisis detection (that's Story 4.1 — crisis-detector.ts)
- NOT crisis resource display UI (that's Story 4.2 — CrisisResourceSheet.swift)
- NOT disclaimers UI (that's Story 4.3 — DisclaimerView.swift)
- NOT post-crisis context continuity (that's Story 4.5)

### Architecture Pattern: Prompt-Based Guardrails

This story follows the exact same pattern established in Stories 3.1-3.5:

| Story | Constant Added to prompt-builder.ts | Purpose |
|-------|-------------------------------------|---------|
| 3.1 | Domain routing in `buildCoachingPrompt()` | Route to correct coaching domain |
| 3.3 | `MEMORY_TAG_INSTRUCTION` | Tag memory references with `[MEMORY: ...]` |
| 3.4 | `PATTERN_TAG_INSTRUCTION` | Tag pattern insights with `[PATTERN: ...]` |
| 3.5 | Cross-domain synthesis section | Synthesize across domains |
| **4.4** | **`TONE_GUARDRAILS_INSTRUCTION` + `CLINICAL_BOUNDARY_INSTRUCTION`** | **Enforce tone safety and clinical boundaries** |

All of these are **prompt instructions** — they tell the LLM how to behave. No additional LLM calls. No new API endpoints. Just expanding the system prompt.

### System Prompt Construction Order (After This Story)

The `buildCoachingPrompt()` function constructs the system prompt in this order:

```
1. BASE_COACHING_PROMPT (existing)
2. TONE_GUARDRAILS_INSTRUCTION ← NEW (this story)
3. CLINICAL_BOUNDARY_INSTRUCTION ← NEW (this story)
4. Domain-specific config (systemPromptAddition, tone, methodology, personality)
5. Domain-specific guardrails ← NEW (this story, optional per domain)
6. DOMAIN_TRANSITION_INSTRUCTION (existing)
7. CLARIFY_INSTRUCTION (existing, conditional)
8. User context section (existing, conditional)
9. MEMORY_TAG_INSTRUCTION (existing, conditional)
10. Conversation history section (existing, conditional)
11. PATTERN_TAG_INSTRUCTION (existing, conditional)
12. Cross-domain patterns (existing, conditional)
```

### Key Design Decisions

1. **Guardrails in system prompt, not a separate validation layer** — Follows proven pattern. Zero additional LLM calls. Zero latency impact.

2. **Warm boundaries, not clinical disclaimers** — No "WARNING: I am not a therapist" banner. Boundaries emerge naturally in conversation through the reframe pattern (Empathize → Boundary → Redirect → Door Open).

3. **Domain-specific guardrails are additive** — The base TONE_GUARDRAILS_INSTRUCTION and CLINICAL_BOUNDARY_INSTRUCTION apply to ALL domains. Domain-specific guardrails in the JSON configs add extra context (e.g., fitness domain shouldn't give nutrition/medical advice).

4. **No post-response validation in this story** — The LLM following the system prompt is the guardrail. A separate post-response filter would add latency and complexity. If needed later, that's a separate story.

### Tone Guardrails Content Guide

**The TONE_GUARDRAILS_INSTRUCTION should prohibit:**
- Dismissive tone ("That's not a big deal", "Just let it go")
- Sarcastic tone ("Oh great, another career crisis")
- Harsh/judgmental tone ("You're being unreasonable", "That's a terrible idea")
- Patronizing tone ("I know it's hard, sweetie")
- Cold/robotic tone ("Your emotional state requires intervention")

**The TONE_GUARDRAILS_INSTRUCTION should enforce:**
- Always warm and empathetic
- Short responses with follow-up questions (coaching rhythm, not lectures)
- "I've noticed..." not "Analysis shows..."
- First-person framing for errors/limitations ("I can't help with..." not "This system cannot...")
- Warm even in boundary-setting and refusals

### Clinical Boundary Content Guide

**The CLINICAL_BOUNDARY_INSTRUCTION should cover:**

| Scenario | Wrong Response | Correct Response Pattern |
|----------|---------------|-------------------------|
| User asks "Do I have ADHD?" | "You have ADHD" / "You show signs of ADHD" | "You're clearly concerned about your focus. A professional could help clarify what's going on. From a coaching angle, I can help you build strategies that work for you right now." |
| User asks about medication | "You should try SSRIs" / "Medication X helps with..." | "Medication questions deserve real expertise from your doctor. I can help you prepare for that conversation — what questions do you want to ask them?" |
| User wants therapy-level support | "Let me help you process your trauma" | "This sounds like something that would really benefit from a therapist's expertise. I'm here for coaching — helping you figure out what steps feel right for you." |
| User mentions a diagnosis | "Your anxiety disorder means..." | "I hear that you've been dealing with anxiety. From a coaching perspective, how is it affecting the goals you care about most?" |

**Boundary Reframe Pattern (from UX Spec "Held, Not Handled"):**
```
1. EMPATHIZE — Validate what they're experiencing
2. BOUNDARY — Honestly acknowledge scope limits
3. REDIRECT — Suggest appropriate professional resource
4. DOOR OPEN — "I'm here for coaching when you want to explore what comes next"
```

### Domain-Specific Guardrails to Add

| Domain | Additional Guardrails |
|--------|----------------------|
| general | Base guardrails only |
| life | Don't assume life decisions require therapy; coach on practical steps |
| career | Don't diagnose workplace burnout as clinical depression |
| relationships | Don't act as couples therapist; coach individual perspective |
| mindset | Don't label cognitive patterns as psychiatric conditions |
| creativity | Don't pathologize creative blocks as mental health issues |
| fitness | Don't give medical/nutrition advice; defer to doctor/dietitian |
| leadership | Don't diagnose organizational dysfunction as individual pathology |

### Project Structure Notes

**Files to MODIFY:**

| File | Location | What to Change |
|------|----------|----------------|
| `prompt-builder.ts` | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` | Add TONE_GUARDRAILS_INSTRUCTION, CLINICAL_BOUNDARY_INSTRUCTION constants; inject into buildCoachingPrompt() |
| `domain-configs.ts` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs.ts` | Add optional `guardrails` field to DomainConfig interface |
| `general.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/general.json` | Add guardrails section |
| `career.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/career.json` | Add guardrails section |
| `life.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/life.json` | Add guardrails section |
| `relationships.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/relationships.json` | Add guardrails section |
| `mindset.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/mindset.json` | Add guardrails section |
| `creativity.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/creativity.json` | Add guardrails section |
| `fitness.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/fitness.json` | Add guardrails section |
| `leadership.json` | `CoachMe/Supabase/supabase/functions/_shared/domain-configs/leadership.json` | Add guardrails section |
| `prompt-builder.test.ts` | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` | Add tone/boundary validation tests |

**Files to NOT create** — all changes fit within existing files following established patterns.

### What Exists Already in prompt-builder.ts

The current `BASE_COACHING_PROMPT` (lines ~47-57) contains minimal guardrails:
```typescript
- Be warm, empathetic, and non-judgmental
- Never diagnose, prescribe, or claim clinical expertise
- If users mention crisis indicators (self-harm, suicide), acknowledge their feelings and encourage professional help
```

This is **a good start but insufficient**. Story 4.4 expands this with:
1. Explicit anti-tone directives (what NOT to do)
2. Specific clinical boundary scenarios with correct response patterns
3. The boundary reframe pattern (Empathize → Boundary → Redirect → Door Open)
4. Domain-specific guardrails

### Existing Pattern to Follow: PATTERN_TAG_INSTRUCTION

Lines ~75-79 of prompt-builder.ts show the pattern:
```typescript
const PATTERN_TAG_INSTRUCTION = `...
CRITICAL RULES:
- Only surface patterns when you're genuinely confident
- NEVER force pattern observations
- Use warm, curious framing — you're reflecting, not diagnosing
- One pattern insight per response maximum
`;
```

Story 4.4's constants should follow this exact style — clear, directive, with CRITICAL RULES and explicit examples of what TO do and what NOT to do.

### Integration with Crisis Detection (Story 4.1)

Story 4.1 (Crisis Detection Pipeline) creates `crisis-detector.ts` and runs BEFORE the LLM call. Story 4.4's guardrails are IN the system prompt and run DURING the LLM call. They are complementary:

- **4.1 Crisis Detection**: Catches crisis keywords → returns `crisis_detected` flag → triggers crisis resource display
- **4.4 Tone Guardrails**: Ensures the LLM's *generated response* is always warm, never clinical, and follows boundary patterns even when crisis is NOT detected (e.g., user asks about medication but isn't in crisis)

Story 4.4 does NOT depend on 4.1 being implemented. The guardrails work independently.

### Git Intelligence

Recent commits:
```
f2fa466 Epic 3: Domain routing, config engine, memory references, pattern synthesis, conversation history
6aabc11 Epic 2 context profiles, settings sign-out, UI polish, and migrations
ad8abd3 checkpoint
```

The current codebase includes all Epic 3 work (Stories 3.1-3.7). Story 4.4 builds directly on this.

### References

- [Source: architecture.md#API-Communication-Patterns] — SSE streaming pipeline showing where guardrails inject
- [Source: architecture.md#Implementation-Patterns] — Error handling pattern with warm first-person messages
- [Source: architecture.md#Project-Structure] — Features/Safety/ module location and _shared/ Edge Function helpers
- [Source: epics.md#Story-4.4] — Original AC: tone guardrails in system prompt, clinical boundary rules in prompt-builder.ts
- [Source: ux-design-specification.md#Crisis-Handling-Flow] — "Held, not handled" principle, boundary reframe pattern
- [Source: ux-design-specification.md#Emotional-Design] — "Safe, Seen, Grounded" register, anti-patterns per stage
- [Source: prompt-builder.ts] — BASE_COACHING_PROMPT, PATTERN_TAG_INSTRUCTION pattern to follow
- [Source: domain-configs/*.json] — 8 domain config files with existing tone fields

### Testing Strategy

**Tests to add to `prompt-builder.test.ts`:**

```typescript
describe('Tone Guardrails & Clinical Boundaries', () => {
  it('includes TONE_GUARDRAILS_INSTRUCTION in all prompts');
  it('includes CLINICAL_BOUNDARY_INSTRUCTION in all prompts');
  it('guardrails prohibit dismissive, sarcastic, harsh tones');
  it('guardrails prohibit diagnosis and clinical labeling');
  it('guardrails prohibit medication/treatment prescription');
  it('guardrails prohibit claiming clinical expertise');
  it('guardrails include warm boundary reframe pattern');
  it('guardrails include crisis resource information (988, Crisis Text Line)');
  it('domain-specific guardrails appended when present in config');
  it('guardrails do not conflict with PATTERN_TAG_INSTRUCTION');
  it('guardrails do not conflict with MEMORY_TAG_INSTRUCTION');
});
```

**Specific tests to run after implementation:**

No iOS-side tests needed for this story. Run Edge Function tests only.

**Edge Function tests** (run manually via Deno):
```bash
cd CoachMe/Supabase/supabase/functions/_shared
deno test prompt-builder.test.ts
```

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
