---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
date: 2026-01-27
author: Sumanth
---

# Product Brief: Coach App

## Executive Summary

800 million people ask AI for advice every week. None of those conversations remember who they are.

Coach App is personal AI coaching that actually knows you. Add your values, goals, and life context once -- then start talking. The AI remembers your story, adapts to what matters to you, and gives you relevant guidance in under 60 seconds. No browsing, no scheduling, no intake forms. Just open the app, say what's on your mind, and get coaching that feels like it comes from someone who knows you -- because it does.

Behind the scenes, a template coaching engine spans life, career, fitness, creativity, leadership, relationships, and more, routing to the right domain based on what you're talking about. The user never picks a category. Over time, anyone can create their own coaching persona and share it with a link -- but the core promise is simple: open the app, feel understood, get unstuck.

Coach App sits at the intersection of four forces: LLMs now capable of coaching-quality conversation, a generation comfortable with AI that just wants a smart friend who remembers what matters to them, a $5.3B coaching industry locked behind enterprise paywalls, and the total absence of any AI product that persistently knows who you are across conversations.

---

## Core Vision

### Problem Statement

People want guidance -- and they're already asking AI for it. 49% of ChatGPT usage is advice-seeking. Reddit posts about "AI therapy" are up 400%. But every one of those conversations starts from zero. The AI doesn't know your values, your goals, your situation, or what you talked about last week. It gives generic advice to a stranger, every single time.

Traditional coaching solves the personalization problem but costs $3,000-$5,000/year and is gated behind enterprise contracts. Purpose-built AI coaching apps like Rocky.ai and Purpose are emerging but feel scripted, lack depth, and still don't truly know you. Platforms like Character.ai prove people want AI personas -- but they're entertainment-first with weak memory and no coaching methodology.

The result: millions of people are reaching for coaching and finding either something too expensive, too generic, or too forgetful.

### Problem Impact

- **For people seeking guidance:** The choice is between a $200/hr human coach, a generic AI that forgets you exist, or a domain-locked wellness app (Headspace for meditation, Noom for weight loss) that doesn't address the full picture. There's nowhere to go at 11pm when your manager's feedback stings and you need someone who gets your situation.
- **For coaches and creators:** 122,974 coach practitioners worldwide are capped at 1:1 delivery. Existing AI cloning tools (Delphi.ai, Coachvox) cost $99/month and only serve established experts. There's no simple way for a knowledgeable person to encode their approach and share it.
- **For the broader market:** A $5.34B coaching industry growing at 17% CAGR is overwhelmingly enterprise-focused. The consumer AI coaching segment has no clear winner despite projected growth to $23.5B by 2034.

### Why Existing Solutions Fall Short

| Category | Examples | Core Limitation |
|---|---|---|
| **Enterprise coaching** | BetterUp, CoachHub | $3K-$5K/year, enterprise-only, scheduled sessions |
| **AI coaching apps** | Rocky.ai, Purpose, Saner.AI | Scripted, limited personalization, no persistent context |
| **Generic AI assistants** | ChatGPT, Claude, Gemini | No coaching structure, forgets you every session |
| **AI persona platforms** | Character.ai, Custom GPTs, Poe | Entertainment-focused, weak memory, no methodology |
| **Coach cloning tools** | Delphi.ai, Coachvox | Expert-only, $99/month, no consumer access |
| **Wellness apps** | Headspace, Calm, Noom | Domain-locked, not conversational, not personalized |

The universal complaint across all platforms: **"It doesn't know me."**

### Proposed Solution

Coach App is a clean, minimal app (iOS + web) built around one idea: **AI coaching that remembers who you are.**

