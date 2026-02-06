---
stepsCompleted: [1, 2, 3, 4]
status: complete
inputDocuments:
  - 'prd.md'
  - 'architecture.md'
totalEpics: 9
totalStories: 53
frCoverage: 47/47
pivotNote: 'Native iOS with progressive enhancement: iOS 18+ minimum, Liquid Glass on iOS 26+, Warm Modern fallback'
---

# Coach App - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Coach App as a **native iOS application** built with Swift and SwiftUI, with progressive enhancement supporting iOS 18+ (Warm Modern design) and iOS 26+ (Liquid Glass design).

## Requirements Inventory

### Functional Requirements

**Coaching Conversation (FR1-FR9)**
- FR1: Users can start a coaching conversation immediately without selecting a category, coach, or completing onboarding
- FR2: Users can send text messages and receive AI coaching responses via real-time token-by-token streaming
- FR3: Users can use voice input as an alternative to typing text messages
- FR4: Users can create and manage multiple conversation threads for different topics
- FR5: Users can view their complete conversation history across all sessions
- FR6: The system can detect the coaching domain from conversation content and route to the appropriate domain expertise invisibly
- FR7: The system can reference previous conversations within the current coaching response
- FR8: The system can identify recurring patterns across a user's conversations and surface them as insights
- FR9: The system can synthesize patterns across different coaching domains for the same user (cross-domain pattern recognition)

**Personal Context (FR10-FR15)**
- FR10: Users can add personal values, goals, and life situation to their context profile
- FR11: Users are prompted to set up their context profile after their first completed session
- FR12: The system can progressively extract context from conversations without requiring explicit user input
- FR13: The system can inject stored context (values, goals, situation, conversation history) into every coaching response
- FR14: Users can view, edit, and delete any part of their context profile
- FR15: Users can delete individual conversations or their entire conversation history

**Coaching Safety (FR16-FR22)**
- FR16: The system can detect crisis indicators (self-harm, suicidal ideation, abuse) in user messages
- FR17: The system can display crisis resources (988 Suicide & Crisis Lifeline, Crisis Text Line) when crisis indicators are detected
- FR18: The system can gracefully redirect from clinical topics to coaching scope without abandoning the user
- FR19: The system displays coaching disclaimers ("AI coaching, not therapy") during onboarding and in terms of service
- FR20: The system enforces tone guardrails — never dismissive, sarcastic, or harsh regardless of user behavior
- FR21: The system prevents coaching responses that diagnose, prescribe, or claim clinical expertise
- FR22: The system can maintain context continuity after a crisis episode when the user returns to coaching

**Creator Tools (FR23-FR26)**
- FR23: Users can create a coaching persona by defining domain, tone, methodology, and personality
- FR24: Users can generate a unique shareable link for their created coaching persona
- FR25: Users can share a link to a specific coaching persona they created or love
- FR26: Recipients of a share link can start a coaching session with that specific persona via iOS deep linking

**Account & Authentication (FR27-FR32)**
- FR27: Users can sign up and log in with Sign in with Apple
- FR28: Users can unlock the app using biometric authentication (Face ID / Touch ID)
- FR29: Users can delete their account and all associated data from within the app
- FR30: Users can access past conversations and their context profile while offline
- FR31: Users see a clear warning that new coaching conversations require an internet connection when offline
- FR32: User data syncs automatically when internet connection is restored

**Payments & Subscription (FR33-FR36)**
- FR33: Users can experience a free trial period without providing payment information
- FR34: Users can subscribe to the paid plan after the trial ends
- FR35: Users can manage their subscription (view status, cancel) from within the app
- FR36: Payments are completed through Apple In-App Purchase

**Notifications & Engagement (FR37-FR40)**
- FR37: Users receive proactive push notifications with context-aware check-ins between sessions
- FR38: Users can control push notification preferences (frequency, enable/disable)
- FR39: The system requests push notification permission after the first completed session, not on first launch
- FR40: Push notifications are delivered via APNs

**Operator Management (FR41-FR46)**
- FR41: The operator can view key product metrics on a monitoring dashboard (retention, engagement, user counts, costs)
- FR42: The operator can track API costs per user in real-time
- FR43: The operator can modify coaching domain configurations (tone, methodology, personality) without code changes
- FR44: The operator can add new coaching domains through configuration files, not code deployment
- FR45: The system enforces rate limiting to prevent abuse and cost overruns
- FR46: The operator can review user-created coaching personas for content safety

**App Store & Discovery (FR47)**
- FR47: The app is available on the iOS App Store with full App Store compliance

### Additional Requirements

**From Architecture:**
- ARCH-1: Project built with Swift 6 + SwiftUI for iOS 18+ (progressive enhancement for iOS 26+)
- ARCH-2: Adaptive design system using `.adaptiveGlass()` modifiers (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25)
- ARCH-3: MVVM + Repository pattern with @Observable ViewModels
- ARCH-4: Backend: Supabase (PostgreSQL, Auth, Edge Functions)
- ARCH-5: Payments: RevenueCat + StoreKit 2
- ARCH-6: Local storage: SwiftData + Keychain
- ARCH-7: Networking: URLSession + SSE for streaming
- ARCH-8: Auth: Sign in with Apple + Supabase Auth sync
- ARCH-9: Edge Functions for LLM orchestration with SSE proxy
- ARCH-10: Data model uses JSONB columns for flexible fields
- ARCH-11: Cross-version testing (iOS 18-25 and iOS 26+)

