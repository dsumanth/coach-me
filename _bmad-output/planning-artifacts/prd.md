---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, step-11-polish, step-12-complete]
inputDocuments:
  - 'product-brief-Coach App-2026-01-27.md'
workflowType: 'prd'
documentCounts:
  briefs: 1
  research: 0
  projectDocs: 0
classification:
  projectType: 'native_ios_app'
  domain: 'general_consumer_ai'
  complexity: 'medium'
  projectContext: 'greenfield'
author: Sumanth
date: 2026-02-05
pivotNote: 'Native iOS with progressive enhancement: iOS 18+ minimum, Liquid Glass on iOS 26+'
---

# Product Requirements Document - Coach App

**Author:** Sumanth
**Date:** 2026-02-05
**Platform:** Native iOS (iOS 18+, enhanced for iOS 26+)
**Design Language:** Adaptive (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25)

## Executive Summary

Coach App is a native iOS application that delivers AI-powered personal coaching with persistent memory. Unlike generic chatbots that forget you after each conversation, Coach App remembers your values, goals, and life situation — creating coaching that feels personal, not transactional.

The app uses **progressive enhancement** to deliver a premium experience across iOS versions:
- **iOS 26+**: Full Liquid Glass design language with lensing, morphing, and adaptive materials
- **iOS 18-25**: "Warm Modern" design with standard SwiftUI materials, subtle blurs, and warm gradients

Both experiences feel intentionally designed — the iOS 18 version is a complete, polished experience, not a degraded fallback. The warm, premium coaching aesthetic is consistent regardless of iOS version.

The business model is premium with free trial ($5-10/month subscription via Apple IAP). Creator tools allow anyone to build and share custom coaching personas, creating organic viral loops and a path toward a "Spotify of coaching" ecosystem.

This PRD defines the complete capability contract for Coach App's V1 launch as a **native iOS application**, covering functional requirements, non-functional requirements, adaptive platform specifications, design requirements for both iOS tiers, and phased development strategy.

## Success Criteria

The following criteria define what success looks like across user experience, business outcomes, and technical execution.

### User Success

**Behavioral Indicators:**

| Metric | Target | What It Proves |
|---|---|---|
| Session return rate | 50%+ return within 7 days | First session is compelling enough to come back |
| Context setup rate | 60%+ of returning users | The "remember me" promise is landing |
| Session depth | 70%+ reach 3+ exchanges | Users are engaging, not bouncing |
| Aha moment rate | 30%+ reach session 3 within 14 days | Progressive depth is working |
| Pattern insight rate | 20%+ of users with 5+ sessions receive a pattern-based insight they confirm as valuable | The AI isn't just remembering — it's understanding |

**Emotional Success Moments:**
- **The hook:** AI references a past conversation — user feels *seen*, not talked at
- **The mirror:** AI identifies a recurring pattern the user didn't recognize in themselves — genuine self-discovery moment
- **The shift:** User catches themselves thinking "I should ask Coach App about this" — it's becoming their go-to
- **The proof:** User tells a friend "it actually remembers me" — organic advocacy

**Failure Signals:**
- Users set up context but the AI responses still feel generic — context injection isn't working
- Users stop after session 1 — first experience isn't delivering enough value
- Users try multiple domains but feel like they're talking to different AIs — routing feels disjointed

### Business Success

**3-Month (Validation Phase):**

| Objective | Target | Decision Gate |
|---|---|---|
| Quality user base | 500 active users | Enough volume for meaningful PMF signal |
| Product-market fit | 40%+ Sean Ellis "very disappointed" score | If yes, invest in growth. If no, iterate core experience. |
| Unit economics | API cost <$2/user/month | Subscription model is sustainable |

**12-Month (Growth Phase):**

| Objective | Target | Decision Gate |
|---|---|---|
| User growth | 10,000+ active users | Organic growth engine is working |
| Creator ecosystem | 100+ shared coaches | Creator tools driving viral loops |
| Revenue | Positive unit economics at scale | Business is self-sustaining |