1. **Start talking immediately** -- open the app, say what's on your mind. No category selection, no coach browsing, no intake forms. Just a conversation.
2. **Personal context is the core** -- your values, goals, situation, and conversation history persist across every session. The AI learns you progressively through conversation, not upfront questionnaires. The more you talk, the better it knows you.
3. **Intelligent routing, invisible to the user** -- behind the scenes, a template coaching engine spans multiple domains (career, relationships, mindset, fitness, creativity, leadership). The app detects what you're talking about and brings the right coaching expertise. You see one coach. It's great at everything because it knows you.
4. **Anyone can create and share** -- simple creator tools let users build a coaching persona (domain, tone, methodology) and share it with a link. Not a marketplace -- a share button. The best coaches spread organically.
5. **Progressive depth** -- first session is valuable. Tenth session is transformative. The context layer deepens over time, creating a coaching relationship that feels real.

### Key Differentiators

| Differentiator | What It Means | Why It Wins |
|---|---|---|
| **Persistent personal context** | Your values, goals, and story persist across every session. The AI knows you. | The #1 unmet need in every competitor. This is the moat -- users won't leave because the AI knows them. |
| **Zero-friction start** | Open, talk, get helped. No setup, no browsing, no categories. | Every competitor adds friction. Coach App removes it. |
| **Invisible intelligence** | One coaching interface, multiple domains routed behind the scenes. | User sees simplicity. Engine delivers expertise. Solo dev builds configs, not products. |
| **Progressive context building** | No intake forms. Context builds through conversation over time. | Mirrors how real coaching works. First session is good. Tenth is great. |
| **Creator tools as a feature, not the product** | Anyone can make a coach and share a link. Discovery through sharing. | Viral growth without marketplace infrastructure. Delightful surprise, not the headline. |
| **"AI that remembers who you are"** | Six-word positioning that captures the entire gap in the market. | Clear, memorable, defensible. No competitor can claim this today. |

---

## Target Users

### Primary Users

#### Persona 1: The Guidance Seeker

**Profile:** Ages 22-40, unified by being at a crossroads -- not by demographics. Could be a 24-year-old navigating their first job, a 32-year-old questioning their career direction, or a 38-year-old rebalancing after a life change. The common thread: they need someone to help them think through something, and they need it now.

**Triggers:** They open Coach App when:
- A specific moment hits -- tough feedback from a manager, an argument with a partner, anxiety about a big decision
- A recurring feeling surfaces -- "I'm stuck and I don't know why," a sense of drifting without direction
- A life transition arrives -- new job, breakup, move, promotion, becoming a parent

**Current Workarounds:**
- Asking ChatGPT or Claude for advice -- and getting generic responses that forget them by the next session
- Googling, reading articles, listening to podcasts -- consuming information without ever applying it personally

**What Makes Them Stay:**
- **Memory:** The AI remembers their last conversation and picks up where they left off
- **Challenge:** It pushes back when they're making excuses -- not a yes-machine
- **Pattern recognition:** It connects dots they didn't see -- "Last month you said X, and now you're doing Y again"
- **Safety:** Nonjudgmental, available at 2am, no shame. A space where they can be honest

**Success looks like:** They stop sitting with problems. They have a place to go that knows them, challenges them, and helps them move forward -- not next Thursday at a scheduled appointment, but right now.

---

#### Persona 2: The Self-Improvement Enthusiast

**Profile:** A subset of Guidance Seekers who are proactive rather than reactive. They've read the books, done the courses, listened to the podcasts. They're not short on information -- they're short on *application.* They don't need another article about communication skills. They need someone who knows their specific situation and helps them apply what they know to their actual life.

**Key Difference from Guidance Seekers:**
- They use Coach App regularly, not just in crisis moments
- They're content-saturated -- they want a conversation that applies knowledge to *their* context, not more generic advice
- They explore different coaching domains deliberately -- career coaching one week, relationship coaching the next, creative blocks after that

**Success looks like:** The gap between "I know what to do" and "I'm actually doing it" closes. The AI becomes their accountability partner and thinking tool, not another content source.

---

### Secondary Users

#### Persona 3: The Coach Creator

**Profile:** A diverse group united by wanting to encode expertise into a shareable AI coaching experience:
- **Certified coaches** who want to scale beyond 1:1 sessions without diluting their methodology
- **Knowledgeable non-certified people** -- managers, mentors, niche experts who coach informally
- **Power users** of Coach App who think "I could build a better coach for X"
- **Content creators** (podcasters, bloggers, influencers) who want to offer coaching as a product