**From UX/Design:**
- UX-1: Warm color palette (earth tones, soft accents) — consistent across iOS versions
- UX-2: Light mode default; dark mode uses warm dark tones
- UX-3: Streaming text buffer of 50-100ms for coaching-paced rendering
- UX-4: Memory moments receive subtle visual distinction
- UX-5: Pattern insights use distinct visual treatment
- UX-6: Crisis resources presented with warm, empathetic adaptive container
- UX-7: Conversation starters for first session
- UX-8: Context prompt after first session: "Want me to remember what matters to you?"
- UX-9: Empty states with personality
- UX-10: Offline banner: "You're offline right now. Your past conversations are here."
- UX-11: Error messages use first person: "I couldn't connect right now"
- UX-12: Full VoiceOver accessibility
- UX-13: Dynamic Type support at all sizes
- UX-14: Both iOS tiers feel intentionally designed (not degraded)

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 1 | Start conversation without onboarding |
| FR2 | Epic 1 | Send messages with streaming responses |
| FR3 | Epic 1 | Voice input |
| FR4 | Epic 3 | Multiple conversation threads |
| FR5 | Epic 3 | View conversation history |
| FR6 | Epic 3 | Invisible domain routing |
| FR7 | Epic 3 | Reference previous conversations |
| FR8 | Epic 3 | Pattern recognition |
| FR9 | Epic 3 | Cross-domain pattern synthesis |
| FR10 | Epic 2 | Add values, goals, situation |
| FR11 | Epic 2 | Context prompt after first session |
| FR12 | Epic 2 | Progressive context extraction |
| FR13 | Epic 2 | Context injection into responses |
| FR14 | Epic 2 | View/edit/delete context profile |
| FR15 | Epic 2 | Delete conversations |
| FR16 | Epic 4 | Crisis detection |
| FR17 | Epic 4 | Crisis resource display |
| FR18 | Epic 4 | Graceful clinical redirection |
| FR19 | Epic 4 | Coaching disclaimers |
| FR20 | Epic 4 | Tone guardrails |
| FR21 | Epic 4 | No diagnose/prescribe responses |
| FR22 | Epic 4 | Context continuity after crisis |
| FR23 | Epic 5 | Create coaching persona |
| FR24 | Epic 5 | Generate share link |
| FR25 | Epic 5 | Share persona link |
| FR26 | Epic 5 | Deep linking for shared personas |
| FR27 | Epic 1 | Sign in with Apple |
| FR28 | Epic 6 | Biometric unlock |
| FR29 | Epic 6 | Account deletion |
| FR30 | Epic 7 | Offline read access |
| FR31 | Epic 7 | Offline warning |
| FR32 | Epic 7 | Auto-sync on reconnect |
| FR33 | Epic 6 | Free trial |
| FR34 | Epic 6 | Subscribe to paid plan |
| FR35 | Epic 6 | Manage subscription |
| FR36 | Epic 6 | Apple IAP |
| FR37 | Epic 8 | Proactive push notifications |
| FR38 | Epic 8 | Notification preferences |
| FR39 | Epic 8 | Permission request timing |
| FR40 | Epic 8 | APNs delivery |
| FR41 | Epic 9 | Monitoring dashboard |
| FR42 | Epic 9 | Per-user cost tracking |
| FR43 | Epic 9 | Domain config management |
| FR44 | Epic 9 | Add domains via config |
| FR45 | Epic 9 | Rate limiting |
| FR46 | Epic 9 | Persona safety review |
| FR47 | Epic 9 | App Store compliance |

## Epic List

### Epic 1: Project Foundation & Core Chat Experience
Users can open the app and have a streaming AI coaching conversation.

**What gets delivered:**
- Xcode project with iOS 18+ deployment target, Swift 6, SwiftUI (ARCH-1)
- Adaptive design system with runtime version detection (ARCH-2)
- Supabase setup (database, auth, Edge Functions) (ARCH-4)
- Sign in with Apple authentication (FR27, ARCH-8)
- Core chat UI with adaptive design (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25) (FR1, FR2)
- Streaming text with 50-100ms buffering (UX-3)
- Warm visual design foundation (UX-1, UX-2)
- Voice input (FR3)

**FRs covered:** FR1, FR2, FR3, FR27
**Stories:** 9

---

### Epic 2: Personal Context & Memory
Users experience coaching that remembers who they are.

**What gets delivered:**
- Context profile data model and SwiftData storage (FR10)
- Context setup prompt after first session (FR11, UX-8)
- Progressive context extraction (FR12)
- Context injection into coaching responses (FR13)
- Profile viewing, editing, and deletion (FR14, FR15)
- Memory moment visual treatment (UX-4)

**FRs covered:** FR10, FR11, FR12, FR13, FR14, FR15
**Stories:** 6

---

### Epic 3: Intelligent Domain Routing & Pattern Recognition
Users receive expert coaching in the right domain with pattern insights.

**What gets delivered:**
- Invisible domain routing (FR6)
- 7 coaching domain configurations
- Cross-session memory references (FR7)
- Pattern recognition (FR8)
- Cross-domain pattern synthesis (FR9, UX-5)
- Multiple conversation threads (FR4)
- Conversation history view (FR5)

**FRs covered:** FR4, FR5, FR6, FR7, FR8, FR9
**Stories:** 7

---

### Epic 4: Coaching Safety & Crisis Handling
Users are protected with appropriate boundaries.

**What gets delivered:**
- Crisis detection pipeline (FR16)
- Crisis resource Liquid Glass sheet (FR17, UX-6)
- Graceful redirection (FR18)
- Coaching disclaimers (FR19)
- Tone guardrails (FR20, FR21)
- Context continuity after crisis (FR22)

**FRs covered:** FR16, FR17, FR18, FR19, FR20, FR21, FR22
**Stories:** 5

---

### Epic 5: Creator Tools & Sharing
Users can create and share custom coaching personas.

**What gets delivered:**
- Persona creation form with Liquid Glass (FR23)
- Share link generation (FR24, FR25)
- Deep linking for shared personas (FR26)

**FRs covered:** FR23, FR24, FR25, FR26
**Stories:** 4

---

### Epic 6: Payments, Auth Enhancements & Account Management
Users can subscribe and manage their account securely.

**What gets delivered:**
- RevenueCat integration (ARCH-5)
- Free trial experience (FR33)
- Subscription purchase flow (FR34, FR36)
- Subscription management (FR35)
- Biometric unlock (FR28)
- Account deletion (FR29)

**FRs covered:** FR28, FR29, FR33, FR34, FR35, FR36
**Stories:** 6

---

### Epic 7: Offline Support & Data Sync
Users can access past conversations offline with seamless sync.

**What gets delivered:**
- Offline read access with SwiftData (FR30)
- Offline warning banner (FR31, UX-10)
- Automatic sync on reconnect (FR32)

**FRs covered:** FR30, FR31, FR32
**Stories:** 4

---

### Epic 8: Engagement & Push Notifications
Users receive context-aware proactive check-ins.

**What gets delivered:**
- APNs push notification infrastructure (FR40)
- Context-aware check-in triggers (FR37)
- Notification preferences (FR38)
- Permission request timing (FR39)

**FRs covered:** FR37, FR38, FR39, FR40
**Stories:** 4

---

### Epic 9: Operator Tools & App Store Launch
Operator can monitor and manage; app is ready for launch.

**What gets delivered:**
- Operator dashboard with metrics (FR41)
- Per-user API cost tracking (FR42)
- Domain configuration management (FR43, FR44)
- Rate limiting (FR45)
- Persona safety review (FR46)
- App Store submission (FR47)

**FRs covered:** FR41, FR42, FR43, FR44, FR45, FR46, FR47
**Stories:** 8

---

## Epic Dependencies

