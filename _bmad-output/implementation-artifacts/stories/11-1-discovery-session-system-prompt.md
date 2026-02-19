# Story 11.1: Discovery Session System Prompt

Status: done

## Story

As a **product**,
I want **a research-backed system prompt that guides the AI through a dynamic discovery conversation**,
So that **every new user feels deeply understood and emotionally invested before seeing the paywall**.

## Acceptance Criteria

1. **Given** a new user starts their first conversation, **When** the system prompt is loaded, **Then** the AI operates in discovery mode with the full discovery prompt (not the regular coaching prompt).

2. **Given** the AI is in discovery mode, **When** it responds to user messages, **Then** every response follows the pattern: precise reflection → emotional validation → one question (never multiple questions per message).

3. **Given** the conversation reaches messages 8-10, **When** the AI has gathered enough context, **Then** it delivers a synthesized insight that connects dots the user hasn't connected themselves (the "aha moment") — referencing specific things from at least 3 earlier messages.

4. **Given** the conversation reaches messages 12-15, **When** the discovery is complete, **Then** the AI signals `[DISCOVERY_COMPLETE]` with a structured JSON context profile and a personalized coaching preview.

5. **Given** the user shares something vulnerable, **When** the AI responds, **Then** it never expresses judgment, surprise, or disapproval — only warmth, validation, and gratitude (unconditional positive regard).