**Revenue Model:** Premium with free trial. 3-7 day trial or first N sessions (enough to hit session 3 aha moment), then $5-10/month subscription via Apple In-App Purchase.

### Technical Success

| Metric | Target | Notes |
|---|---|---|
| **API response time** | <500ms for chat responses (time to first token) | P95 latency for consumer AI apps |
| **Context retrieval** | <200ms to load user profile + history | Sub-second personalization |
| **Domain routing accuracy** | 90%+ correct domain detection | NLP classification baseline |
| **App launch to first interaction** | <1.5 seconds | iOS native performance |
| **Crash rate** | <0.5% of sessions | App Store quality threshold |
| **Data encryption** | AES-256 at rest, TLS 1.3 in transit | Industry standard for personal data |
| **Auth security** | Sign in with Apple, biometric | Apple ecosystem integration |
| **Context persistence accuracy** | 99%+ — no lost user data | Zero-tolerance for personal context loss |
| **UI animation rendering** | 60fps smooth animations | Both iOS 26 (Liquid Glass) and iOS 18-25 (Warm Modern) |
| **Cross-version satisfaction** | Equivalent NPS scores across iOS versions | Design doesn't feel "lesser" on iOS 18-25 |

### Measurable Outcomes

**Dashboard KPIs (track daily/weekly):**

| KPI | Target | Red Flag Threshold |
|---|---|---|
| DAU/MAU ratio | 25%+ | Below 15% |
| Week 1 retention | 40%+ | Below 25% |
| Context setup rate | 60%+ of returning users | Below 40% |
| Sessions/user/week | 2+ | Below 1 |
| Share/invite rate | 10%+ | Below 5% |
| API cost/user/month | <$2 | Above $3 |

## User Journeys

The following journeys map real usage scenarios to product capabilities. Each journey reveals specific requirements that informed the Functional Requirements section.

### Journey 1: The Guidance Seeker — Success Path

**Meet Priya, 28, product designer in Austin.**

**Opening Scene:** It's 10:47pm on a Tuesday. Priya just got out of a tense call with her manager — feedback that her recent project "lacked strategic thinking." She's stung. She opens Coach App because a coworker shared a link last week with the message "this thing actually remembers you."

**Rising Action:** The Liquid Glass interface feels warm and inviting — the chat floats elegantly above a soft gradient, controls translucent and responsive. She types: "My manager just told me I lack strategic thinking and I don't even know what that means in my context." The coach responds with a grounded, specific question — not a list, not a lecture. The streaming text appears smoothly, paced like a thoughtful response. At the end, the coach asks: "Want me to remember what matters to you so we can pick this up next time?" She adds her values, goal, and situation through an elegant sheet that slides up with glass morphing animations.

Three days later, she's preparing for a design review. She opens Coach App and says "I have a big presentation tomorrow and I want to come across as strategic, not just tactical." The coach references the manager feedback from Tuesday — the memory moment is highlighted with a subtle Liquid Glass treatment that draws attention without disrupting flow.

**Climax:** Two weeks in, session 5. Priya vents about another meeting where she stayed quiet. The coach surfaces a pattern insight: "This is the third time you've described staying silent when you disagree with a direction. What do you think is driving the pattern?" The insight appears with distinct visual treatment — whitespace and reflective pacing built into the Liquid Glass UI. Priya pauses. She hadn't connected those moments. Self-discovery.

**Resolution:** A month later, Priya speaks up in a design review and gets positive feedback. She opens Coach App to share the win. The coach remembers the pattern, celebrates the growth.

**Capabilities Revealed:**
- Zero-friction first session (no signup before value)
- Context prompt after first session ("remember what matters")
- Cross-session memory and reference
- Pattern recognition across conversations
- Career domain routing (detected automatically)
- Liquid Glass design enhancing emotional moments

---

### Journey 2: The Self-Improvement Enthusiast — Power User Path

**Meet Derek, 34, engineering manager in Seattle.**