```
Epic 1 (Foundation) → enables all other epics
     ↓
Epic 2 (Context) → enables Epic 3 (patterns need context)
     ↓
Epic 3 (Routing/Patterns) → standalone with Epics 1+2
     ↓
Epic 4 (Safety) → standalone with Epic 1
Epic 5 (Creator) → standalone with Epics 1+2
Epic 6 (Payments/Auth) → standalone with Epic 1
Epic 7 (Offline) → standalone with Epics 1+2
Epic 8 (Notifications) → standalone with Epics 1+2
Epic 9 (Operator/Launch) → requires all previous epics
```

---

## Epic 1: Project Foundation & Core Chat Experience

Users can open the app and have a streaming AI coaching conversation.

### Story 1.1: Initialize Xcode Project with iOS 18+ & Core Dependencies

As a **developer**,
I want **the project scaffolded with Swift 6, SwiftUI, and all core dependencies**,
So that **I have a working foundation to build Coach App**.

**Acceptance Criteria:**

**Given** no existing project
**When** I create a new Xcode project with iOS 18.0 deployment target
**Then** the project is created with Swift 6 and SwiftUI lifecycle

**Given** the Xcode project exists
**When** I add dependencies (Supabase Swift SDK, RevenueCat SDK, Sentry SDK)
**Then** all dependencies are added via Swift Package Manager without conflicts

**Given** dependencies are installed
**When** I configure the project structure per architecture
**Then** folders exist: App/, Features/, Core/, Resources/, Supabase/, Tests/

**Given** the project is configured
**When** I build and run on both iOS 18 and iOS 26 Simulators
**Then** the app launches successfully on both versions

**Technical Notes:**
- Create Xcode project: Coach App, Interface: SwiftUI, Language: Swift
- Set deployment target to iOS 18.0
- Add SPM dependencies: `supabase-swift`, `purchases-ios`, `sentry-cocoa`
- Create folder structure per architecture.md
- Verify builds on iOS 18, 22, and 26 simulators

---

### Story 1.2: Adaptive Design System Foundation

As a **developer**,
I want **an adaptive design system that detects iOS version at runtime**,
So that **the app delivers Liquid Glass on iOS 26+ and Warm Modern on iOS 18-25**.

**Acceptance Criteria:**

**Given** the app launches on iOS 26+
**When** the design system initializes
**Then** Liquid Glass styling is enabled via `.glassEffect()` modifiers

**Given** the app launches on iOS 18-25
**When** the design system initializes
**Then** Warm Modern styling is enabled via `.ultraThinMaterial` and standard SwiftUI materials

**Given** I use adaptive modifiers in views
**When** I apply `.adaptiveGlass()` or `.adaptiveInteractiveGlass()`
**Then** the correct styling is applied based on iOS version without conditional code in views

**Given** I run the app on different iOS versions
**When** I compare the experiences
**Then** both feel intentionally designed and premium (UX-14)

**Technical Notes:**
- Create `Core/UI/Modifiers/AdaptiveGlassModifiers.swift` with version-aware extensions
- Create `Core/UI/Modifiers/VersionDetection.swift` for reusable version checks
- Create `Core/UI/Components/AdaptiveGlassContainer.swift` wrapping `GlassEffectContainer`
- Create `Core/UI/Theme/DesignSystem.swift` as coordinator
- Test on iOS 18, 22, and 26 simulators
- Use `if #available(iOS 26, *)` pattern consistently

---

### Story 1.3: Supabase Project Setup & Core Database Schema

As a **developer**,
I want **Supabase configured with the core database schema**,
So that **user data and conversations can be stored securely**.

**Acceptance Criteria:**

**Given** a new Supabase project
**When** I configure auth settings
**Then** Apple OAuth provider is enabled and configured

**Given** Supabase auth is configured
**When** I create migrations for `users`, `conversations`, `messages` tables
**Then** tables are created with proper foreign keys and indexes

**Given** tables exist
**When** I add Row Level Security policies
**Then** users can only read/write their own data

**Given** the Supabase project
**When** I configure environment variables in Xcode
**Then** the iOS app can connect to Supabase

**Technical Notes:**
- Create Supabase project at supabase.com
- Enable Apple OAuth provider
- Create migrations: 00001_initial_schema.sql
- Add RLS policies per architecture.md
- Store SUPABASE_URL and SUPABASE_ANON_KEY in Configuration.swift

---

### Story 1.4: Sign in with Apple Authentication

As a **user**,
I want **to sign in with my Apple ID**,
So that **I have a secure personal account with minimal friction**.

**Acceptance Criteria:**

**Given** I am on the welcome screen
**When** I tap "Sign in with Apple"
**Then** the native Apple authentication sheet appears

**Given** I complete Apple authentication successfully
**When** the app receives the credential
**Then** my Supabase user is created/updated and I am navigated to the chat screen

**Given** I have previously signed in
**When** I launch the app
**Then** my session is restored automatically from Keychain

**Given** authentication fails
**When** I see an error
**Then** the message is warm and first-person: "I had trouble signing you in. Let's try that again."

**Technical Notes:**
- Use AuthenticationServices framework
- Send Apple identity token to Supabase Edge Function for verification
- Store Supabase JWT in Keychain via KeychainManager
- Implement AuthService and AuthViewModel per architecture

---

### Story 1.5: Core Chat UI with Adaptive Design

As a **user**,
I want **a beautiful chat interface that feels premium on any iOS version**,
So that **coaching feels warm and personal regardless of my device**.

**Acceptance Criteria:**

**Given** I am on the chat screen on iOS 26+
**When** I view the interface
**Then** navigation elements use Liquid Glass (`.glassEffect()`) and content floats above warm background

**Given** I am on the chat screen on iOS 18-25
**When** I view the interface
**Then** navigation elements use Warm Modern styling (`.ultraThinMaterial`) and content floats above warm background

**Given** I am viewing messages
**When** I see the chat bubbles
**Then** user messages and coach responses are visually distinct with warm colors (same on both iOS tiers)

**Given** I want to send a message
**When** I see the input area
**Then** it uses `AdaptiveGlassContainer` with send button having `.adaptiveInteractiveGlass()`

**Given** accessibility settings are enabled
**When** reduced transparency is on
**Then** materials automatically adjust for clarity on both iOS tiers

**Technical Notes:**
- Create ChatView.swift with adaptive toolbar using `.adaptiveGlass()`
- Create MessageBubble.swift (no glass on content — same on both iOS tiers)
- Create MessageInput.swift with AdaptiveGlassContainer
- Apply warm color palette from Colors.swift (shared across iOS versions)
- Ensure VoiceOver labels on all interactive elements
- Test on both iOS 18 and iOS 26 simulators