6. **Given** the discovery prompt is loaded, **When** measuring token count, **Then** the system prompt is ≤1,200 tokens (optimized for Haiku's context window and cost target of ~$0.035/user for 12 messages).

7. **Given** crisis indicators are detected during discovery, **When** the AI responds, **Then** the existing crisis detection pipeline (Story 4.1) activates and the crisis prompt overrides discovery behavior — discovery resumes only after crisis is resolved.

8. **Given** the discovery conversation is in progress, **When** the AI silently tracks context, **Then** it populates all extraction fields: `coaching_domains`, `current_challenges`, `emotional_baseline`, `communication_style`, `key_themes`, `strengths_identified`, `values`, `vision`, `aha_insight`.

## Tasks / Subtasks

- [x] Task 1: Create discovery system prompt file (AC: #1, #2, #5, #6)
  - [x] 1.1 Create `CoachMe/Supabase/supabase/functions/_shared/discovery-system-prompt.md` with the full research-backed prompt
  - [x] 1.2 Implement 6-phase conversation arc (Welcome → Exploration → Deepening → Aha Moment → Hope & Vision → Bridge to Paywall)
  - [x] 1.3 Embed the 5 Non-Negotiable Rules (reflect before ask, one question per message, go where emotion is, never judge, use their words)
  - [x] 1.4 Include emotional intelligence guidelines (precise labeling, connecting content to emotion, reflecting underlying needs, noting what's unsaid)
  - [x] 1.5 Include cultural sensitivity guidelines (multiple entry points, normalization, respect pacing, universal bridge topics)
  - [x] 1.6 Validate prompt token count ≤1,200 tokens (count with `tiktoken` or manual estimation)

- [x] Task 2: Add discovery prompt to prompt-builder (AC: #1, #7)
  - [x] 2.1 In `prompt-builder.ts`, add `buildDiscoveryPrompt()` function that loads the discovery system prompt
  - [x] 2.2 Load discovery prompt from the `.md` file at module initialization (same pattern as domain configs)
  - [x] 2.3 Ensure crisis detection still works during discovery — if `crisisDetected === true`, prepend `CRISIS_PROMPT` before discovery prompt (same override pattern as regular coaching)
  - [x] 2.4 Export `buildDiscoveryPrompt` for use by `chat-stream/index.ts`

- [x] Task 3: Implement `[DISCOVERY_COMPLETE]` signal and context extraction (AC: #3, #4, #8)
  - [x] 3.1 Add context extraction instructions to the discovery prompt — AI must silently track and populate: `coaching_domains`, `current_challenges`, `emotional_baseline`, `communication_style`, `key_themes`, `strengths_identified`, `values`, `vision`, `aha_insight`
  - [x] 3.2 Define the `[DISCOVERY_COMPLETE]` output format: AI outputs `[DISCOVERY_COMPLETE]` tag followed by structured JSON with all extraction fields
  - [x] 3.3 Add `hasDiscoveryComplete()` and `extractDiscoveryProfile()` helper functions to `prompt-builder.ts` (following same pattern as `hasMemoryMoments()` / `extractMemoryMoments()`)
  - [x] 3.4 Add `stripDiscoveryTags()` to remove `[DISCOVERY_COMPLETE]` block from user-visible response text

- [x] Task 4: Write tests for discovery prompt integration (AC: #1-#8)
  - [x] 4.1 Add unit tests for `buildDiscoveryPrompt()` in `prompt-builder.test.ts` — verify prompt composition, crisis override behavior
  - [x] 4.2 Add unit tests for `hasDiscoveryComplete()`, `extractDiscoveryProfile()`, `stripDiscoveryTags()` — verify parsing of structured JSON from AI output
  - [x] 4.3 Add test for prompt token count ≤1,200 tokens
  - [x] 4.4 Add test verifying crisis prompt takes priority over discovery prompt when `crisisDetected === true`

## Dev Notes

### Architecture & Patterns

- **System prompts are server-side only** — never in iOS client code (Architecture constraint)
- **Prompt composition order** in `prompt-builder.ts`: CRISIS_PROMPT (if crisis) → BASE/DISCOVERY prompt → context sections. Discovery prompt replaces the regular `BASE_COACHING_PROMPT` + domain sections — it is a complete standalone prompt
- **File loading pattern**: Follow `domain-configs.ts` pattern — load `.md` file at module init via top-level await, cache in module-level variable
- **Tag detection pattern**: Follow existing `hasMemoryMoments()` / `extractMemoryMoments()` / `stripMemoryTags()` pattern in `prompt-builder.ts` for the new `[DISCOVERY_COMPLETE]` tag helpers
- **Model routing**: This story creates the prompt only. Model routing (Haiku for discovery, Sonnet for paid) is Story 11.2's responsibility. The prompt should work with any model but is optimized for Haiku's strengths (warm, conversational, good at questions)
- **Crisis integration**: The existing `CRISIS_PROMPT` from Story 4.1 must override discovery behavior. The pattern is: if `crisisDetected === true`, prepend crisis prompt regardless of mode. Discovery resumes naturally after crisis response.

### Research Foundation

This story's prompt is backed by extensive research documented in [11-1-discovery-prompt-research.md](_bmad-output/implementation-artifacts/stories/11-1-discovery-prompt-research.md):

| Framework | Application in Prompt |
|-----------|----------------------|
| **Motivational Interviewing (OARS)** | Reflective listening structure, open-ended questions, affirmations, scaling technique |
| **ICF "Evokes Awareness"** | One powerful question per message, forward-focused, connected to values |
| **Carl Rogers' Core Conditions** | Unconditional positive regard (Rule #4), empathic understanding (precise reflections), congruence |
| **Social Penetration Theory** | 6-phase graduated escalation — surface → values → vulnerability → synthesis |
| **Aron's Fast Friends** | Structured escalating self-disclosure creates intimacy in 15 messages |
| **IKEA Effect** | User co-creates their coaching profile through sharing — feels like "theirs" |
| **Peak-End Rule** | Design emotional peak at messages 9-10 (aha moment), end on hope before paywall |
| **Funnel Technique** | What → Why → How does that feel → What does it mean progression |

### Key Design Decisions

1. **Discovery prompt is a COMPLETE replacement** for the regular coaching prompt (not an add-on). During discovery, the AI operates under entirely different instructions — no domain routing, no pattern synthesis, no memory references. It's a focused discovery conversation.

2. **The `[DISCOVERY_COMPLETE]` signal is embedded in the AI's response**, not a separate API call. The prompt instructs the AI to output the tag + JSON when Phase 6 conditions are met. The Edge Function (Story 11.2) will detect and parse this.

3. **Context extraction is "silent"** — the AI tracks fields internally throughout the conversation and only outputs the structured JSON at `[DISCOVERY_COMPLETE]`. The user never sees the extraction happening.

4. **The aha moment (Phase 4) is the conversion moment**. The prompt must instruct the AI to: synthesize everything shared, reference 3+ earlier messages, name an unstated pattern, phrase as gentle hypothesis. This is the Peak-End Rule's "peak."

5. **Haiku optimization**: Keep instructions concise, use clear formatting (numbered rules, phases), avoid ambiguity. Haiku excels at following structured instructions with warm conversational tone.

### Prompt Token Budget

| Section | Estimated Tokens |
|---------|-----------------|
| Role & identity | ~80 |
| 5 Non-Negotiable Rules | ~200 |
| 6-Phase Conversation Arc | ~500 |
| Emotional Intelligence Guidelines | ~150 |
| Cultural Sensitivity | ~80 |
| What You Must Never Do | ~100 |
| Context Extraction Instructions | ~90 |
| **Total** | **~1,200** |

### Cost Target

- Discovery = ~12 messages × Haiku ($0.25/$1.25 per MTok)
- ~1,200 token system prompt + ~800 tokens/message context
- **Estimated cost per discovery: ~$0.035/user**

### File Paths

| File | Purpose |
|------|---------|
| `CoachMe/Supabase/supabase/functions/_shared/discovery-system-prompt.md` | Discovery prompt content (NEW) |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` | Add `buildDiscoveryPrompt()`, tag helpers (MODIFY) |
| `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` | Add discovery prompt tests (MODIFY) |

### What This Story Does NOT Include

- **Model routing** (Haiku vs Sonnet) — that's Story 11.2
- **iOS UI changes** (welcome screen, onboarding flow) — that's Story 11.3
- **Database schema changes** (discovery_completed_at, new profile fields) — that's Story 11.4
- **Personalized paywall** — that's Story 11.5
- **Message counting bypass** — that's Epic 10 integration in Story 11.2

### Project Structure Notes

- New file `discovery-system-prompt.md` follows the `_shared/` pattern for shared Edge Function resources
- Prompt content in `.md` file (not inline TypeScript string) enables: version control diffing, A/B testing, non-developer editing, token counting tools
- All modifications to `prompt-builder.ts` follow existing conditional section pattern — discovery is a new branch, not a modification of existing logic

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11, Story 11.1] — User story, AC, prompt content, technical notes
- [Source: _bmad-output/implementation-artifacts/stories/11-1-discovery-prompt-research.md] — Full research foundation (MI, ICF, Rogers, behavioral psychology, wellness apps, conversion triggers)
- [Source: _bmad-output/planning-artifacts/architecture.md] — System prompt server-side constraint, prompt-builder composition, model routing, SSE format
- [Source: _bmad-output/planning-artifacts/prd.md] — FR1 (zero friction), FR10-13 (context), FR16-18 (crisis), NFR1 (500ms TTFT), NFR13 (prompt injection hardening)
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts] — Existing prompt composition pattern, tag helpers, crisis override logic
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — SSE pipeline, model selection, context loading

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No errors encountered during implementation.

### Completion Notes List

- **Task 1**: Created `discovery-system-prompt.md` (499 words, ~750 estimated tokens — well under 1,200 budget). Prompt implements all 5 research frameworks: MI OARS, ICF Evokes Awareness, Carl Rogers' Core Conditions, Social Penetration Theory graduated escalation, and Peak-End Rule aha moment design. 6-phase conversation arc covers Welcome → Exploration → Deepening → Aha Moment → Hope & Vision → Bridge.
- **Task 2**: Added `buildDiscoveryPrompt(crisisDetected)` to `prompt-builder.ts`. Follows `domain-configs.ts` pattern — loads `.md` file via top-level `await loadDiscoveryPrompt()`, caches in module-level `discoveryPromptContent` variable. Crisis override prepends `CRISIS_PROMPT` before discovery content (same pattern as `buildCoachingPrompt`).
- **Task 3**: Added `DiscoveryProfile` interface with all 9 extraction fields. Implemented `hasDiscoveryComplete()`, `extractDiscoveryProfile()`, and `stripDiscoveryTags()` following exact same regex pattern as existing `hasMemoryMoments`/`extractMemoryMoments`/`stripMemoryTags`. Uses `[DISCOVERY_COMPLETE]...[/DISCOVERY_COMPLETE]` paired tags (unlike single `[MEMORY:]` tags) because the discovery block contains multi-line JSON.
- **Task 4**: Added 30 new tests covering: `buildDiscoveryPrompt` (prompt content, 6 phases, 5 rules, UPR, EI, cultural sensitivity, extraction fields, signal format, no regular coaching content, no domain routing), token count validation, crisis override priority and ordering, `hasDiscoveryComplete` (presence, absence, partial, multiline, case insensitive), `extractDiscoveryProfile` (full parse, null cases, malformed JSON, missing field defaults, multiline JSON), `stripDiscoveryTags` (removal, preservation, multiline, non-interference with MEMORY/PATTERN tags), and DiscoveryProfile type compile check.

### Implementation Plan

Discovery prompt is a COMPLETE standalone replacement for the regular coaching prompt — `buildDiscoveryPrompt()` returns only the discovery `.md` content (with optional crisis prepend), without any of the regular coaching infrastructure (no tone guardrails, clinical boundaries, domain routing, pattern synthesis, memory tags, reflections, or style adaptation). This is by design per the story's Dev Notes: "During discovery, the AI operates under entirely different instructions."

### File List

| Action | File |
|--------|------|
| NEW | `CoachMe/Supabase/supabase/functions/_shared/discovery-system-prompt.md` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` |

## Senior Developer Review (AI)

**Reviewer:** Sumanth (via Claude Opus 4.6 adversarial review)
**Date:** 2026-02-10
**Outcome:** Changes Requested → Fixed

### Findings (7 total: 1 HIGH, 3 MEDIUM, 3 LOW)

| ID | Severity | Description | Resolution |
|----|----------|-------------|------------|
| H1 | HIGH | Clinical boundary REFRAME PATTERN missing from discovery prompt — no structured response for diagnosis/medication questions during onboarding | **FIXED** — Added clinical boundary reframe instruction to "Never Do" section |
| M1 | MEDIUM | `loadDiscoveryPrompt()` silently returns empty string on failure — AI gets no system prompt | **FIXED** — Added fallback prompt + error logging in `buildDiscoveryPrompt()` |
| M2 | MEDIUM | `stripDiscoveryTags()` uses `.trim()` unlike `stripMemoryTags`/`stripPatternTags` | **FIXED** — Changed to `.trimEnd()` to preserve leading whitespace |
| M3 | MEDIUM | AC #2 requires "reflection → validation → question" but prompt lacked explicit 3-part structure | **FIXED** — Rule #1 now mandates: (1) precise reflection, (2) emotional validation, (3) one question |
| L1 | LOW | Token count test uses rough word-based estimation (1.5x) | Accepted — within budget headroom |
| L2 | LOW | Missing edge case test for empty content between discovery tags | Accepted — catch block handles correctly |
| L3 | LOW | `DiscoveryProfile` uses mutable array types | Accepted — minor type safety concern |

### Files Modified During Review

| Action | File |
|--------|------|
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/discovery-system-prompt.md` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts` |
| MODIFIED | `CoachMe/Supabase/supabase/functions/_shared/prompt-builder.test.ts` |

## Change Log

- **2026-02-10**: Story 11.1 implementation complete. Created research-backed discovery system prompt (~750 tokens), added `buildDiscoveryPrompt()` with crisis override support, implemented `[DISCOVERY_COMPLETE]` tag helpers (`hasDiscoveryComplete`, `extractDiscoveryProfile`, `stripDiscoveryTags`) with `DiscoveryProfile` interface, and added 30 comprehensive unit tests. All 8 acceptance criteria addressed.
- **2026-02-10**: Code review fixes (4 issues fixed). H1: Added clinical boundary reframe to discovery prompt. M1: Added fallback prompt when `.md` file fails to load. M2: Changed `stripDiscoveryTags` from `.trim()` to `.trimEnd()`. M3: Rule #1 now explicitly mandates 3-part response structure (reflect → validate → ask). Added 3 new tests.
