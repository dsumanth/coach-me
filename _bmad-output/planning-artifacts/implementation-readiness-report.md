---
stepsCompleted: [1, 2, 3, 4, 5, 6]
status: complete
project: Coach App
date: 2026-01-28
documents:
  - prd.md
  - architecture.md
  - epics.md
  - ux-design-specification.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-01-28
**Project:** Coach App

## 1. Document Inventory

| Document | File | Format | Status |
|----------|------|--------|--------|
| PRD | prd.md | Whole | Found |
| Architecture | architecture.md | Whole | Found |
| Epics & Stories | epics.md | Whole | Found |
| UX Design | ux-design-specification.md | Whole | Found |

- No duplicates detected
- No missing documents
- All 4 required documents present

## 2. PRD Analysis

### Functional Requirements (52 Total)

**Coaching Conversation (FR1-FR9):**
- FR1: Users can start a coaching conversation immediately without selecting a category, coach, or completing onboarding
- FR2: Users can send text messages and receive AI coaching responses via real-time token-by-token streaming
- FR3: Users can use voice input as an alternative to typing text messages
- FR4: Users can create and manage multiple conversation threads for different topics
- FR5: Users can view their complete conversation history across all sessions
- FR6: The system can detect the coaching domain from conversation content and route to the appropriate domain expertise invisibly
- FR7: The system can reference previous conversations within the current coaching response
- FR8: The system can identify recurring patterns across a user's conversations and surface them as insights
- FR9: The system can synthesize patterns across different coaching domains for the same user (cross-domain pattern recognition)

**Personal Context (FR10-FR15):**
- FR10: Users can add personal values, goals, and life situation to their context profile
- FR11: Users are prompted to set up their context profile after their first completed session
- FR12: The system can progressively extract context from conversations without requiring explicit user input
- FR13: The system can inject stored context (values, goals, situation, conversation history) into every coaching response
- FR14: Users can view, edit, and delete any part of their context profile
- FR15: Users can delete individual conversations or their entire conversation history

**Coaching Safety (FR16-FR22):**
- FR16: The system can detect crisis indicators (self-harm, suicidal ideation, abuse) in user messages
- FR17: The system can display crisis resources (988 Suicide & Crisis Lifeline, Crisis Text Line) when crisis indicators are detected
- FR18: The system can gracefully redirect from clinical topics to coaching scope without abandoning the user
- FR19: The system displays coaching disclaimers ("AI coaching, not therapy") during onboarding and in terms of service
- FR20: The system enforces tone guardrails -- never dismissive, sarcastic, or harsh regardless of user behavior
- FR21: The system prevents coaching responses that diagnose, prescribe, or claim clinical expertise
- FR22: The system can maintain context continuity after a crisis episode when the user returns to coaching

**Creator Tools (FR23-FR27):**
- FR23: Users can create a coaching persona by defining domain, tone, methodology, and personality
- FR24: Users can generate a unique shareable link for their created coaching persona
- FR25: Users can share a link to a specific coaching persona they created or love
- FR26: Recipients of a share link can start a coaching session with that specific persona
- FR27: Share links render Open Graph meta tags for rich social media previews (title, description, image)

**Account & Authentication (FR28-FR35):**
- FR28: Users can sign up and log in with email
- FR29: Users can sign up and log in with social login providers
- FR30: Users can unlock the iOS app using biometric authentication (Face ID / Touch ID)
- FR31: Users can authenticate on web using Passkey (WebAuthn)
- FR32: Users can delete their account and all associated data from within the app
- FR33: Users can access past conversations and their context profile while offline
- FR34: Users see a clear warning that new coaching conversations require an internet connection when offline
- FR35: User data syncs automatically when internet connection is restored

**Payments & Subscription (FR36-FR40):**
- FR36: Users can experience a free trial period without providing payment information
- FR37: Users can subscribe to the paid plan after the trial ends
- FR38: Users can manage their subscription (view status, cancel) from within the app
- FR39: iOS users complete payments through Apple In-App Purchase
- FR40: Web users complete payments through Stripe

**Notifications & Engagement (FR41-FR44):**
- FR41: Users receive proactive push notifications with context-aware check-ins between sessions
- FR42: Users can control push notification preferences (frequency, enable/disable)
- FR43: The system requests push notification permission after the first completed session, not on first launch
- FR44: Push notifications are delivered via APNs on iOS and Web Push API on web