**Opening Scene:** Derek has a shelf of leadership books and a meditation streak. He's not in crisis — he's optimizing. He downloads Coach App, immediately sets up his context profile: values (growth, directness, empathy), goals (become VP of Engineering, improve 1:1s, run a half marathon).

**Rising Action:** Derek uses Coach App 3-4 times per week across domains. Monday: leadership coaching. Wednesday: career coaching. Thursday: fitness coaching. The Liquid Glass interface adapts seamlessly — the same warm, focused experience regardless of domain. When he's stressed about a performance review, the coach connects it to his running training: "You told me you push through discomfort in training runs by focusing on the next mile marker. What's the next mile marker for this conversation?"

**Climax:** After 6 weeks, the coach synthesizes across domains: "You've mentioned 'not wanting to let people down' in your leadership 1:1s, your career goals, and even your running. Is that something you want to explore?" Derek hadn't seen the thread connecting his leadership anxiety, career ambition, and fitness perfectionism. Cross-domain pattern recognition.

**Resolution:** Derek becomes a daily user. He creates an "Engineering Leadership" coaching persona using the creator tools and shares it with peer managers. Three sign up.

**Capabilities Revealed:**
- Proactive context setup (power user path)
- Multi-domain usage with cross-domain context
- Cross-domain pattern recognition
- Creator tools as natural evolution of power use
- Organic sharing / viral loop

---

### Journey 3: The Coach Creator — Creation & Sharing

**Meet Aisha, 31, certified career coach with 12K LinkedIn followers.**

**Opening Scene:** Aisha charges $150/hr for 1:1 career coaching. She's booked solid but capped at 20 clients. She discovers Coach App as a user first.

**Rising Action:** After 2 weeks, she sees the "Create a Coach" option. The creator form slides up with Liquid Glass morphing — elegant and intuitive. She defines: domain (career transitions), tone (warm but direct), methodology (her "3P Framework"). She generates a share link. Total time: 8 minutes.

She posts on LinkedIn: "I built an AI version of my career coaching methodology." 47 people click. 23 start conversations. 8 come back for a second session.

**Climax:** One user reaches out directly: "Your AI coach helped me rewrite my resume positioning in a way that actually landed interviews. I want to work with you 1:1 for the deeper stuff." The AI coaching persona became a funnel to her premium human coaching.

**Resolution:** Aisha shares her coach link in every LinkedIn post. Her AI coach becomes a lead generation tool.

**Capabilities Revealed:**
- Creator form (domain, tone, methodology, personality)
- Share link generation
- User-created coach content in template engine
- Organic discovery through social sharing

---

### Journey 4: The Guidance Seeker — Edge Case (Coaching Boundary)

**Meet James, 26, recent college grad in Chicago.**

**Opening Scene:** James has been using Coach App for 3 weeks for career coaching. The context layer knows his values, situation, and recent conversations.

**Rising Action:** On a bad night, James types: "I don't see the point of anything anymore. Nothing I do matters."

**Climax:** The coach recognizes the shift. The response appears with empathetic tone, and a Liquid Glass container slides in with crisis resources — 988 Suicide & Crisis Lifeline, Crisis Text Line — presented warmly, not clinical. "I hear you, and what you're feeling sounds really heavy. I want to be honest — this is beyond what I can help with as a coaching tool. You deserve to talk to someone trained for exactly this."

**Resolution:** James texts the Crisis Text Line that night. A week later, he comes back to Coach App for career coaching. The coach picks up where they left off — no awkwardness, just continuity.

**Capabilities Revealed:**
- Crisis detection / coaching boundary recognition
- Crisis resource display (warm, empathetic UI)
- Graceful deflection without abandonment
- Context continuity after sensitive moments

---

### Journey 5: Solo Operator (Sumanth)

**Meet Sumanth, solo developer and operator of Coach App.**

**Opening Scene:** It's launch week. Sumanth checks the monitoring dashboard. 43 new users signed up overnight. API costs are at $38 for the day.

