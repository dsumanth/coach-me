---
stepsCompleted: [1, 2]
inputDocuments:
  - 'product-brief-Coach App-2026-01-27.md'
  - 'prd.md'
  - 'architecture.md'
  - 'epics.md'
date: 2026-02-09
author: Sumanth
scope: Epic 8 — Adaptive Coaching Intelligence & Proactive Engagement
---

# Product Brief: Adaptive Coaching Intelligence

## Executive Summary

Coach App remembers — but it doesn't learn. The context system stores facts users provide and facts extracted from conversations, but there are no feedback loops. The app can't tell you what's actually working, can't adapt its coaching style to what resonates with you, can't connect dots across sessions proactively, and can't track your growth over time. It's a coach with a great memory but no ability to get better at coaching *you*.

Adaptive Coaching Intelligence transforms Coach App from "AI that remembers you" to "AI that grows with you." Four layers of invisible intelligence make the coach smarter with every session — and reach out between sessions with real insight. All learning surfaces through the coach's voice in conversation. The profile serves as a transparent control panel where users see, edit, or delete what the system has learned.

**Design Principle:** "A real coach has no dashboard." A great coach has a notebook they glance at before your session, a memory of what you said last time, and intuition built from working with you over time. Everything they learn, they surface through conversation. Coach App should work the same way.

---

## Core Vision

### Problem Statement

Coach App's current context system is **memory without learning**. The extraction pipeline works — every 5 AI responses, insights are extracted with confidence scoring, users confirm or dismiss them, and confirmed insights get injected into future coaching prompts. But this is fact-gathering, not intelligence.

The system knows *what you said*. It doesn't know:
- **What works for you** — which coaching responses you engaged with deeply vs. which fell flat
- **How you're changing** — whether your values are shifting, your goals evolving, your confidence growing
- **How to talk to you** — whether you prefer direct advice or exploratory questions, brief or detailed, challenging or supportive
- **When to reach out** — what patterns signal you need a nudge, or that a theme is recurring and worth surfacing

The feedback loop is open-ended: You talk → AI extracts facts → Facts get stored → Facts get injected. There's no closed loop where the system learns from outcomes and adapts.

### Problem Impact