**Path to Creation:**
- **Organic (primary):** Start as a Guidance Seeker or Enthusiast, love the product, realize they could create a coach for their niche, build one, share the link
- **Direct (later):** Discover Coach App because they've heard about creator tools, sign up specifically to build

**Phase:** Basic creator tools ship from day one -- a form with domain, tone, methodology, and a share link. Not a marketplace. Just creation and sharing. This serves as a growth engine even before it becomes a full-featured creator platform.

**Success looks like:** They build a coach in under 10 minutes, share the link, and see people using it. For certified coaches, the AI version becomes a funnel to their premium human coaching.

---

### Explicit Exclusions

- **Enterprise/B2B teams** -- no admin dashboards, no team management, no SSO. This is a consumer product.
- **Clinical mental health crisis** -- Coach App is not therapy. Clear disclaimers and crisis resource redirects where appropriate.
- **Minors under 18** -- age-gated. Coaching AI for adults only.

---

### User Journey

#### The Guidance Seeker's Journey

**Discovery:**
A friend texts them a link: "try this, it actually remembers you." Or they see a screenshot on social media of a coaching conversation that resonates. Word of mouth and social sharing are the primary growth drivers. App Store search ("AI coach," "life advice app") is secondary.

**First Session:**
They open the app and start talking. No onboarding screens, no category selection, no account setup before value. They type what's on their mind and get a response that feels relevant. After the conversation ends, a gentle prompt: *"Want me to remember what matters to you?"* They add 2-3 values or goals. Context layer begins.

**Aha Moment:**
Second session -- the AI references something from the first conversation. First week -- they notice the coaching getting sharper as context builds. But the real emotional hook is a specific moment: the AI says *"Last time you mentioned feeling overlooked at work. This sounds like the same pattern -- what do you think is driving it?"* They feel seen. That's the moment they're hooked.

**Retention:**
Three forces work together:
1. **Context moat** -- "This AI knows me. Starting over elsewhere would mean losing everything it's learned."
2. **Genuine utility** -- it helps them make better decisions, see patterns, take action
3. **Habit formation** -- becomes part of their routine, whether that's a morning check-in, evening reflection, or crisis tool they reach for when they're stuck

#### The Self-Improvement Enthusiast's Journey

Follows the same path but moves faster and goes deeper. They set up their context profile proactively. They use the app regularly, not just when triggered. They deliberately explore different coaching domains -- career one week, relationships the next, creative blocks after that. They're the first to discover creator tools and share coaches with friends.

#### The Coach Creator's Journey

Starts as a user. Falls in love with the coaching experience. Has a moment of "I know a lot about X -- I could build a coach for that." Opens the creator tools, defines a domain, tone, and methodology, and shares the link. Watches people start using it. For certified coaches, this becomes a funnel: the AI version handles the everyday questions, and users who want deeper support book paid human sessions.

---

## Success Metrics

### User Success Metrics

**Behavioral Indicators (users are getting value when...):**

| Metric | What It Measures | Target |
|---|---|---|
| **Session return rate** | Users come back within 7 days for another conversation | 50%+ of users return within first week |
| **Context depth** | Users add values, goals, or life context to their profile | 60%+ of returning users set up context |
| **Session engagement** | Conversations go beyond 3 exchanges (not bouncing) | 70%+ of sessions reach 3+ exchanges |
| **Aha moment rate** | Users reach session 3+, where pattern recognition and context depth kick in | 30%+ of new users reach session 3 within first 14 days |

**"This is Working" Moments:**
- The AI references something from a previous conversation and the user feels *seen* -- this is the emotional conversion point
- The user comes back voluntarily without a trigger event -- coaching is becoming a habit, not just a crisis tool

### Business Objectives

**3-Month Goals (Validation Phase):**