**Rising Action:** He checks metrics: Week 1 retention is at 36% (below target). He digs into session logs — users in "relationships" domain are bouncing after 1 exchange. He opens the domain config and adjusts: warmer tone, more empathetic opening. Deploys in 15 minutes.

He notices API costs spiking for one power user with 47 sessions in 3 days. Makes a note to implement session rate limiting.

**Climax:** At 3-month mark, he runs the Sean Ellis survey. 44% say "very disappointed." PMF signal strong. API costs per user at $2.30 — above target. He optimizes prompt lengths and implements context summarization.

**Resolution:** He invests in growth. Cost per user down to $1.60. The template engine architecture pays off — adding a new domain takes a config change, not a rebuild.

**Capabilities Revealed:**
- Monitoring dashboard (basic metrics visibility)
- Domain config management
- Usage monitoring and cost tracking
- Config-driven domain management

---

### Journey Requirements Summary

| Capability Area | Revealed By Journeys | Priority |
|---|---|---|
| Zero-friction first session | J1, J2 | MVP Core |
| Context prompt + profile setup | J1, J2 | MVP Core |
| Cross-session memory | J1, J2, J4 | MVP Core |
| Pattern recognition across conversations | J1, J2 | MVP Core |
| Cross-domain pattern recognition | J2 | MVP Core |
| Intelligent domain routing | J1, J2 | MVP Core |
| Multiple conversation threads | J2 | MVP (cuttable) |
| Creator form + share link | J3 | MVP Core |
| Coach-specific sharing | J3 | MVP Core |
| Crisis detection + resource display | J4 | MVP Core |
| Content safety layer | J4 | MVP Core |
| Push notifications / proactive check-ins | J1 | MVP (cuttable) |
| Voice input | -- | MVP (cuttable) |
| Monitoring dashboard | J5 | MVP Core |
| Domain config management | J5 | MVP Core |
| Usage + cost tracking | J5 | MVP Core |
| Rate limiting | J5 | MVP Core |
| Liquid Glass UI excellence | J1-J4 | MVP Core |

## Domain-Specific Requirements

### Coaching-Not-Therapy Boundary

- **Disclaimers:** "Coach App provides AI coaching, not therapy or mental health treatment" — visible in onboarding and terms of service
- **Crisis detection:** Active monitoring for self-harm, suicidal ideation, abuse indicators. When triggered: empathetic acknowledgment, crisis resource display (988 Lifeline, Crisis Text Line), graceful deflection
- **Scope guardrails:** AI must not diagnose, prescribe, or claim clinical expertise
- **Liability protection:** Terms of service explicitly disclaim therapeutic relationship

### Personal Data Privacy

- **Architecture:** Server-stored with strong encryption, device sync via iCloud Keychain for credentials
- **Encryption:** AES-256 at rest, TLS 1.3 in transit
- **User control:** Users can view, edit, and delete their entire context profile and conversation history
- **LLM provider policy:** Providers with zero-retention API policies (OpenAI and Anthropic APIs)
- **Data minimization:** Only store what improves coaching quality
- **No third-party sharing:** Personal context data never shared with advertisers or analytics platforms
- **App Store Privacy Nutrition Labels:** Accurate declaration of all data collected

### AI Safety

- **Hallucination prevention:** Coaching engine must never fabricate facts about user's context
- **Prompt injection hardening:** System prompts protected against jailbreak attempts
- **Content safety:** No harmful advice, no enabling self-destructive behavior
- **Creator content moderation:** Manual review at MVP scale
- **Tone guardrails:** Never dismissive, sarcastic, or harsh

### App Store Compliance

- **Apple IAP:** In-app subscriptions use Apple's payment system
- **AI content disclosure:** Visible disclosure that coaching content is AI-generated
- **Account deletion:** In-app account deletion capability (Apple requirement)
- **Privacy nutrition labels:** Accurate declaration of all data collected
- **iOS version support:** iOS 18+ minimum, optimized for iOS 26+ with Liquid Glass

### LLM Provider Dependency