**Operator Management (FR45-FR50):**
- FR45: The operator can view key product metrics on a monitoring dashboard (retention, engagement, user counts, costs)
- FR46: The operator can track API costs per user in real-time
- FR47: The operator can modify coaching domain configurations (tone, methodology, personality) without code changes
- FR48: The operator can add new coaching domains through configuration files, not code deployment
- FR49: The system enforces rate limiting to prevent abuse and cost overruns
- FR50: The operator can review user-created coaching personas for content safety

**Marketing & Discovery (FR51-FR52):**
- FR51: Visitors can access an SEO-optimized marketing landing page describing Coach App
- FR52: The app is available on both iOS (App Store) and web with feature parity

### Non-Functional Requirements (42 Total)

**Performance (NFR1-NFR9):**
- NFR1: Chat responses begin streaming within 500ms of user message (time to first token, P95)
- NFR2: User context profile and conversation history load within 200ms
- NFR3: Domain routing classification completes within 100ms
- NFR4: iOS app reaches interactive state within 2 seconds of launch
- NFR5: Web app initial page load completes within 3 seconds on 3G, 1 second on WiFi
- NFR6: Streaming text renders smoothly at 30+ tokens/second without UI jank
- NFR7: iOS app bundle size remains under 5MB; web initial bundle under 500KB
- NFR8: Active session memory usage stays under 100MB on both platforms
- NFR9: Offline conversation history loads within 500ms from local cache

**Security (NFR10-NFR18):**
- NFR10: All user data encrypted at rest using AES-256
- NFR11: All data in transit encrypted using TLS 1.3
- NFR12: Authentication tokens implement rotation with secure expiration policies
- NFR13: System prompts hardened against prompt injection
- NFR14: Personal context data never included in application logs or error reports
- NFR15: LLM provider API keys stored in secure environment variables
- NFR16: User account deletion permanently removes all associated data within 30 days (GDPR)
- NFR17: Session tokens invalidated on logout and password change
- NFR18: Rate limiting enforced per-user to prevent abuse

**Scalability (NFR19-NFR24):**
- NFR19: System supports 500 concurrent active users at launch
- NFR20: Architecture supports 10x user growth (5,000 concurrent) with infra scaling only
- NFR21: LLM API costs scale linearly with users
- NFR22: Context storage scales efficiently for users with 100+ sessions
- NFR23: Template engine supports adding new domains without performance impact
- NFR24: Database design supports efficient queries across growing history per user

**Accessibility (NFR25-NFR30):**
- NFR25: All user-facing interfaces comply with WCAG 2.1 AA standards
- NFR26: Chat interface fully navigable via keyboard
- NFR27: All interactive elements have appropriate screen reader labels and ARIA attributes
- NFR28: Color contrast ratios meet AA minimum (4.5:1 normal, 3:1 large text)
- NFR29: Text supports dynamic type / user-configured font sizes on both platforms
- NFR30: Animations respect OS-level reduced motion preferences

**Integration (NFR31-NFR36):**
- NFR31: LLM integration layer is provider-agnostic
- NFR32: Apple IAP integration handles all subscription lifecycle events
- NFR33: Stripe integration supports subscription management, invoicing, and webhook processing
- NFR34: Social login supports at minimum Google and Apple sign-in
- NFR35: Push notification delivery achieves 95%+ success rate
- NFR36: All third-party integrations implement retry logic with exponential backoff

**Reliability (NFR37-NFR42):**
- NFR37: System maintains 99.9% uptime
- NFR38: No user context data is lost under any failure condition
- NFR39: If LLM provider unavailable, graceful degradation message within 3 seconds
- NFR40: Interrupted streaming responses display partial content with retry option
- NFR41: Offline-to-online transitions sync automatically without data conflicts
- NFR42: Crash rate remains below 1% of sessions

### Additional Requirements (from Domain-Specific Sections)

**Coaching Boundary Requirements:**
- Disclaimers visible in onboarding, ToS, and periodically in-app
- Terms of service explicitly disclaim therapeutic relationship
- Legal review before launch

**Privacy Requirements (Hybrid Model D):**
- Server-stored with strong encryption, full cross-device sync
- LLM providers with zero-retention API policies
- Data minimization -- only store what improves coaching quality
- No third-party sharing of personal context data
- GDPR readiness: consent collection, data portability, deletion rights