- **For users:** Coaching feels the same at session 1 and session 50. The coach remembers more facts but doesn't get *better* at coaching. Users plateau instead of experiencing deepening insight.
- **For retention:** The "context moat" (users won't leave because the AI knows them) weakens if "knowing" is just fact recall. True learning creates a moat competitors can't replicate — the coach genuinely understands you.
- **For the product promise:** "AI that remembers you" is table stakes as competitors add memory features. "AI that *learns* you" is the next defensible position.

### Why Existing Solutions Fall Short

No AI coaching product has solved continuous learning:

| Solution | What It Does | What's Missing |
|----------|-------------|----------------|
| **ChatGPT Memory** | Stores facts you tell it | No behavioral inference, no style adaptation, no cross-session patterns |
| **Character.ai** | Maintains persona consistency | No user-specific learning, no coaching methodology |
| **Rocky.ai / Purpose** | Scripted coaching flows | No personalization depth, no progressive intelligence |
| **Coach App (current)** | Extracts and injects context | No feedback loops, no style adaptation, no proactive intelligence |

The gap: **every product treats personalization as a data problem** (store more facts about the user). True coaching personalization is a **learning problem** (understand what works for this specific person and adapt).

### Proposed Solution

Four layers of adaptive intelligence, all invisible to the user, all surfaced through the coach's voice:

**Layer 1: Learning Signals Infrastructure**
Capture behavioral signals from every interaction — insight confirmation/dismissal patterns, engagement depth per session, domain preferences, response engagement signals. This is the raw data that powers everything else.

**Layer 2: In-Conversation Intelligence**
- **Pattern Recognition:** Cross-session theme detection with confidence scoring. The coach surfaces patterns naturally: "This is the third time we've talked about X — what do you think is driving that?"
- **Progress Tracking:** Goal progress inference from conversation language shifts. Session-opening check-ins ("How did your presentation go?"). Monthly reflections delivered as coaching moments, not reports.
- **Style Adaptation:** Learn whether the user prefers direct vs. exploratory, brief vs. detailed, challenging vs. supportive — per domain. Adapt the system prompt dynamically.

**Layer 3: Between-Session Intelligence**
Smart push notifications powered by all learning layers. Not generic reminders — pattern-aware, progress-aware, style-adapted nudges: "You've been quiet this week. Last time this happened, you said work stress was building. Want to talk?"

**Layer 4: Transparent Control (Profile Enhancement)**
The existing profile section expands to show what the system has learned — inferred patterns, coaching preferences, domain interests, progress notes. Every item editable or deletable. The user always has full control.

**Privacy, Compliance & Data Governance:**

Learning signals introduce new user data that requires explicit privacy safeguards:

- **Data Retention & Minimization:** Learning signals (`learning_signals` table) are retained for 12 months from creation, then automatically purged. Aggregated/anonymized summaries in `coaching_preferences` may be retained longer as they contain no raw behavioral data. Raw message content is never stored in learning signal records — only derived signal types and metadata.
- **GDPR/CCPA Compliance:** The lawful basis for processing learning signals is legitimate interest (improving the coaching service for the specific user) combined with explicit user consent obtained at the notification permission prompt and profile transparency layer. Data subject rights are supported: users can view all learned data in the Profile Enhancement UI (Story 8.8), delete individual learned items (which records a `insight_dismissed` signal preventing re-inference), and request full data export/deletion via the existing Account Deletion flow (Story 6.6) which cascades to `learning_signals`, `coaching_preferences`, and `pattern_cache`.
- **Consent Flows:** Beyond notification permissions (Story 8.3), the Profile Enhancement UI (Story 8.8) serves as the ongoing consent/control surface. The warm empty state message ("As we talk more, I'll share what I'm learning about you here. You'll always be able to see, edit, or remove anything.") communicates the system's learning behavior. Users who delete all learned items effectively opt out of learning-powered features.
- **Pseudonymization & Model Training:** Learning signals are associated with `user_id` (a UUID) and are never linked to PII in the signal data itself. Learning signal data is NOT used for model training or any purpose beyond improving the individual user's coaching experience. No behavioral data is shared with third parties.
- **Operational Controls:** Access to `learning_signals` and `coaching_preferences` is governed by RLS (users access own data only; service_role for server-side analytics). All server-side access to learning data is logged via Supabase audit logs. Retention windows are enforced via a scheduled cleanup function.

### Key Differentiators

| Differentiator | What It Means | Why It Wins |
|---|---|---|
| **Conversation-first learning** | All intelligence surfaces through the coach's voice, not UI widgets | Feels like a real coaching relationship, not a data dashboard |
| **Behavioral inference** | System learns from what you *do*, not just what you *say* | ~75% of useful signals inferred without any user effort |
| **Style adaptation** | Coach learns HOW to talk to you, not just WHAT to say | Every other AI product uses one style for all users |
| **Closed feedback loop** | System learns from outcomes and adapts extraction + coaching | Competitors have open-ended memory; Coach App has intelligence |
| **Transparent control** | Profile shows everything learned; user can edit/delete | Trust through transparency — users feel safe, not surveilled |
| **Natural touchpoints** | Check-ins at session boundaries, monthly reflections as coaching moments | Low friction — no feedback buttons, no rating scales, no homework |

### Inference Accuracy Without Explicit Feedback

| Signal | Inference Accuracy | Method |
|---|---|---|
| Domain preference | ~95% | Count conversation topics |
| Engagement depth | ~85% | Message length, reply speed, follow-up questions, session duration |
| Pattern recognition | ~80% | LLM analysis across conversations |
| Coaching style preference | ~70% | Track which response styles get longer follow-ups |
| Progress on goals | ~50% | Language shift detection ("I'm struggling" → "I tried it") |
| Breakthrough moments | ~30% | Requires user confirmation via natural conversation |
| Whether advice was acted on | ~15% | Requires user mention in future session |

**Note:** The accuracy percentages in the table above are **target/assumption estimates** based on analogous systems (conversation AI platforms, coaching apps, therapeutic chatbot research), not measured results from Coach App. Key assumptions: (1) domain preference is high-confidence because it's a direct count of conversation topics, (2) engagement depth relies on proxy signals (message length, session duration) which correlate but are not definitive, (3) progress on goals requires language shift detection which is inherently noisy. These targets will be measured and iterated during implementation and post-launch validation — establish baseline metrics during the first 90 days of production data.

**~75% of useful learning signals can be inferred from behavior alone.** The remaining 25% comes from natural conversation touchpoints (session-opening check-ins, monthly reflections) — not feedback buttons.

---

## Implementation Scope

This feature is implemented as **Epic 8: Adaptive Coaching Intelligence & Proactive Engagement** — absorbing the original push notifications epic and expanding it with learning infrastructure.

### Stories (8 total)

| Story | Layer | Description |
|-------|-------|-------------|
| 8.1 Learning Signals Infrastructure | Foundation | Data models, behavioral tracking, engagement metrics |
| 8.2 APNs Push Infrastructure | Plumbing | Device tokens, APNs setup, basic push delivery |
| 8.3 Push Permission & Preferences | Control | Permission timing, notification settings |
| 8.4 Pattern Recognition Engine | Intelligence | Cross-session theme detection, pattern surfacing in conversation |
| 8.5 Progress Tracking & Reflections | Intelligence | Session check-ins, monthly reflections, growth detection |
| 8.6 Coaching Style Adaptation | Intelligence | Per-user style learning, domain-specific preferences |
| 8.7 Smart Push Notifications | Between-Session | Learning-powered proactive nudges |
| 8.8 Enhanced Profile | Transparency | Display learned knowledge, user edit/delete control |

### Dependency Chain

```
8.1 (Signals) ──→ 8.4 (Patterns) ──→ 8.5 (Progress) ──→ 8.7 (Smart Push)
              ──→ 8.6 (Style)   ──→ 8.7 (Smart Push)
              ──→ 8.8 (Profile) (depends on 8.1 + 8.4 + 8.6 for full display)
8.2 (APNs)   ──→ 8.3 (Permissions) ──────────────────→ 8.7 (Smart Push)
```

Stories 8.1 and 8.2 can be built in parallel. Stories 8.4, 8.5, 8.6 can be built in parallel after 8.1. Story 8.7 is the capstone that brings everything together. Story 8.8 depends on 8.1 (learning signals), 8.4 (patterns), and 8.6 (style adaptation) for full functionality — it can ship after 8.6 completes, which is when all three data sources are available for the profile display.