- **Provider abstraction:** Architecture supports swapping LLM providers without rebuild
- **Cost monitoring:** Real-time tracking of API costs per user
- **Rate limit handling:** Queuing or graceful degradation when limits hit
- **Fallback strategy:** Graceful "temporarily unavailable" message if provider has outage

## Platform Requirements

### iOS Native with Progressive Enhancement

Coach App is built as a **native iOS application** using Swift and SwiftUI, with progressive enhancement for iOS 26's Liquid Glass design language.

| Requirement | Decision | Rationale |
|---|---|---|
| **Platform** | iOS only (native) | Maximum quality, optimal performance, Apple ecosystem |
| **iOS minimum version** | iOS 18+ | Broad market reach (~90% of active devices) |
| **iOS recommended version** | iOS 26+ | Full Liquid Glass experience |
| **Language** | Swift 6 | Modern, safe, performant |
| **UI Framework** | SwiftUI | Native iOS design, adaptive across versions |
| **Architecture** | MVVM + Swift Concurrency | Clean separation, async/await for streaming |
| **Design approach** | Progressive enhancement | Premium experience on all supported versions |

### Adaptive Design Strategy

Coach App delivers a premium experience across iOS versions through runtime version detection and adaptive UI:

| iOS Version | Design Treatment | Visual System |
|-------------|------------------|---------------|
| **iOS 26+** | Full Liquid Glass | Lensing, morphing, adaptive materials, `.glassEffect()` |
| **iOS 18-25** | Warm Modern | `.ultraThinMaterial`, subtle blurs, warm gradients, soft shadows |

**Key Principles:**
- Both experiences are **intentionally designed** — iOS 18-25 is not a "degraded" experience
- **Information architecture stays identical** — same screens, same flows, same functionality
- **Interaction patterns stay identical** — same gestures, same navigation, same affordances
- Only **visual rendering adapts** based on iOS version
- Users on iOS 18-25 should report **equivalent satisfaction** to iOS 26+ users

**Implementation Pattern:**
```swift
if #available(iOS 26, *) {
    content.glassEffect()  // Liquid Glass
} else {
    content.background(.ultraThinMaterial)  // Warm Modern fallback
}
```

### Liquid Glass Design Requirements (iOS 26+)

iOS 26's Liquid Glass is the most significant Apple design evolution since iOS 7. Coach App fully embraces this design language on supported devices:

**Core Principles:**
- **Navigation layer only:** Liquid Glass applies to controls floating above content — never to content itself
- **Content leads:** Coaching conversation content is always primary; controls float elegantly above
- **Adaptive materials:** Glass continuously adapts to background content, light conditions, and interactions
- **No glass on glass:** Never stack Liquid Glass elements; use GlassEffectContainer for grouping

**Visual Characteristics:**
- **Lensing:** Real-time light bending creating depth and focus
- **Fluidity:** Gel-like flexibility with instant responsiveness
- **Morphing:** Dynamic transformation between control states
- **Warm tones:** Earth tones and soft accents — not sterile whites or tech blues

**Implementation Requirements (iOS 26+):**
- Use `.glassEffect()` modifier for navigation elements (toolbars, buttons, sheets)
- Use `GlassEffectContainer` for grouping multiple glass elements
- Use `.interactive()` for buttons and tappable elements
- Apply `.tint()` sparingly for call-to-action elements
- Respect accessibility settings (reduced transparency, increased contrast, reduced motion)
- Light mode default; dark mode uses warm dark tones

### Warm Modern Design Requirements (iOS 18-25)

For users on iOS 18-25, Coach App delivers a complete, polished "Warm Modern" experience:

**Core Principles:**
- **Same warmth, different materials:** Earth tones, soft accents, approachable aesthetic
- **Standard SwiftUI materials:** `.ultraThinMaterial`, `.regularMaterial` for depth
- **Subtle visual hierarchy:** Soft shadows, gentle gradients, rounded corners
- **Familiar iOS patterns:** Users feel at home with standard iOS conventions