---

### Story 1.6: Chat Streaming Edge Function

As a **developer**,
I want **an Edge Function that streams LLM responses**,
So that **users see coaching responses token-by-token**.

**Acceptance Criteria:**

**Given** a chat request arrives at the Edge Function
**When** I process the request
**Then** I verify the JWT and extract the user ID

**Given** a valid user
**When** I call the LLM API
**Then** I stream the response back via Server-Sent Events

**Given** the stream completes
**When** I have the full response
**Then** I save the message to the database and log usage/cost

**Given** an error occurs
**When** the LLM is unavailable
**Then** I return a graceful error within 3 seconds

**Technical Notes:**
- Create supabase/functions/chat-stream/index.ts
- Use llm-client.ts for provider-agnostic LLM calls
- Implement SSE streaming with proper headers
- Log to usage_logs table on completion

---

### Story 1.7: iOS SSE Streaming Client

As a **user**,
I want **to see coaching responses appear smoothly, word by word**,
So that **it feels like a thoughtful conversation, not a dump of text**.

**Acceptance Criteria:**

**Given** I send a message
**When** the coach starts responding
**Then** I see a typing indicator with subtle animation

**Given** tokens are streaming
**When** they arrive
**Then** text appears smoothly with 50-100ms buffering (not jittery single-token)

**Given** the stream completes
**When** the full response is shown
**Then** the typing indicator disappears and message is finalized

**Given** the stream is interrupted
**When** I see partial content
**Then** I can tap a retry button to try again

**Technical Notes:**
- Create ChatStreamService.swift using URLSession AsyncBytes
- Create StreamingText.swift view for buffered rendering
- Create TypingIndicator.swift with subtle Liquid Glass animation
- Implement retry mechanism in ChatViewModel

---

### Story 1.8: Voice Input

As a **user**,
I want **to speak my messages instead of typing**,
So that **coaching is convenient when I'm on the go**.

**Acceptance Criteria:**

**Given** I am on the chat screen
**When** I tap the microphone button
**Then** the app requests microphone permission if not granted

**Given** permission is granted
**When** I tap and hold the microphone
**Then** speech-to-text converts my words to text in the input field

**Given** I release the microphone
**When** the text is transcribed
**Then** I can review and edit before sending

**Technical Notes:**
- Use Speech framework for speech recognition
- Add microphone button to MessageInput with `.adaptiveInteractiveGlass()`
- Request permission with warm explanation
- Handle errors gracefully

---

### Story 1.9: Warm Visual Design System

As a **user**,
I want **a warm, inviting visual design that's consistent across iOS versions**,
So that **the app feels approachable for personal conversations on any device**.

**Acceptance Criteria:**

**Given** I open the app on any iOS version
**When** I see the interface in light mode
**Then** colors are warm earth tones with soft accents (not sterile whites or tech blues)

**Given** I have dark mode enabled
**When** I view the app
**Then** dark mode uses warm dark tones (not pure black) on all iOS versions

**Given** I see empty states
**When** there's no content
**Then** empty states have personality with warm copy

**Given** errors occur
**When** I see error messages
**Then** they use first person: "I couldn't connect right now"

**Given** I compare iOS 18 and iOS 26 experiences
**When** I view the same screens
**Then** the color palette, typography, and warmth feel identical (only glass effects differ)

**Technical Notes:**
- Implement Colors.swift with warm palette (shared across iOS versions)
- Implement Typography.swift with Dynamic Type support
- Create empty state components with personality
- Ensure all error strings use first person
- Verify visual consistency across iOS 18 and iOS 26

---

## Epic 2: Personal Context & Memory

Users experience coaching that remembers who they are.

### Story 2.1: Context Profile Data Model & Storage

As a **developer**,
I want **a context profile data model stored in Supabase and cached locally**,
So that **user context persists across sessions and works offline**.

**Acceptance Criteria:**

**Given** a new user
**When** they sign up
**Then** a context_profiles row is created with empty JSONB for values, goals, situation

**Given** context is updated
**When** I save changes
**Then** data is synced to Supabase and cached in SwiftData

**Given** the app launches offline
**When** I need context
**Then** I can load from SwiftData cache

**Technical Notes:**
- Create migration 00002_context_profiles.sql (if not in initial)
- Create ContextProfile.swift model with Codable
- Create SwiftData @Model for local caching
- Implement ContextRepository with remote + local sources

---

### Story 2.2: Context Setup Prompt After First Session

As a **user**,
I want **to be asked if I want the coach to remember me after my first conversation**,
So that **I understand the value and can opt in**.

**Acceptance Criteria:**

**Given** I complete my first coaching exchange
**When** the coach's response ends
**Then** an adaptive sheet slides up asking "Want me to remember what matters to you?"

**Given** I tap "Yes, remember me"
**When** the sheet transitions
**Then** I see fields to add values, goals, and life situation

**Given** I tap "Not now"
**When** I dismiss the sheet
**Then** I continue chatting and am prompted again after session 3

**Technical Notes:**
- Create ContextPromptSheet.swift with adaptive morphing/transitions
- Track first_session_complete flag in user preferences
- Store prompt_dismissed_count for re-prompt logic
- Animate sheet with glass morphing transition

---

### Story 2.3: Progressive Context Extraction

As a **user**,
I want **the coach to learn about me from our conversations without me filling out forms**,
So that **my profile builds naturally over time**.

**Acceptance Criteria:**

**Given** I mention a value like "honesty is important to me"
**When** the coach responds
**Then** it notes this for potential extraction

**Given** multiple conversations over time
**When** patterns emerge
**Then** the system suggests adding detected context to my profile

**Given** a context suggestion appears
**When** I confirm it's accurate
**Then** it's added to my profile

**Technical Notes:**
- Create extract-context Edge Function
- Use LLM to identify values/goals/situation from conversation
- Store suggestions for user confirmation
- Never auto-add without user consent

---

### Story 2.4: Context Injection into Coaching Responses

As a **user**,
I want **the coach to use what it knows about me in every response**,
So that **advice feels personalized, not generic**.

**Acceptance Criteria:**

**Given** I have context in my profile
**When** the coach responds
**Then** responses reference my values, goals, or situation when relevant

**Given** the coach references my context
**When** I see the response
**Then** memory moments are highlighted with subtle visual distinction

**Technical Notes:**
- Update context-loader.ts to include profile in prompt
- Update prompt-builder.ts to integrate context
- Add memory moment detection in streaming response
- Create subtle visual treatment for memory moments (UX-4)

---