| Objective | Target | Why It Matters |
|---|---|---|
| **Quality user base** | 500 active users with strong retention | Proves the core experience works. Quality over vanity numbers. |
| **Product-market fit signal** | 40%+ of surveyed users say they'd be "very disappointed" if Coach App went away (Sean Ellis test) | The single most reliable early indicator of PMF. If you hit this, keep going. If you don't, iterate. |

**12-Month Goals (Growth Phase):**

| Objective | Target | Why It Matters |
|---|---|---|
| **User growth** | 10,000+ active users | Demonstrates organic growth and word-of-mouth traction |
| **Creator ecosystem** | 100+ user-created coaches shared via links | Validates the creator tools and community-driven growth engine |
| **Brand recognition** | "AI that remembers you" becomes associated with Coach App | Positioning is landing -- users can articulate why Coach App is different |

### Revenue Model

**Premium with free trial.** Users get a free trial period to experience the zero-friction onboarding and feel the personal context layer working. After the trial, paid subscription to continue.

- **Free trial:** First few sessions or 3-7 day window -- enough to reach the aha moment (session 3, where pattern recognition kicks in)
- **Paid tier:** $5-10/month for unlimited coaching, full context features, all coaching domains, and creator tools
- **Why premium from day one:** Establishes Coach App as a valuable tool, not a free chatbot. Filters for users who take coaching seriously. Ensures sustainable API costs from the start.
- **Key design constraint:** Trial must be long enough for users to hit the aha moment (context layer proving value) before the paywall activates.

### Key Performance Indicators

**Dashboard KPIs (track daily/weekly):**

| KPI | What It Measures | Target | Why It Matters |
|---|---|---|---|
| **DAU/MAU ratio** | Engagement health -- what fraction of monthly users come daily | 25%+ | Above 25% = strong engagement. Below 15% = product isn't sticky enough. |
| **Week 1 retention** | Do people come back after their first session | 40%+ | The single most important early metric. Predicts long-term retention. |
| **Context setup rate** | What % of users add values/goals to their profile | 60%+ of returning users | Leading indicator of retention -- users who set up context retain 2x+ better. |
| **Sessions per user per week** | How often active users engage | 2+ sessions/week | Shows the product is becoming part of their routine, not a one-time try. |
| **Share/invite rate** | What % of users share a coach link or invite someone | 10%+ | Viral coefficient driver. Above 10% = organic growth is working. |
| **API cost per user per month** | Unit economics sustainability | <$2/user/month | Must be below subscription price to be sustainable. Track closely as usage scales. |

### Strategic Alignment

Every metric connects back to the core vision:

- **Context setup rate** validates "AI that remembers you" -- if users don't set up context, the differentiator isn't landing
- **Week 1 retention** validates "zero-friction start" -- if they don't come back, the first session wasn't compelling enough
- **Sessions per user** validates "progressive depth" -- if they only use it once, the deepening experience isn't working
- **Share rate** validates "social sharing as growth" -- if they don't share, the viral loop is broken
- **Sean Ellis test** validates everything -- if 40%+ would be "very disappointed," the product matters

---

## MVP Scope

### Core Features (Must Ship)

**The Conversation Experience:**
- Single chat interface -- one screen, open the app, start talking
- Coaching engine with intelligent domain routing -- detects what the user is talking about, routes to the right coaching expertise. User sees one coach.
- Conversation history -- persists across sessions. AI can reference past conversations, patterns, and breakthroughs.
- Multiple conversation threads -- separate threads for different topics, with context maintained across all.

**The Personal Context Layer:**
- Profile setup -- values, goals, life situation. "Want me to remember what matters to you?" prompt after first session.
- Progressive context extraction -- AI learns about the user from conversations, not just explicit profile input.
- Context injection -- every coaching response is informed by the user's stored values, goals, situation, and conversation history.

**Coaching Domains (7 at launch):**
1. Life coaching -- general guidance, decisions, direction
2. Career coaching -- work challenges, growth, transitions
3. Relationships -- communication, conflict, connection
4. Mindset -- limiting beliefs, confidence, mental frameworks
5. Creativity -- creative blocks, projects, artistic direction
6. Fitness -- health goals, habits, accountability
7. Leadership -- management skills, team dynamics, influence