**Implementation Requirements (iOS 18-25):**
- Use `.background(.ultraThinMaterial)` for navigation elements
- Use subtle shadows and rounded corners for depth
- Apply warm color palette consistently
- Maintain same spacing, typography, and layout as iOS 26 version
- Respect all accessibility settings

### Device Features

| Feature | Implementation | MVP Status |
|---|---|---|
| **Sign in with Apple** | Native Apple authentication | MVP Core |
| **Face ID / Touch ID** | Biometric unlock via LocalAuthentication | MVP Core |
| **Push Notifications** | APNs (Apple Push Notification service) | MVP (cuttable) |
| **Microphone** | Speech-to-text for voice input | MVP (cuttable) |
| **Haptics** | Subtle feedback for key interactions | MVP (cuttable) |
| **iCloud Keychain** | Secure credential storage | MVP Core |
| **Live Activities** | Session status on lock screen | Post-MVP |
| **Interactive Widgets** | Quick coaching access | Post-MVP |

### Offline Mode

- **Available offline:** Read past conversations, view context profile, browse conversation history
- **Unavailable offline:** New coaching conversations (requires LLM API)
- **UX:** Warm Liquid Glass banner: "You're offline right now. Your past conversations are here — new coaching needs a connection."
- **Sync:** Automatic sync when connection restored via Swift Concurrency

### Push Strategy

- **Proactive check-ins:** Context-aware nudges between sessions
- **Re-engagement:** If user hasn't returned in 3+ days, gentle nudge based on last conversation
- **Permission flow:** Request push permission after first completed session (not on first launch)
- **Frequency cap:** Maximum 1 push per day

### Real-Time Streaming

- **LLM response delivery:** Token-by-token streaming via Server-Sent Events
- **UX:** Text appears progressively with 50-100ms buffer for coaching-paced rendering (not jittery)
- **Typing indicator:** Show coaching "thinking" state before first token
- **Error handling:** If stream interrupted, display partial response with retry option

### Accessibility

- **Standard:** WCAG 2.1 AA compliance + iOS Accessibility APIs
- **VoiceOver:** Full VoiceOver support with semantic descriptions
- **Dynamic Type:** Support all accessibility text sizes
- **Reduced Motion:** Respect system preference, tone down Liquid Glass animations
- **Reduced Transparency:** System automatically adjusts glass for clarity
- **Increased Contrast:** System uses stark colors and borders when enabled

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Full Experience MVP — ship the complete coaching experience in V1, iOS only.

**Resource:** Solo developer. Native iOS with Liquid Glass design. Swift/SwiftUI.

### MVP Feature Set (Phase 1 — V1)

**Core Coaching Experience:**
- Single chat interface with intelligent domain routing
- Personal context layer (values, goals, situation, progressive extraction)
- Conversation history with cross-session memory
- Pattern recognition across conversations
- Cross-domain pattern recognition
- 7 coaching domains (life, career, relationships, mindset, creativity, fitness, leadership)
- Multiple conversation threads
- Real-time token-by-token streaming
- Voice input

**Personal Context & Safety:**
- Context prompt after first session
- Progressive context building through conversation
- Crisis detection + crisis resource display
- Content safety layer
- Coaching-not-therapy disclaimers

**Platform:**
- Native iOS app (Swift/SwiftUI)
- iOS 26 Liquid Glass design throughout
- Offline read access with warm offline banner

**Authentication & Security:**
- Sign in with Apple
- Face ID / Touch ID biometric unlock
- AES-256 encryption at rest, TLS 1.3 in transit
- User data control (view, edit, delete everything)

**Creator Tools:**
- Creator form (domain, tone, methodology, personality)
- Share link generation with deep linking

**Payments:**
- Free trial (enough sessions to reach aha moment)
- Paid subscription $5-10/month via Apple IAP

**Operator Tools:**
- Monitoring dashboard (key metrics visibility)
- Usage + cost tracking
- Domain configuration management
- Rate limiting

### Post-MVP Features