### Story 2.5: Context Profile Viewing & Editing

As a **user**,
I want **to see and edit what the coach knows about me**,
So that **I have full control over my data**.

**Acceptance Criteria:**

**Given** I tap my profile
**When** the profile view opens
**Then** I see my values, goals, and situation in an organized layout

**Given** I want to edit a value
**When** I tap edit
**Then** an adaptive sheet allows me to modify the text

**Given** I want to remove something
**When** I tap delete on an item
**Then** it's removed after confirmation

**Technical Notes:**
- Create ContextProfileView.swift
- Create ContextEditorSheet.swift with adaptive styling
- Implement ContextViewModel for state management
- Add VoiceOver accessibility labels

---

### Story 2.6: Conversation Deletion

As a **user**,
I want **to delete individual conversations or all my history**,
So that **I control what the coach remembers**.

**Acceptance Criteria:**

**Given** I view a conversation
**When** I tap delete
**Then** I see a confirmation with warm copy: "This will remove our conversation. You sure?"

**Given** I confirm deletion
**When** the action completes
**Then** the conversation is deleted from Supabase and local cache

**Given** I want to delete all history
**When** I tap "Clear all conversations" in settings
**Then** all conversations are deleted after confirmation

**Technical Notes:**
- Add delete action to ConversationRow
- Implement cascade delete in Supabase
- Clear SwiftData cache on delete
- Use warm confirmation copy

---

## Epic 3: Intelligent Domain Routing & Pattern Recognition

Users receive expert coaching in the right domain with pattern insights.

### Story 3.1: Invisible Domain Routing

As a **user**,
I want **the coach to automatically know what type of coaching I need**,
So that **I don't have to pick categories or modes**.

**Acceptance Criteria:**

**Given** I start talking about my career
**When** the coach responds
**Then** it uses career coaching methodology without me selecting it

**Given** I switch topics to relationships
**When** the conversation continues
**Then** the coach seamlessly adjusts to relationships methodology

**Given** domain detection is uncertain
**When** confidence is low
**Then** the coach asks a clarifying question rather than guessing wrong

**Technical Notes:**
- Create domain-router.ts Edge Function helper
- Use NLP classification with confidence threshold
- Load domain configs from Resources/DomainConfigs/
- Implement 7 domains: life, career, relationships, mindset, creativity, fitness, leadership

---

### Story 3.2: Domain Configuration Engine

As an **operator**,
I want **coaching domains defined in JSON config files**,
So that **I can adjust domain behavior without code changes**.

**Acceptance Criteria:**

**Given** a domain config file exists
**When** I read career-coaching.json
**Then** I see tone, methodology, system prompt, and personality defined

**Given** I want to adjust a domain
**When** I modify the config and redeploy Edge Functions
**Then** the domain behavior changes

**Given** I want to add a new domain
**When** I create a new JSON file
**Then** the routing system recognizes and uses it

**Technical Notes:**
- Create 7 JSON config files in Resources/DomainConfigs/
- Create DomainConfig Swift model
- Load configs in Edge Function domain-router.ts
- Support hot-reload via config refresh endpoint

---

### Story 3.3: Cross-Session Memory References

As a **user**,
I want **the coach to reference things I said in previous conversations**,
So that **coaching feels continuous, not fragmented**.

**Acceptance Criteria:**

**Given** I mentioned something important last week
**When** I bring up a related topic today
**Then** the coach references our previous conversation naturally

**Given** a memory reference appears
**When** I see it in the response
**Then** it has subtle visual distinction (UX-4)

**Technical Notes:**
- Update context-loader.ts to include relevant past messages
- Use semantic search or recent history for relevance
- Tag memory references in response for visual treatment
- Limit history to prevent token overflow

---

### Story 3.4: Pattern Recognition Across Conversations

As a **user**,
I want **the coach to notice patterns in what I say over time**,
So that **I gain insights about myself I might not see**.

**Acceptance Criteria:**

**Given** I've mentioned something similar three times across sessions
**When** the coach notices the pattern
**Then** it surfaces an insight: "This is the third time you've described X. What do you think that means?"

**Given** a pattern insight appears
**When** I see it
**Then** it has distinct visual treatment with whitespace and reflective pacing (UX-5)

**Technical Notes:**
- Implement pattern detection in prompt-builder.ts
- Use conversation history analysis
- Surface patterns only with high confidence
- Create PatternInsightView with distinct styling

---

### Story 3.5: Cross-Domain Pattern Synthesis

As a **user**,
I want **the coach to connect dots across different life areas**,
So that **I see the bigger picture of my patterns**.

**Acceptance Criteria:**

**Given** I've discussed similar themes in career and relationships
**When** the coach recognizes the cross-domain pattern
**Then** it synthesizes: "I notice you mention X in both your work and personal life..."

**Technical Notes:**
- Extend pattern detection to span domains
- Require high confidence for cross-domain insights
- Surface sparingly for maximum impact

---

### Story 3.6: Multiple Conversation Threads

As a **user**,
I want **to have separate conversations for different topics**,
So that **I can keep threads organized**.

**Acceptance Criteria:**

**Given** I am in a conversation
**When** I tap "New conversation"
**Then** a new thread starts and I can switch between threads

**Given** I have multiple conversations
**When** I view my history
**Then** I see them organized with domain badges and last message preview

**Technical Notes:**
- Conversations table already supports multiple per user
- Create thread selection UI in HistoryView
- Add domain badge to ConversationRow
- Implement conversation switching in ChatViewModel

---

### Story 3.7: Conversation History View

As a **user**,
I want **to see all my past conversations**,
So that **I can review previous coaching sessions**.

**Acceptance Criteria:**

**Given** I have past conversations
**When** I tap history
**Then** I see a list with domain badges, dates, and preview text

**Given** I tap a past conversation
**When** it opens
**Then** I see the full message history

**Given** the conversation is read-only (completed)
**When** I want to continue
**Then** I can tap "Continue this conversation" to reopen it

**Technical Notes:**
- Create HistoryView.swift with adaptive navigation styling
- Create ConversationRow with domain badge
- Implement HistoryViewModel with SwiftData queries
- Support continuation of past conversations

---

## Epic 4: Coaching Safety & Crisis Handling

Users are protected with appropriate boundaries.

### Story 4.1: Crisis Detection Pipeline

As a **system**,
I want **to detect crisis indicators before generating a response**,
So that **users in distress get appropriate resources immediately**.

**Acceptance Criteria:**

**Given** a user message arrives
**When** I analyze it for crisis indicators
**Then** I check for self-harm, suicidal ideation, abuse, and severe distress