All powered by one template engine with domain-specific configurations.

**Platform:**
- iOS app + web app from day one
- Shared backend, platform-specific frontends
- Feature parity across both platforms

**Account & Payment:**
- Authentication (email + social login)
- Free trial (enough sessions to reach the aha moment -- session 3+)
- Paid subscription ($5-10/month) via Stripe (web) and App Store (iOS)

**Creator Tools:**
- Basic creator form: define domain, tone, methodology, personality
- Share link generation -- anyone can send their coach to others
- Coach-specific sharing -- users share a link to a specific coaching persona they created or love

**Engagement Features:**
- Push notifications -- proactive check-ins between sessions ("How did that conversation with your manager go?")
- Voice input -- audio conversations as an alternative to text
- Share/invite mechanism -- coach-specific links for organic growth

### Out of Scope for MVP

| Feature | Why It's Deferred |
|---|---|
| Marketplace / browse / discovery UI | Discovery happens through sharing and recommendations, not browsing. Phase 2+. |
| Analytics dashboard for creators | Creators need users first. Analytics come when there's data to show. Phase 2. |
| Social features (following, liking, commenting) | Community features need a community. Build the user base first. Phase 3. |
| Creator monetization / revenue sharing | Creators need traction before monetization matters. Phase 3. |
| Admin / moderation tools | Manual review is fine at small scale. Build tooling when volume demands it. |
| Localization / multi-language | English first. Expand languages when international demand is proven. |

### MVP Success Criteria

The MVP succeeds when:

| Gate | Criteria | Evidence |
|---|---|---|
| **Core experience works** | Users who set up context retain 2x better than those who don't | Analytics show correlation between context depth and retention |
| **Product-market fit** | 40%+ of users say "very disappointed" if Coach App went away (Sean Ellis test) | Survey data at 500 active users |
| **Organic growth** | 10%+ of users share a coach link or invite someone | Share rate tracking |
| **Sustainable unit economics** | API cost per user <$2/month | Cost monitoring vs. subscription revenue |
| **Retention holds** | 40%+ week 1 retention | Cohort analysis |

**Decision point:** If PMF signal is strong at 500 users, invest in growth. If not, iterate on the core experience before scaling.

### Scope Risk Note

This MVP is ambitious for a solo developer: dual platform (iOS + web), 7 coaching domains, push notifications, voice input, multiple threads, and creator tools. If timeline pressure hits, the recommended cut order is:

1. **Cut first:** Voice input (text-only is fine for launch)
2. **Cut second:** Push notifications (pull-based engagement works initially)
3. **Cut third:** Multiple threads (single conversation thread is simpler)
4. **Cut fourth:** Reduce to 5 domains (drop fitness + leadership initially)
5. **Protect at all costs:** Single chat + personal context layer + domain routing + creator tools + sharing

The personal context layer and zero-friction chat experience are non-negotiable. Everything else can be phased if needed.

### Future Vision

**Phase 2 (Post-MVP, once PMF is validated):**
- Enhanced creator tools -- richer methodology definition, conversation flow design
- Creator analytics -- see how many people use your coach, engagement metrics
- Proactive coaching intelligence -- smarter check-ins based on context patterns
- Advanced voice features -- full voice conversations, not just input

**Phase 3 (Growth phase, 10K+ users):**
- Creator monetization -- creators charge for premium coaching personas, revenue sharing model
- Community features -- reviews, ratings, "coaches my friends use," recommendations
- Discovery engine -- algorithmic matching based on user context and coaching needs

**Long-term Vision:**
- "Spotify of coaching" -- a platform where the best coaching experiences surface organically through usage and community curation
- The personal context layer becomes the most valuable thing on a user's phone -- an AI that truly knows them, across every domain of their life
- Coach App becomes the default answer to "I need someone to talk to about this"