**Phase 2 (Growth) — Gate: 40%+ Sean Ellis at 500 users:**
- Enhanced creator tools
- Creator analytics dashboard
- Proactive coaching intelligence
- Advanced voice (full voice conversations)
- Live Activities for session status
- Interactive widgets

**Phase 3 (Expansion) — Gate: 10K+ users, positive unit economics:**
- Creator monetization
- Community features
- Discovery engine
- Apple Watch companion app
- iPad optimization

### Prioritized Cut List (Safety Net)

If timeline or complexity pressure hits, cut in this order:

1. Voice input (text-only is fine for launch)
2. Push notifications (pull-based engagement works initially)
3. Offline read access (online-only is acceptable)
4. Multiple threads (single conversation thread is simpler)
5. Domains 6-7: fitness + leadership (5 domains is still strong)
6. Haptic feedback
7. **Protect at all costs:** Single chat + personal context layer + domain routing + streaming + crisis detection + creator tools + sharing + monitoring + auth + payments + Liquid Glass design

## Functional Requirements

The following 47 functional requirements define the complete capability contract for Coach App. Every feature must trace back to these requirements.

### Coaching Conversation

- **FR1:** Users can start a coaching conversation immediately without selecting a category, coach, or completing onboarding
- **FR2:** Users can send text messages and receive AI coaching responses via real-time token-by-token streaming
- **FR3:** Users can use voice input as an alternative to typing text messages
- **FR4:** Users can create and manage multiple conversation threads for different topics
- **FR5:** Users can view their complete conversation history across all sessions
- **FR6:** The system can detect the coaching domain from conversation content and route to the appropriate domain expertise invisibly
- **FR7:** The system can reference previous conversations within the current coaching response
- **FR8:** The system can identify recurring patterns across a user's conversations and surface them as insights
- **FR9:** The system can synthesize patterns across different coaching domains for the same user (cross-domain pattern recognition)

### Personal Context

- **FR10:** Users can add personal values, goals, and life situation to their context profile
- **FR11:** Users are prompted to set up their context profile after their first completed session
- **FR12:** The system can progressively extract context from conversations without requiring explicit user input
- **FR13:** The system can inject stored context (values, goals, situation, conversation history) into every coaching response
- **FR14:** Users can view, edit, and delete any part of their context profile
- **FR15:** Users can delete individual conversations or their entire conversation history

### Coaching Safety

- **FR16:** The system can detect crisis indicators (self-harm, suicidal ideation, abuse) in user messages
- **FR17:** The system can display crisis resources (988 Suicide & Crisis Lifeline, Crisis Text Line) when crisis indicators are detected
- **FR18:** The system can gracefully redirect from clinical topics to coaching scope without abandoning the user
- **FR19:** The system displays coaching disclaimers ("AI coaching, not therapy") during onboarding and in terms of service
- **FR20:** The system enforces tone guardrails — never dismissive, sarcastic, or harsh regardless of user behavior
- **FR21:** The system prevents coaching responses that diagnose, prescribe, or claim clinical expertise
- **FR22:** The system can maintain context continuity after a crisis episode when the user returns to coaching

### Creator Tools

- **FR23:** Users can create a coaching persona by defining domain, tone, methodology, and personality
- **FR24:** Users can generate a unique shareable link for their created coaching persona
- **FR25:** Users can share a link to a specific coaching persona they created or love
- **FR26:** Recipients of a share link can start a coaching session with that specific persona via iOS deep linking

### Account & Authentication

- **FR27:** Users can sign up and log in with Sign in with Apple
- **FR28:** Users can unlock the app using biometric authentication (Face ID / Touch ID)
- **FR29:** Users can delete their account and all associated data from within the app
- **FR30:** Users can access past conversations and their context profile while offline
- **FR31:** Users see a clear warning that new coaching conversations require an internet connection when offline
- **FR32:** User data syncs automatically when internet connection is restored

### Payments & Subscription

- **FR33:** Users can experience a free trial period without providing payment information
- **FR34:** Users can subscribe to the paid plan after the trial ends
- **FR35:** Users can manage their subscription (view status, cancel) from within the app
- **FR36:** Payments are completed through Apple In-App Purchase