**Given** crisis indicators are detected
**When** the pipeline triggers
**Then** the response includes crisis resources instead of regular coaching

**Technical Notes:**
- Create crisis-detector.ts Edge Function helper
- Run before LLM call in chat-stream pipeline
- Use keyword matching + LLM analysis
- Return crisis_detected flag in response

---

### Story 4.2: Crisis Resource Display

As a **user in distress**,
I want **to see crisis resources presented with empathy**,
So that **I feel supported, not dismissed**.

**Acceptance Criteria:**

**Given** crisis is detected
**When** the response appears
**Then** a warm adaptive sheet slides in with empathetic message and resources

**Given** the crisis sheet is displayed
**When** I see the content
**Then** I see 988 Suicide & Crisis Lifeline and Crisis Text Line with tap-to-call/text

**Given** I want to continue coaching
**When** I dismiss the sheet
**Then** I can continue the conversation

**Technical Notes:**
- Create CrisisResourceSheet.swift with warm adaptive styling
- Include empathetic copy: "I hear you, and what you're feeling sounds really heavy..."
- Make phone numbers and text links tappable
- Store crisis resources in CrisisResources.swift constants

---

### Story 4.3: Coaching Disclaimers

As a **user**,
I want **to understand that this is coaching, not therapy**,
So that **I have appropriate expectations**.

**Acceptance Criteria:**

**Given** I first open the app
**When** I see the welcome screen
**Then** there's a brief disclaimer: "AI coaching, not therapy or mental health treatment"

**Given** I review terms of service
**When** I read the terms
**Then** the therapeutic disclaimer is clearly stated

**Technical Notes:**
- Add disclaimer to WelcomeView
- Include disclaimer in onboarding flow
- Link to full terms from settings

---

### Story 4.4: Tone Guardrails & Clinical Boundaries

As a **user**,
I want **the coach to always be warm and supportive**,
So that **I never feel judged or dismissed**.

**Acceptance Criteria:**

**Given** any user message (including provocative ones)
**When** the coach responds
**Then** the tone is never dismissive, sarcastic, or harsh

**Given** I ask for a diagnosis
**When** the coach responds
**Then** it explains it can't diagnose and suggests professional resources

**Given** I ask for medication advice
**When** the coach responds
**Then** it declines and recommends consulting a healthcare provider

**Technical Notes:**
- Include tone guardrails in system prompt
- Add clinical boundary rules to prompt-builder.ts
- Test with edge case inputs

---

### Story 4.5: Context Continuity After Crisis

As a **user who returns after a crisis episode**,
I want **the coach to pick up naturally**,
So that **I don't feel awkward about what happened**.

**Acceptance Criteria:**

**Given** I had a crisis-detected conversation
**When** I return later
**Then** the coach welcomes me back warmly without dwelling on the crisis

**Given** I want to continue normal coaching
**When** I start talking about career
**Then** the coach responds normally with full context continuity

**Technical Notes:**
- Don't flag crisis conversations differently in context loading
- Resume normal coaching without special treatment
- Maintain all context from before crisis

---

## Epic 5: Creator Tools & Sharing

Users can create and share custom coaching personas.

### Story 5.1: Coaching Persona Creation Form

As a **creator**,
I want **to define a custom coaching persona**,
So that **I can share my methodology with others**.

**Acceptance Criteria:**

**Given** I tap "Create a Coach"
**When** the form appears
**Then** I see fields for name, domain, tone, methodology, and personality

**Given** I fill out the form
**When** I tap create
**Then** my persona is saved and visible in my creator dashboard

**Given** the form is displayed
**When** I interact with it
**Then** it uses adaptive styling (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25)

**Technical Notes:**
- Create PersonaFormSheet.swift with adaptive styling
- Create CoachingPersona.swift model
- Create PersonaRepository for CRUD
- Store in coaching_personas table

---

### Story 5.2: Share Link Generation

As a **creator**,
I want **to generate a shareable link for my coaching persona**,
So that **others can try it**.

**Acceptance Criteria:**

**Given** I have created a persona
**When** I tap "Share"
**Then** I see a unique link I can copy

**Given** I copy the link
**When** I share it on social media
**Then** recipients can tap it to open the app/App Store

**Technical Notes:**
- Generate unique share code per persona
- Format: coachapp.ai/c/{code}
- Implement Universal Links for deep linking
- Create ShareLinkView.swift

---

### Story 5.3: Deep Linking for Shared Personas

As a **user receiving a shared link**,
I want **to start coaching with that specific persona**,
So that **I experience what was shared with me**.

**Acceptance Criteria:**

**Given** I tap a Coach App share link
**When** I have the app installed
**Then** the app opens to that persona's coaching session

**Given** I tap a share link
**When** I don't have the app installed
**Then** I'm taken to the App Store to download

**Given** I just installed from a share link
**When** I open the app for the first time
**Then** I'm taken directly to that persona's coaching session

**Technical Notes:**
- Configure Associated Domains in Xcode
- Create DeepLinkHandler.swift in App/Navigation
- Handle deferred deep linking for new installs
- Store pending deep link in UserDefaults

---

### Story 5.4: Creator Dashboard

As a **creator**,
I want **to see and manage all my coaching personas**,
So that **I can edit, share, or delete them**.

**Acceptance Criteria:**

**Given** I have created personas
**When** I open the creator tab
**Then** I see all my personas in a grid/list

**Given** I tap a persona
**When** the detail view opens
**Then** I can edit, share, or delete

**Technical Notes:**
- Create CreatorDashboard.swift
- Create PersonaCard.swift for grid items
- Implement CreatorViewModel

---

## Epic 6: Payments, Auth Enhancements & Account Management

Users can subscribe and manage their account securely.

### Story 6.1: RevenueCat Integration

As a **developer**,
I want **RevenueCat configured for subscription management**,
So that **payments work reliably without manual StoreKit complexity**.

**Acceptance Criteria:**

**Given** RevenueCat SDK is installed
**When** I configure it with API keys
**Then** it initializes successfully on app launch

**Given** a user signs in
**When** I identify them with RevenueCat
**Then** their subscription status syncs

**Technical Notes:**
- Add RevenueCat API key to Configuration.swift
- Create RevenueCatService.swift
- Configure products in RevenueCat dashboard
- Sync with Apple App Store Connect

---

### Story 6.2: Free Trial Experience

As a **user**,
I want **to try Coach App without providing payment info**,
So that **I can experience the value before committing**.

**Acceptance Criteria:**

**Given** I'm a new user
**When** I sign up
**Then** my trial starts automatically

**Given** I'm in my trial
**When** I see the trial banner
**Then** I know how many days/sessions remain