**AI Safety Requirements:**
- Hallucination prevention: never fabricate facts about user's context
- Prompt injection hardening for system prompts
- Creator content moderation (manual at MVP scale)

**App Store Compliance:**
- Apple IAP for iOS subscriptions (30% cut)
- AI content disclosure per Apple requirements
- In-app account deletion capability
- Privacy nutrition labels
- AI output complies with Apple content policies

**LLM Provider Requirements:**
- Provider abstraction: support swapping providers without rebuild
- Cost monitoring: alert thresholds at $2/user/month
- Rate limit handling: queuing or graceful degradation
- Terms compliance verification
- Graceful "temporarily unavailable" for provider outages

### PRD Completeness Assessment

The PRD is comprehensive and well-structured:
- 52 clearly numbered FRs across 8 categories
- 42 clearly numbered NFRs across 6 categories
- 5 detailed user journeys providing context
- Domain-specific requirements addressing coaching safety, privacy, and compliance
- Clear phased development strategy with prioritized cut list
- Measurable success criteria with specific targets

**No gaps identified in the PRD itself.**

## 3. Epic Coverage Validation

### Coverage Matrix

| FR | PRD Requirement | Epic Coverage | Status |
|----|----------------|---------------|--------|
| FR1 | Start conversation without onboarding | Epic 1 (1.6, 1.7) | ✅ Covered |
| FR2 | Send messages with streaming responses | Epic 1 (1.7) | ✅ Covered |
| FR3 | Voice input | *Cuttable* (PRD cut list #1) | ⚠️ Deferred |
| FR4 | Multiple conversation threads | Epic 3 (3.1) | ✅ Covered |
| FR5 | View conversation history | Epic 3 (3.1) | ✅ Covered |
| FR6 | Invisible domain routing | Epic 3 (3.2, 3.3) | ✅ Covered |
| FR7 | Reference previous conversations | Epic 3 (3.4) | ✅ Covered |
| FR8 | Pattern recognition across conversations | Epic 3 (3.5) | ✅ Covered |
| FR9 | Cross-domain pattern synthesis | Epic 3 (3.6) | ✅ Covered |
| FR10 | Add values, goals, situation to profile | Epic 2 (2.1, 2.3) | ✅ Covered |
| FR11 | Context prompt after first session | Epic 2 (2.2) | ✅ Covered |
| FR12 | Progressive context extraction | Epic 2 (2.5) | ✅ Covered |
| FR13 | Context injection into responses | Epic 2 (2.4) | ✅ Covered |
| FR14 | View/edit/delete context profile | Epic 2 (2.3) | ✅ Covered |
| FR15 | Delete conversations | Epic 2 (2.7) | ✅ Covered |
| FR16 | Crisis detection | Epic 4 (4.1) | ✅ Covered |
| FR17 | Crisis resource display | Epic 4 (4.2) | ✅ Covered |
| FR18 | Graceful clinical redirection | Epic 4 (4.3) | ✅ Covered |
| FR19 | Coaching disclaimers | Epic 4 (4.4) | ✅ Covered |
| FR20 | Tone guardrails | Epic 4 (4.5) | ✅ Covered |
| FR21 | No diagnose/prescribe responses | Epic 4 (4.3) | ✅ Covered |
| FR22 | Context continuity after crisis | Epic 4 (4.6) | ✅ Covered |
| FR23 | Create coaching persona | Epic 5 (5.1, 5.2) | ✅ Covered |
| FR24 | Generate share link | Epic 5 (5.4) | ✅ Covered |
| FR25 | Share persona link | Epic 5 (5.4) | ✅ Covered |
| FR26 | Start session via share link | Epic 5 (5.5) | ✅ Covered |
| FR27 | Open Graph meta tags | Epic 5 (5.6) | ✅ Covered |
| FR28 | Email sign up/login | Epic 1 (1.3) | ✅ Covered |
| FR29 | Social login | Epic 1 (1.4) | ✅ Covered |
| FR30 | Biometric unlock | Epic 7 (7.1, 7.2) | ✅ Covered |
| FR31 | Passkey (WebAuthn) | *Deferred* (post-MVP) | ⚠️ Deferred |
| FR32 | Account deletion | Epic 7 (7.3, 7.4, 7.5) | ✅ Covered |
| FR33 | Offline read access | Epic 8 (8.1, 8.4, 8.5) | ✅ Covered |
| FR34 | Offline warning | Epic 8 (8.2) | ✅ Covered |
| FR35 | Auto-sync on reconnect | Epic 8 (8.2, 8.3) | ✅ Covered |
| FR36 | Free trial | Epic 6 (6.2) | ✅ Covered |
| FR37 | Subscribe to paid plan | Epic 6 (6.3, 6.4) | ✅ Covered |
| FR38 | Manage subscription | Epic 6 (6.5) | ✅ Covered |
| FR39 | Apple IAP | Epic 6 (6.3) | ✅ Covered |
| FR40 | Stripe payments | Epic 6 (6.4) | ✅ Covered |
| FR41 | Proactive push notifications | Epic 9 (9.4) | ✅ Covered |
| FR42 | Notification preferences | Epic 9 (9.2, 9.3) | ✅ Covered |
| FR43 | Permission request timing | Epic 9 (9.2) | ✅ Covered |
| FR44 | APNs + Web Push delivery | Epic 9 (9.1) | ✅ Covered |
| FR45 | Monitoring dashboard (retention, engagement, users, costs) | Epic 10 (10.2+10.3+10.4 combined) | ⚠️ Partial |
| FR46 | Per-user API cost tracking in real-time | **NOT FOUND** | ❌ MISSING |
| FR47 | Modify domain configs without code changes | **NOT FOUND** | ❌ MISSING |
| FR48 | Add new domains via configuration files | **NOT FOUND** | ❌ MISSING |
| FR49 | Rate limiting for abuse prevention | **NOT FOUND** | ❌ MISSING |
| FR50 | Review user-created personas for safety | Epic 10 (10.6) | ✅ Covered |
| FR51 | SEO-optimized marketing landing page | **NOT FOUND** | ❌ MISSING |
| FR52 | iOS + web feature parity | Architecture-level concern, no explicit story | ⚠️ Partial |

### Critical Finding: Epic 10 FR Misalignment

**Stories 10.1-10.5, 10.7, 10.8 claim incorrect FR numbers.** The story content doesn't match the PRD FR it claims to implement:

| Story | Claims FR | Story Actually Does | PRD FR Actually Requires |
|-------|-----------|--------------------|--------------------|
| 10.1 | FR45 | Admin role & access control | Monitoring dashboard |
| 10.2 | FR46 | Dashboard shell with metric cards | Per-user API cost tracking |
| 10.3 | FR47 | System health monitoring | Modify domain configs without code |
| 10.4 | FR48 | Usage analytics dashboard | Add new domains via config files |
| 10.5 | FR49 | Revenue monitoring | Rate limiting |
| 10.6 | FR50 | Content moderation queue | Persona safety review ✅ CORRECT |
| 10.7 | FR51 | GDPR data export | SEO landing page |
| 10.8 | FR52 | System announcements | iOS + web feature parity |

### Missing FR Coverage

#### Critical Missing FRs

**FR47: Modify coaching domain configurations without code changes**
- Impact: Template engine management is a core operator capability (mentioned in Journey 5)
- Recommendation: Add story to Epic 10 for domain config editing UI or CLI

**FR48: Add new coaching domains through configuration files**
- Impact: Key architectural promise -- new domains = config, not code
- Recommendation: Add story to Epic 10 for domain config creation workflow

**FR49: Rate limiting for abuse prevention**
- Impact: Cost protection and abuse prevention (NFR18 also requires this)
- Recommendation: Add story to Epic 1 or Epic 10 for rate limiting middleware

**FR51: SEO-optimized marketing landing page**
- Impact: User acquisition channel, mentioned in PRD Platform Requirements
- Recommendation: Add story to Epic 10 or new Epic for marketing site

#### High Priority Missing FRs

**FR46: Per-user API cost tracking in real-time**
- Impact: Operator needs visibility into cost per user for sustainability
- Recommendation: Add acceptance criteria to Story 10.5 or create new story

#### Partially Covered FRs

**FR45: Monitoring dashboard**
- Stories 10.2 + 10.3 + 10.4 together deliver dashboard functionality
- Missing explicit "costs" metric card -- per-user cost not shown
- Recommendation: Fix FR mapping, add cost tracking to dashboard

**FR52: iOS + web feature parity**
- Addressed by Expo cross-platform architecture, not a discrete feature
- Recommendation: Could remain as architecture concern, or add validation story

#### Extra Stories Without PRD FR Backing

These stories provide useful operator functionality but have no corresponding PRD FR:
- **Story 10.1** (Admin Role): Reasonable prerequisite, supports NFR19
- **Story 10.7** (GDPR Data Export): Supports NFR16 compliance, but no FR
- **Story 10.8** (System Announcements): Not in PRD scope

### Coverage Statistics

- Total PRD FRs: 52
- FRs covered in epics: 44
- FRs explicitly deferred: 2 (FR3 cuttable, FR31 deferred)
- FRs missing coverage: 5 (FR46, FR47, FR48, FR49, FR51)
- FRs partially covered: 2 (FR45, FR52)
- **Coverage percentage: 84.6% (44/52)**
- **Coverage excluding deferred: 88% (44/50)**
- **Target: 100% -- 5 FRs require new stories or acceptance criteria**

## 4. UX Alignment Assessment

### UX Document Status

**Found:** `ux-design-specification.md` — comprehensive UX spec covering executive summary, emotional design, design system, component architecture, interaction patterns, and all critical screens.

### UX ↔ PRD Alignment

| UX Area | PRD Alignment | Status |
|---------|--------------|--------|
| Zero-friction first session (conversation starters) | FR1 | ✅ Aligned |
| Streaming text with coaching pace (50-100ms buffer) | FR2, NFR1, NFR6 | ✅ Aligned |
| Context prompt after first session | FR11 | ✅ Aligned |
| Memory moment visual treatment | FR7, FR13 | ✅ Aligned |
| Pattern insight presentation | FR8, FR9 | ✅ Aligned |
| Crisis intervention UX | FR16-FR22 | ✅ Aligned |
| Offline state communication | FR33-FR35 | ✅ Aligned |
| 4-tab navigation (Chat, History, Profile, Settings) | PRD user journeys | ✅ Aligned |
| Creator tools "Build Your Coach" experience | FR23-FR27 | ✅ Aligned |
| Paywall tied to value moments | FR36-FR40 | ✅ Aligned |
| Dark mode as option (not default) | UX emotional register | ✅ Aligned |
| Passkey deferred post-MVP | FR31 deferral | ✅ Aligned |
| Warm color palette (cream, terracotta) | PRD emotional positioning | ✅ Aligned |
| WCAG 2.1 AA accessibility | NFR25-NFR30 | ✅ Aligned |

**No PRD ↔ UX misalignments found.** The UX spec was created with the PRD as input and maintains full traceability.

### UX ↔ Architecture Alignment

| UX Requirement | Architecture Support | Status |
|---------------|---------------------|--------|
| Streaming text with buffer | SSE via Supabase Edge Functions | ✅ Supported |
| NativeWind v4.2.1 / Tailwind CSS v3.3.2 | Architecture specifies same versions | ✅ Supported |
| Atomic design component hierarchy | Architecture defines component structure | ✅ Supported |
| Memory moment metadata flag | Context injection pipeline supports tagging | ✅ Supported |
| Offline conversation caching | TanStack Query + AsyncStorage | ✅ Supported |
| CSS custom properties for theming | NativeWind supports this pattern | ✅ Supported |
| Tab bar navigation (Expo Router) | Architecture specifies Expo Router | ✅ Supported |
| Biometric unlock (Face ID / Touch ID) | expo-local-authentication specified | ✅ Supported |
| Responsive web layout (sidebar on desktop) | Expo web + Tailwind breakpoints | ⚠️ Implicit |

### Warnings

1. **Desktop Web Layout**: UX spec mentions a sidebar layout for conversation history on wide screens ("centered chat column with sidebar for history on wide screens"). The architecture doesn't explicitly address responsive breakpoints or desktop-specific layout components. This is an implementation detail but should be noted in Epic 1 Story 1.5 (Design System) or a dedicated story.

2. **Memory Moment Metadata**: The UX spec mentions that "the Edge Function can tag context-informed responses with a metadata flag, allowing StreamingText.tsx to apply a distinct visual treatment." This metadata tagging mechanism should be explicitly specified in Epic 2 Story 2.4 (Context Injection) acceptance criteria to ensure the UX treatment is implementable.

3. **Conversation Starters**: The UX spec defines specific conversation starters ("Something's been on my mind," "I need help with a decision," "I want to set a goal") that disappear after session 1. This behavior should be explicitly captured in Epic 1 Story 1.6 (Chat UI) acceptance criteria.

### UX Alignment Summary

**Overall: STRONG alignment.** The UX spec, PRD, and Architecture are well-coordinated. Three minor implementation detail warnings noted above — none are blockers, all are addressable within existing stories by refining acceptance criteria.

## 5. Epic Quality Review

### A. User Value Focus Check

| Epic | Title | User-Centric? | Value Proposition | Verdict |
|------|-------|---------------|-------------------|---------|
| 1 | Project Foundation & Core Chat Experience | ⚠️ Borderline | Users can chat with AI coach by end of epic | ✅ Acceptable |
| 2 | Personal Context & Memory | ✅ Yes | Users experience coaching that remembers them | ✅ Pass |
| 3 | Intelligent Domain Routing & Pattern Recognition | ✅ Yes | Users get domain-specific coaching automatically | ✅ Pass |
| 4 | Coaching Safety & Crisis Handling | ✅ Yes | Users are protected during crisis | ✅ Pass |
| 5 | Creator Tools & Sharing | ✅ Yes | Users can create and share coaching personas | ✅ Pass |
| 6 | Payments & Subscription | ✅ Yes | Users can subscribe to continue using Coach App | ✅ Pass |
| 7 | Auth Enhancements & Account Management | ✅ Yes | Users have biometric auth and account control | ✅ Pass |
| 8 | Offline Support & Data Sync | ✅ Yes | Users can access conversations offline | ✅ Pass |
| 9 | Engagement & Push Notifications | ✅ Yes | Users receive personalized re-engagement | ✅ Pass |
| 10 | Operator Tools & Launch Readiness | ✅ Yes | Operators can monitor and manage platform | ✅ Pass |

**Note on Epic 1:** Contains "As a developer" stories (1.1, 1.2) which don't deliver direct user value. This is standard for greenfield projects — the epic as a whole delivers user value (streaming chat) by Story 1.7. No technical-only epics exist.

### B. Epic Independence Validation

| Epic | Dependencies | Independent? | Verdict |
|------|-------------|-------------|---------|
| 1 | None (standalone) | ✅ | Pass |
| 2 | Epic 1 (auth + chat) | ✅ | Pass |
| 3 | Epic 1 + 2 (needs context for patterns) | ✅ | Pass |
| 4 | Epic 1 (needs chat) | ✅ | Pass |
| 5 | Epic 1 (needs auth + chat) | ✅ | Pass |
| 6 | Epic 1 (needs auth) | ✅ | Pass |
| 7 | Epic 1 (needs auth) | ✅ | Pass |
| 8 | Epic 1 (needs chat for caching) | ✅ | Pass |
| 9 | Epic 1 (needs auth for tokens) | ✅ | Pass |
| 10 | Epic 1 (needs auth for admin) | ✅ | Pass |

No circular dependencies. No epic requires a future epic. ✅

### C. Story Sizing and Independence

All 61 stories reviewed for:
- Completable by a single dev agent ✅
- No story spans multiple epics ✅
- Each story delivers a testable increment ✅

### D. Acceptance Criteria Quality

| Criterion | Assessment |
|-----------|-----------|
| Given/When/Then format | ✅ Consistent across all stories |
| Testable | ✅ Each AC can be verified independently |
| Error cases | ✅ Most stories include error/edge cases |
| Specificity | ✅ Clear expected outcomes |

### E. Within-Epic Dependency Check

All epics validated — stories build sequentially on previous stories only. No forward dependencies detected. ✅

### F. Database/Entity Creation Timing

| Table(s) | Created In | First Needed By | Verdict |
|----------|-----------|-----------------|---------|
| users (auth extension) | Story 1.2 | Story 1.3 (auth) | ✅ Just-in-time |
| conversations, messages | Story 1.2 | Story 1.6 (chat UI) | ⚠️ Borderline |
| user_context | Story 2.1 | Story 2.2 (context prompt) | ✅ Just-in-time |
| coaching_personas | Story 5.1 | Story 5.2 (creation form) | ✅ Just-in-time |
| user_push_tokens | Story 9.1 | Story 9.2 (permission) | ✅ Just-in-time |
| flagged_content | Story 10.6 | Story 10.6 (moderation) | ✅ Just-in-time |

**Note:** `conversations` and `messages` tables are created in Story 1.2 (Supabase setup) which is 4 stories before they're used (Story 1.6). This is borderline but acceptable since they're in the same epic and the Supabase schema is set up as a cohesive unit with RLS policies.

### G. Starter Template Validation

Architecture specifies `npx create-expo-app@latest coach-app`. Story 1.1 uses this exact command. ✅

### Quality Violations Found

#### 🔴 Critical Violations

**1. Epic 10: FR Traceability Broken**
Stories 10.1-10.5, 10.7, 10.8 claim FR numbers that don't match their actual content. The `**FRs**: FRXX` tags at the bottom of each story point to the wrong PRD requirement.

- Story 10.1 claims FR45 (monitoring dashboard) but implements admin role & access control
- Story 10.2 claims FR46 (per-user cost tracking) but implements dashboard shell
- Story 10.3 claims FR47 (domain config management) but implements system health monitoring
- Story 10.4 claims FR48 (add domains via config) but implements usage analytics
- Story 10.5 claims FR49 (rate limiting) but implements revenue monitoring
- Story 10.7 claims FR51 (SEO landing page) but implements GDPR data export
- Story 10.8 claims FR52 (platform parity) but implements system announcements

**Impact:** Developers will implement the wrong features or skip required features thinking they're covered.
**Remediation:** Remap FR tags to match actual story content, add missing stories for uncovered FRs.

**2. Epic 10: 5 PRD FRs Have No Implementation Story**
- FR46: Per-user API cost tracking — no story
- FR47: Modify domain configs without code changes — no story
- FR48: Add new domains via configuration files — no story
- FR49: Rate limiting for abuse prevention — no story
- FR51: SEO-optimized marketing landing page — no story

**Impact:** 5 PRD-mandated capabilities will not be built.
**Remediation:** Add 3-5 new stories to Epic 10 covering these FRs.

#### 🟠 Major Issues

**3. Stories 10.7 & 10.8: Features Not in PRD**
GDPR data export and system announcements are not PRD requirements. They may be valuable but they introduce scope creep.
**Remediation:** Either add these as FRs to the PRD (via Correct Course), or mark them as "stretch" stories.

#### 🟡 Minor Concerns

**4. Epic 1 Title: "Project Foundation"**
Borderline technical naming. Suggestion: "Core Chat Experience" alone would be more user-centric.

**5. Stories 1.1 & 1.2: Developer Stories**
"As a developer" stories in a user-facing epic. Standard for greenfield projects but noted.

**6. Epic 10 "What Gets Delivered" Section Mismatch**
The epic description (line 380-393) promises FR45-FR52 coverage, but the stories don't deliver FR46, FR47, FR48, FR49, FR51. The description should match actual story coverage.

### Best Practices Compliance Summary

| Check | Epics 1-9 | Epic 10 |
|-------|-----------|---------|
| Delivers user value | ✅ | ✅ |
| Epic independence | ✅ | ✅ |
| Stories appropriately sized | ✅ | ✅ |
| No forward dependencies | ✅ | ✅ |
| Database tables created when needed | ✅ | ✅ |
| Clear acceptance criteria | ✅ | ✅ |
| FR traceability maintained | ✅ | ❌ BROKEN |
| All claimed FRs covered | ✅ | ❌ 5 MISSING |

## 6. Summary and Recommendations

### Overall Readiness Status

### ⚠️ NEEDS WORK

The project is **nearly ready** for implementation. Epics 1-9 (53 of 61 stories) are well-structured, properly traced to PRD requirements, and ready for development. Epic 10 has significant FR traceability and coverage issues that must be resolved before implementation begins.

### Findings Summary

| Category | Issues Found | Severity |
|----------|-------------|----------|
| FR Coverage Gaps | 5 FRs missing stories (FR46, FR47, FR48, FR49, FR51) | 🔴 Critical |
| FR Traceability | 7 stories in Epic 10 mapped to wrong FR numbers | 🔴 Critical |
| Scope Additions | 2 stories (10.7, 10.8) not backed by PRD FRs | 🟠 Major |
| UX Alignment | 3 minor implementation detail gaps | 🟡 Minor |
| Epic Structure | Epics 1-9 pass all quality checks | ✅ No issues |
| Story Quality | All 61 stories have proper AC format | ✅ No issues |
| Dependencies | No forward dependencies or circular deps | ✅ No issues |
| Architecture Alignment | Starter template, db timing all correct | ✅ No issues |
| PRD Completeness | 52 FRs, 42 NFRs fully documented | ✅ No issues |

### Critical Issues Requiring Immediate Action

**1. Add Missing Stories to Epic 10** (5 stories needed)

| Missing FR | Recommended Story |
|-----------|-------------------|
| FR46 | Per-user API cost tracking dashboard (add to Story 10.5 as acceptance criteria or new story) |
| FR47 | Domain configuration editor (admin UI to modify coaching domain configs: tone, methodology, personality) |
| FR48 | New domain creation workflow (admin UI to add a new coaching domain via YAML/JSON config upload) |
| FR49 | Rate limiting middleware (per-user request throttling with configurable thresholds) |
| FR51 | Marketing landing page (SEO-optimized static page with app description, value proposition, download links) |

**2. Fix Epic 10 FR Traceability**

Correct the `**FRs**: FRXX` tags on Stories 10.1-10.8 to accurately reflect what each story implements. The stories themselves are fine — the FR labels are wrong.

Proposed remapping:
- Story 10.1 (Admin Role): Remove FR45, label as "Prerequisite — no direct FR"
- Story 10.2 (Dashboard Shell): Label as FR45 (partial — monitoring dashboard)
- Story 10.3 (System Health): Label as FR45 (partial — monitoring dashboard: health metrics)
- Story 10.4 (Usage Analytics): Label as FR45 (partial — monitoring dashboard: engagement)
- Story 10.5 (Revenue): Label as FR45 (partial — monitoring dashboard: costs) + FR46 (if cost-per-user added)
- Story 10.6 (Moderation): FR50 ✅ (already correct)
- Story 10.7 (GDPR Export): Remove FR51, label as "NFR16 support — no direct FR"
- Story 10.8 (Announcements): Remove FR52, label as "Stretch — no PRD FR"

**3. Decide on Extra Stories (10.7, 10.8)**

Stories 10.7 (GDPR Export) and 10.8 (System Announcements) implement features not in the PRD.

Options:
- **Option A**: Keep them and add corresponding FRs to the PRD (recommended for 10.7 — GDPR export supports NFR16 compliance)
- **Option B**: Remove them and defer to post-MVP
- **Option C**: Mark as "stretch" stories — implement only if time allows

### Recommended Next Steps

1. **Fix Epic 10**: Add 4-5 new stories for missing FRs (FR47, FR48, FR49, FR51; fold FR46 into existing story). Correct FR traceability labels on existing stories.

2. **Refine UX details in acceptance criteria**: Add conversation starter behavior to Story 1.6 AC. Add memory moment metadata flag to Story 2.4 AC. Note desktop layout requirements in Story 1.5.

3. **Proceed to Sprint Planning**: After Epic 10 fixes are applied, the project is ready for Phase 4 (Implementation). Run Sprint Planning (`/bmad-bmm-sprint-planning`) to generate the implementation sequence.

### What's Working Well

- **Epics 1-9** are solid, well-structured, and ready for development
- **PRD** is comprehensive with clear, numbered requirements
- **Architecture** aligns well with both PRD and UX spec
- **UX Design** is thorough with strong emotional design framework
- **Story quality** is consistently high across all 61 stories
- **No forward dependencies** — stories build correctly on previous work
- **Database creation timing** follows just-in-time principle

### Final Note

This assessment identified **10 issues** across **4 categories** (coverage, traceability, scope, UX detail). The 2 critical issues are concentrated in Epic 10 and are straightforward to fix — the core product stories (Epics 1-9, covering 53 stories) are implementation-ready. Address the Epic 10 issues before starting Sprint Planning to ensure complete FR coverage.

---

**Assessment completed:** 2026-01-28
**Assessor:** Implementation Readiness Workflow (BMAD Method)
**Report:** `_bmad-output/planning-artifacts/implementation-readiness-report.md`