### Notifications & Engagement

- **FR37:** Users receive proactive push notifications with context-aware check-ins between sessions
- **FR38:** Users can control push notification preferences (frequency, enable/disable)
- **FR39:** The system requests push notification permission after the first completed session, not on first launch
- **FR40:** Push notifications are delivered via APNs

### Operator Management

- **FR41:** The operator can view key product metrics on a monitoring dashboard (retention, engagement, user counts, costs)
- **FR42:** The operator can track API costs per user in real-time
- **FR43:** The operator can modify coaching domain configurations (tone, methodology, personality) without code changes
- **FR44:** The operator can add new coaching domains through configuration files, not code deployment
- **FR45:** The system enforces rate limiting to prevent abuse and cost overruns
- **FR46:** The operator can review user-created coaching personas for content safety

### App Store & Discovery

- **FR47:** The app is available on the iOS App Store with full App Store compliance

## Non-Functional Requirements

The following 36 non-functional requirements define how well the system must perform.

### Performance

- **NFR1:** Chat responses begin streaming within 500ms of user message (time to first token, P95)
- **NFR2:** User context profile and conversation history load within 200ms
- **NFR3:** Domain routing classification completes within 100ms (invisible to user)
- **NFR4:** iOS app reaches interactive state within 1.5 seconds of launch
- **NFR5:** Streaming text renders smoothly at 30+ tokens/second without UI jank
- **NFR6:** UI animations maintain 60fps on both iOS 26 (Liquid Glass) and iOS 18-25 (Warm Modern)
- **NFR7:** App bundle size remains under 30MB
- **NFR8:** Active session memory usage stays under 100MB
- **NFR9:** Offline conversation history loads within 500ms from local cache

### Security

- **NFR10:** All user data encrypted at rest using AES-256
- **NFR11:** All data in transit encrypted using TLS 1.3
- **NFR12:** Authentication tokens implement rotation with secure expiration policies
- **NFR13:** System prompts are hardened against prompt injection from user input and creator-defined content
- **NFR14:** Personal context data is never included in application logs or error reports
- **NFR15:** LLM provider API keys are stored in secure environment variables, never in client code
- **NFR16:** User account deletion permanently removes all associated data within 30 days
- **NFR17:** Session tokens are invalidated on logout
- **NFR18:** Rate limiting enforced per-user to prevent abuse (configurable threshold)

### Scalability

- **NFR19:** System supports 500 concurrent active users at launch with no performance degradation
- **NFR20:** Architecture supports 10x user growth (5,000 concurrent) with infrastructure scaling only
- **NFR21:** LLM API costs scale linearly with users
- **NFR22:** Context storage scales efficiently for users with 100+ conversation sessions
- **NFR23:** Template engine supports adding new coaching domains without performance impact
- **NFR24:** Database design supports efficient queries across growing conversation history

### Accessibility

- **NFR25:** All user-facing interfaces comply with WCAG 2.1 AA standards
- **NFR26:** Full VoiceOver support with semantic accessibility labels
- **NFR27:** All interactive elements have appropriate accessibility traits
- **NFR28:** Color contrast ratios meet AA minimum (4.5:1 for normal text)
- **NFR29:** Text supports Dynamic Type at all accessibility sizes
- **NFR30:** Animations and Liquid Glass effects respect reduced motion preference

### Integration

- **NFR31:** LLM integration layer is provider-agnostic — supports swapping providers without code changes
- **NFR32:** Apple IAP integration handles all subscription lifecycle events (purchase, renewal, cancellation, refund)
- **NFR33:** Push notification delivery achieves 95%+ success rate via APNs
- **NFR34:** All third-party integrations implement retry logic with exponential backoff

### Reliability

- **NFR35:** No user context data is lost under any failure condition (zero data loss for personal context)
- **NFR36:** If LLM provider is unavailable, system displays graceful degradation message within 3 seconds