**Given** my trial is about to end
**When** 1 day remains
**Then** I get a gentle notification

**Technical Notes:**
- Configure trial in RevenueCat
- Create TrialBanner.swift
- Track trial status in SubscriptionViewModel
- Schedule trial ending notification

---

### Story 6.3: Subscription Purchase Flow

As a **user**,
I want **to subscribe after my trial**,
So that **I can continue using Coach App**.

**Acceptance Criteria:**

**Given** my trial has ended
**When** I try to start a chat
**Then** a paywall appears with subscription options

**Given** I tap subscribe
**When** the Apple payment sheet appears
**Then** I can complete payment

**Given** payment succeeds
**When** the sheet dismisses
**Then** I can continue chatting immediately

**Technical Notes:**
- Create PaywallView.swift with adaptive styling
- Use RevenueCat purchasing API
- Handle transaction states
- Update entitlements immediately

---

### Story 6.4: Subscription Management

As a **subscriber**,
I want **to view and manage my subscription**,
So that **I have full control over my account**.

**Acceptance Criteria:**

**Given** I am subscribed
**When** I tap subscription in settings
**Then** I see my current plan and renewal date

**Given** I want to cancel
**When** I tap manage subscription
**Then** I'm taken to iOS subscription management

**Technical Notes:**
- Create SubscriptionManagement.swift
- Use RevenueCat for subscription info
- Link to iOS subscription settings
- Handle cancellation gracefully

---

### Story 6.5: Biometric Unlock

As a **user**,
I want **to unlock Coach App with Face ID or Touch ID**,
So that **my personal conversations are secure and convenient to access**.

**Acceptance Criteria:**

**Given** I've signed in
**When** I'm asked to enable biometric
**Then** I can choose to enable Face ID or Touch ID

**Given** biometric is enabled
**When** I launch the app
**Then** I'm prompted for Face ID/Touch ID before seeing content

**Given** biometric fails
**When** I can't authenticate
**Then** I can fall back to full sign-in

**Technical Notes:**
- Use LocalAuthentication framework
- Create BiometricService.swift
- Store biometric preference in Keychain
- Handle fallback gracefully

---

### Story 6.6: Account Deletion

As a **user**,
I want **to delete my account and all my data**,
So that **I have full control over my privacy**.

**Acceptance Criteria:**

**Given** I want to delete my account
**When** I tap "Delete Account" in settings
**Then** I see a confirmation with warm copy explaining what happens

**Given** I confirm deletion
**When** the action completes
**Then** all my data is removed from Supabase and local storage

**Given** my account is deleted
**When** I open the app next
**Then** I see the welcome screen for new users

**Technical Notes:**
- Create AccountDeletion.swift view
- Implement server-side deletion via Edge Function
- Clear Keychain and SwiftData
- RevenueCat user ID reset

---

## Epic 7: Offline Support & Data Sync

Users can access past conversations offline with seamless sync.

### Story 7.1: Offline Data Caching with SwiftData

As a **user**,
I want **my conversations cached on my device**,
So that **I can read them when offline**.

**Acceptance Criteria:**

**Given** I have conversations
**When** data is fetched from Supabase
**Then** it's also saved to SwiftData for offline access

**Given** I lose network connection
**When** I open the app
**Then** I can browse my cached conversations

**Technical Notes:**
- Create SwiftData @Model definitions
- Implement caching in ConversationRepository
- Cache messages, context profile
- Handle SwiftData errors gracefully

---

### Story 7.2: Offline Warning Banner

As a **user who is offline**,
I want **a clear but warm warning**,
So that **I understand why I can't chat but don't feel frustrated**.

**Acceptance Criteria:**

**Given** I'm offline
**When** I'm on the chat screen
**Then** I see an adaptive banner: "You're offline right now. Your past conversations are here — new coaching needs a connection."

**Given** I'm offline
**When** I try to send a message
**Then** the send button is disabled with warm tooltip

**Technical Notes:**
- Create NetworkMonitor.swift using NWPathMonitor
- Create OfflineBanner.swift with adaptive styling
- Disable send button when offline
- Use warm, first-person copy

---

### Story 7.3: Automatic Sync on Reconnect

As a **user coming back online**,
I want **my data to sync automatically**,
So that **I don't have to do anything manually**.

**Acceptance Criteria:**

**Given** I come back online
**When** network is detected
**Then** the app automatically syncs any pending changes

**Given** sync completes
**When** new data is available
**Then** the UI updates automatically

**Technical Notes:**
- Create OfflineSyncService.swift
- Monitor network state changes
- Implement sync queue for pending operations
- Update SwiftData and refresh views

---

### Story 7.4: Sync Conflict Resolution

As a **user**,
I want **sync conflicts handled gracefully**,
So that **I don't lose any data**.

**Acceptance Criteria:**

**Given** there's a conflict between local and remote
**When** sync runs
**Then** server data takes precedence for conversations (server is source of truth)

**Given** context profile has conflicts
**When** sync runs
**Then** most recent timestamp wins

**Technical Notes:**
- Use timestamp-based conflict resolution
- Server is authoritative for messages
- Most recent wins for user-editable data
- Log conflicts for monitoring

---

## Epic 8: Engagement & Push Notifications

Users receive context-aware proactive check-ins.

### Story 8.1: APNs Push Infrastructure

As a **developer**,
I want **push notifications configured**,
So that **I can send proactive coaching check-ins**.

**Acceptance Criteria:**

**Given** the app launches
**When** user has granted permission
**Then** device token is registered with Supabase

**Given** a push is sent
**When** it's delivered
**Then** the notification appears correctly

**Technical Notes:**
- Configure APNs in Apple Developer Portal
- Add push capability to Xcode
- Create PushNotificationService.swift
- Store device tokens in push_tokens table

---

### Story 8.2: Permission Request Timing

As a **user**,
I want **to be asked for push permission at the right time**,
So that **I understand why and am more likely to say yes**.

**Acceptance Criteria:**

**Given** I'm a new user
**When** I first launch
**Then** I am NOT asked for push permission yet

**Given** I complete my first coaching session
**When** the session ends
**Then** I'm asked: "Want me to check in with you between sessions?"

**Technical Notes:**
- Track session completion count
- Request permission after first complete session
- Use warm copy explaining the value
- Store preference in UserDefaults

---

### Story 8.3: Context-Aware Check-In Triggers

As a **user**,
I want **push notifications that feel personal**,
So that **check-ins are helpful, not annoying**.

**Acceptance Criteria:**

**Given** I had a conversation about an upcoming presentation
**When** the presentation date approaches
**Then** I get: "How did your presentation go?"

**Given** I haven't opened the app in 3 days
**When** a re-engagement push is triggered
**Then** it references my last conversation topic

**Technical Notes:**
- Create push-trigger Edge Function
- Schedule context-aware notifications
- Use conversation history for personalization
- Respect frequency caps (max 1/day)

---

### Story 8.4: Notification Preferences

As a **user**,
I want **to control my notification settings**,
So that **I get the right amount of engagement**.

**Acceptance Criteria:**

**Given** I open notification settings
**When** I view my preferences
**Then** I can enable/disable check-ins and set frequency

**Given** I disable notifications
**When** I save
**Then** no more notifications are sent

**Technical Notes:**
- Create NotificationSettings.swift
- Store preferences in Supabase
- Respect preferences in push-trigger function

---

## Epic 9: Operator Tools & App Store Launch

Operator can monitor and manage; app is ready for launch.

### Story 9.1: Operator Dashboard - Metrics View

As an **operator**,
I want **to see key metrics at a glance**,
So that **I understand how the product is performing**.

**Acceptance Criteria:**

**Given** I'm logged in as operator
**When** I open the dashboard
**Then** I see DAU, WAU, retention, and engagement metrics

**Given** metrics are loading
**When** the view renders
**Then** I see skeleton loading states

**Technical Notes:**
- Create DashboardView.swift
- Create MetricsView.swift
- Query aggregate metrics from Supabase
- Implement operator role check

---

### Story 9.2: Per-User API Cost Tracking

As an **operator**,
I want **to see API costs per user**,
So that **I can monitor unit economics and identify abuse**.

**Acceptance Criteria:**

**Given** I view cost metrics
**When** the data loads
**Then** I see total costs and per-user breakdown

**Given** a user exceeds cost threshold
**When** alert is triggered
**Then** I can see the flagged users

**Technical Notes:**
- Query usage_logs table
- Calculate costs from token counts
- Create cost alert threshold
- Display in dashboard

---

### Story 9.3: Domain Configuration Management

As an **operator**,
I want **to modify domain configurations without code changes**,
So that **I can iterate on coaching quality quickly**.

**Acceptance Criteria:**

**Given** I open domain config
**When** I view a domain
**Then** I see its tone, methodology, and personality settings

**Given** I edit a domain
**When** I save changes
**Then** the config updates and new conversations use it

**Technical Notes:**
- Create DomainConfigView.swift
- Store configs in Supabase or update JSON files
- Implement config refresh mechanism

---

### Story 9.4: Rate Limiting

As a **system**,
I want **to enforce rate limits per user**,
So that **costs stay controlled and service remains stable**.

**Acceptance Criteria:**

**Given** a user sends many messages quickly
**When** they hit the rate limit
**Then** they see a friendly message: "Let's take a breath. You can continue in a moment."

**Given** rate limits are configurable
**When** I adjust the threshold
**Then** the new limit applies

**Technical Notes:**
- Implement rate limiting in chat-stream Edge Function
- Store rate limit config
- Return friendly error when limited
- Track in usage_logs

---

### Story 9.5: Persona Safety Review

As an **operator**,
I want **to review user-created coaching personas**,
So that **harmful content doesn't spread**.

**Acceptance Criteria:**

**Given** a user creates a persona
**When** it's flagged for review
**Then** I see it in my review queue

**Given** I review a persona
**When** I approve or reject
**Then** its status updates accordingly

**Technical Notes:**
- Add status field to coaching_personas
- Create review queue view
- Implement approval workflow

---

### Story 9.6: App Store Metadata & Compliance

As an **operator**,
I want **the app ready for App Store submission**,
So that **users can download it**.

**Acceptance Criteria:**

**Given** I prepare for submission
**When** I review the app
**Then** AI content disclosure is visible

**Given** I prepare for submission
**When** I check features
**Then** account deletion works correctly

**Given** I submit to App Store
**When** review happens
**Then** all compliance requirements are met

**Technical Notes:**
- Create App Store screenshots
- Write description with AI disclosure
- Verify Privacy Nutrition Labels match actual data use
- Test account deletion flow

---

### Story 9.7: App Icon & Launch Screen

As a **user**,
I want **a beautiful app icon and launch screen**,
So that **the app feels polished from first impression**.

**Acceptance Criteria:**

**Given** I look at my home screen
**When** I see Coach App
**Then** the icon reflects warm, approachable design

**Given** I tap to open
**When** the app launches
**Then** the launch screen matches the warm design system

**Technical Notes:**
- Design app icon following Apple HIG
- Create launch screen with warm colors
- Add to Assets.xcassets

---

### Story 9.8: Final QA & TestFlight Distribution

As a **developer**,
I want **the app thoroughly tested across iOS versions and distributed to beta users**,
So that **bugs are found before public launch**.

**Acceptance Criteria:**

**Given** development is complete
**When** I run full regression on iOS 18 and iOS 26
**Then** all critical flows pass on both iOS tiers

**Given** I test the adaptive design
**When** I compare iOS 18-25 and iOS 26+ experiences
**Then** both feel intentionally designed and premium (UX-14)

**Given** I upload to TestFlight
**When** the build processes
**Then** beta testers can install and test on various iOS versions

**Given** beta feedback is collected
**When** bugs are found
**Then** they are fixed before App Store submission

**Technical Notes:**
- Create test plan covering all epics
- Test matrix: iOS 18, iOS 22, iOS 26 simulators and devices
- Verify adaptive design parity across iOS versions
- Configure TestFlight
- Collect beta feedback
- Fix P0/P1 bugs before launch

---

## Summary

| Epic | Stories | FRs Covered |
|------|---------|-------------|
| Epic 1: Foundation & Chat | 9 | FR1, FR2, FR3, FR27, ARCH-2 |
| Epic 2: Context & Memory | 6 | FR10-FR15 |
| Epic 3: Routing & Patterns | 7 | FR4-FR9 |
| Epic 4: Safety & Crisis | 5 | FR16-FR22 |
| Epic 5: Creator & Sharing | 4 | FR23-FR26 |
| Epic 6: Payments & Auth | 6 | FR28, FR29, FR33-FR36 |
| Epic 7: Offline & Sync | 4 | FR30-FR32 |
| Epic 8: Notifications | 4 | FR37-FR40 |
| Epic 9: Operator & Launch | 8 | FR41-FR47, ARCH-11 |
| **Total** | **53** | **47/47 FRs + Adaptive Design** |

All 47 functional requirements are covered by the 53 stories across 9 epics, with progressive enhancement for iOS 18+ (Warm Modern) and iOS 26+ (Liquid Glass).
