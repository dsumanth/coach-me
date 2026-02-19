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
| FR37 | Epic 8 | Smart proactive push notifications (learning-powered) |
| FR38 | Epic 8 | Notification preferences |
| FR39 | Epic 8 | Permission request timing |
| FR40 | Epic 8 | APNs delivery |
| NEW | Epic 8 | Learning signals infrastructure |
| NEW | Epic 8 | In-conversation pattern recognition engine |
| NEW | Epic 8 | Progress tracking & coaching reflections |
| NEW | Epic 8 | Coaching style adaptation |
| NEW | Epic 8 | Enhanced profile — learned knowledge display |
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

### Epic 8: Adaptive Coaching Intelligence & Proactive Engagement
The coach gets smarter with every session and reaches out between sessions with real insight.

**What gets delivered:**
- Learning signals infrastructure — behavioral tracking foundation
- APNs push notification infrastructure (FR40)
- Push permission timing and notification preferences (FR38, FR39)
- In-conversation pattern recognition engine (FR8, FR9 enhanced)
- Progress tracking and coaching reflections
- Coaching style adaptation per user
- Smart proactive push notifications powered by learning (FR37)
- Enhanced profile displaying learned knowledge (FR14 enhanced)

**FRs covered:** FR8 (enhanced), FR9 (enhanced), FR14 (enhanced), FR37, FR38, FR39, FR40
**Stories:** 8

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
- Implement HistoryViewModel with Supabase queries (SwiftData caching deferred to Story 7.1)
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

## Epic 8: Adaptive Coaching Intelligence & Proactive Engagement

The coach gets smarter with every session and reaches out between sessions with real insight. All learning surfaces through conversation — no dashboards, no feedback buttons. The profile serves as a transparent control panel where users can see, edit, or delete what the system has learned.

**Design Principle:** "A real coach has no dashboard." Learning is invisible infrastructure. Output is the coach's voice in conversation.

### Story 8.1: Learning Signals Infrastructure

As a **developer**,
I want **a data foundation that captures behavioral signals from user interactions**,
So that **all intelligence layers have the signals they need to learn about each user**.

**Acceptance Criteria:**

**Given** a user confirms or dismisses an extracted insight
**When** the action completes
**Then** the confirmation action (confirmed/dismissed) and timestamp are recorded in learning signals

**Given** a user completes a coaching session
**When** the session ends
**Then** engagement metrics are captured: message count, average message length, session duration, domain

**Given** a user has multiple sessions over time
**When** I query their learning signals
**Then** I can derive: domain preferences, session frequency patterns, engagement depth trends

**Given** learning signals accumulate
**When** the system queries them
**Then** queries return within 200ms for prompt injection use

**Technical Notes:**
- Create `learning_signals` table in Supabase: `user_id`, `signal_type` (enum: insight_confirmed, insight_dismissed, session_completed, domain_used), `signal_data` (JSONB), `created_at`
- Extend `context_profiles` with `coaching_preferences` JSONB column: `{ preferred_style, domain_usage, session_patterns, last_reflection_at }`
- Create `LearningSignalService.swift` (@MainActor) — record signals, query aggregates
- Track engagement per session: message_count, avg_message_length, session_duration_seconds, domain
- Track insight feedback: which categories get confirmed vs dismissed (informs extraction quality)
- Non-blocking writes — signal capture must never slow down the user experience
- Migration: `20260210000001_learning_signals.sql`

**Dependencies:** None — this is the foundation
**FRs covered:** New (learning infrastructure)

---

### Story 8.2: APNs Push Infrastructure

As a **developer**,
I want **push notifications configured with Apple Push Notification service**,
So that **the app can deliver proactive coaching nudges between sessions**.

**Acceptance Criteria:**

**Given** the app launches and user has granted push permission
**When** the device token is obtained
**Then** it is registered in the `push_tokens` table in Supabase

**Given** a push notification is triggered from the backend
**When** it is sent via APNs
**Then** the notification appears correctly on the user's device

**Given** a user taps a push notification
**When** the app opens
**Then** it navigates to the relevant conversation or starts a new one

**Technical Notes:**
- Configure APNs key in Apple Developer Portal
- Add Push Notifications capability in Xcode
- Create `PushNotificationService.swift` — device token registration, permission management
- Create `push_tokens` table: `user_id`, `device_token`, `platform`, `created_at`, `updated_at`
- Create `push-send` Edge Function helper for server-side push delivery
- Handle token refresh on app launch

**Dependencies:** None — independent infrastructure
**FRs covered:** FR40

---

### Story 8.3: Push Permission Timing & Notification Preferences

As a **user**,
I want **to be asked for push permission at the right moment and control my notification settings**,
So that **I opt in when I understand the value and stay in control of frequency**.

**Acceptance Criteria:**

**Given** I'm a new user
**When** I first launch the app
**Then** I am NOT asked for push permission

**Given** I complete my first coaching session
**When** the session ends
**Then** I'm asked: "Want me to check in with you between sessions?" with warm, explanatory copy

**Given** I open notification settings
**When** I view preferences
**Then** I can enable/disable check-ins and choose frequency (daily, few times a week, weekly)

**Given** I change my notification preferences
**When** I save
**Then** the push-trigger function respects my new settings immediately

**Technical Notes:**
- Use the server-side `coaching_preferences.session_count` (from `context_profiles`) as the authoritative session counter — do NOT maintain a separate `session_completion_count` in UserDefaults. The client reads `session_count` from the cached context profile to determine if this is the first completed session.
- Request permission after first complete session (not on first launch)
- Create `NotificationPreferencesView.swift` in Settings
- Store preferences in `notification_preferences` JSONB column on `context_profiles`
- Warm permission copy: "I'd love to check in between our sessions — a quick nudge to see how things are going. You can always adjust this later."

**Dependencies:** 8.2 (APNs infrastructure)
**FRs covered:** FR38, FR39

---

### Story 8.4: In-Conversation Pattern Recognition Engine

As a **user**,
I want **the coach to notice patterns in my behavior and conversations over time**,
So that **I gain self-awareness about recurring themes I might not see on my own**.

**Acceptance Criteria:**

**Given** I have 5+ sessions with accumulated learning signals
**When** the coach constructs a response
**Then** the system prompt includes a "patterns summary" derived from learning signals (recurring themes, domain frequency, behavioral trends)

**Given** the coach detects a recurring theme across 3+ sessions
**When** it surfaces the pattern in conversation
**Then** it does so naturally through the coach's voice: "I've noticed this is the third time we've talked about X — what do you think is driving that?"

**Given** a pattern is surfaced
**When** the user engages with it (responds with 2+ messages about the pattern)
**Then** the engagement is captured as a learning signal confirming the pattern's relevance

**Given** the system generates pattern summaries
**When** multiple patterns exist
**Then** patterns are ranked by frequency and recency, with only high-confidence patterns (3+ occurrences) included in prompts

**Technical Notes:**
- Create `pattern-analyzer` Edge Function helper — queries learning signals, generates pattern summary for prompt injection
- Extend `prompt-builder.ts` to include `[PATTERNS_CONTEXT]` section when user has 5+ sessions
- Pattern summary format for system prompt: "Recurring themes: [theme1 (N times, domains), theme2 (N times, domains)]. Growth signals: [positive shifts detected]. Coaching style notes: [what works for this user]."
- Build on existing `[PATTERN: ...]` tag infrastructure from Epic 3 — patterns are already parsed and rendered
- Pattern detection runs server-side during prompt construction, NOT client-side
- Cost optimization: cache pattern summaries, refresh every 3 sessions (not every message)

**Dependencies:** 8.1 (learning signals data)
**FRs covered:** FR8, FR9 (enhanced)

---

### Story 8.5: Progress Tracking & Coaching Reflections

As a **user**,
I want **the coach to notice my growth and reflect it back to me at natural moments**,
So that **I feel my progress is seen and I'm motivated to keep going**.

**Acceptance Criteria:**

**Given** I return for a new session after discussing a specific challenge previously
**When** the coach opens the session
**Then** it may naturally ask about how things went: "Last time we talked about your presentation anxiety. How did it go?"

**Given** I have been using the app for 4+ weeks
**When** the coach detects it's been approximately a month since onboarding
**Then** it offers a reflection: "Before we dive in today — it's been about a month since we started. Can I share something I've noticed about your journey so far?"

**Given** the user says "yes" to a monthly reflection
**When** the coach reflects
**Then** it summarizes: top themes, patterns noticed, growth signals — all in the coach's voice, not as a report

**Given** the user says "actually I need to talk about something" when offered a reflection
**When** the coach hears this
**Then** it gracefully pivots: "Of course — what's on your mind?" and saves the reflection for next time

**Technical Notes:**
- Add `last_reflection_at` and `session_count` tracking to `coaching_preferences` JSONB
- **`session_count` is the single source of truth for session counting** — stored server-side in `coaching_preferences.session_count`. There is no separate client-side counter (e.g., UserDefaults). The client emits a `session_completed` signal, and the server increments `session_count` atomically via an RPC call (`increment_session_count`) or a non-blocking Supabase update in the `chat-stream` Edge Function after stream completion. The `reflection-builder` reads `session_count` exclusively from `coaching_preferences`, never from local storage.
- A migration/backfill step should populate `session_count` from historical `conversations` count for existing users: `UPDATE context_profiles SET coaching_preferences = jsonb_set(COALESCE(coaching_preferences, '{}'::jsonb), '{session_count}', to_jsonb((SELECT COUNT(*) FROM conversations WHERE conversations.user_id = context_profiles.user_id)), true) WHERE coaching_preferences->>'session_count' IS NULL`
- Create `reflection-builder` Edge Function helper — generates session-opening check-ins and monthly reflections
- Session check-in logic: if previous session had an unresolved topic/goal, include it as a follow-up prompt
- Monthly reflection logic: triggered when `session_count >= 8 AND days_since_last_reflection >= 25`
- Reflection content generated from pattern summary + goal status + domain usage
- Reflection is a coaching moment, not analytics: "You started talking about career confidence 4 weeks ago. In our recent sessions, I'm hearing you describe yourself differently — less 'I'm not strategic enough' and more 'here's my strategy.' That's a real shift."
- Guard: max 1 reflection per month, never interrupt urgent topics

**Dependencies:** 8.1 (learning signals), 8.4 (pattern recognition)
**FRs covered:** New (progress tracking)

---

### Story 8.6: Coaching Style Adaptation

As a **user**,
I want **the coach to learn how I prefer to be coached and adapt its approach**,
So that **coaching feels personalized to my communication style, not one-size-fits-all**.

**Acceptance Criteria:**

**Given** I consistently engage more deeply with direct, action-oriented responses (longer replies, follow-up questions)
**When** the system analyzes engagement patterns over 5+ sessions
**Then** my `coaching_preferences.preferred_style` is updated to reflect this preference

**Given** my coaching style preference has been learned
**When** the coach constructs a response
**Then** the system prompt includes style guidance: "This user prefers direct, action-oriented coaching. Lead with concrete next steps rather than open-ended exploration."

**Given** my style preference differs across domains (direct for career, exploratory for relationships)
**When** the coach routes to a specific domain
**Then** it applies the domain-specific style preference

**Given** I haven't established a clear style preference yet (fewer than 5 sessions)
**When** the coach responds
**Then** it uses the default balanced coaching style

**Technical Notes:**
- Style dimensions to track: `direct_vs_exploratory`, `brief_vs_detailed`, `action_vs_reflective`, `challenging_vs_supportive`
- Inference method: compare average message length of user replies per response style (proxy for engagement depth)
- Store per-domain style preferences: `coaching_preferences.domain_styles: { "career": { "direct": 0.8, "brief": 0.6 }, "relationships": { "exploratory": 0.7, "detailed": 0.8 } }`
- Create `style-adapter` Edge Function helper — reads preferences, generates style instructions for system prompt
- Style inference runs as background analysis every 5 sessions (via learning signals aggregation), not real-time
- Minimum 5 sessions before any style adaptation kicks in (avoid overfitting to early interactions)
- Users can override in profile (Story 8.8): "I prefer direct coaching" manual setting overrides inference

**Dependencies:** 8.1 (learning signals)
**FRs covered:** New (coaching personalization)

---

### Story 8.7: Smart Proactive Push Notifications

As a **user**,
I want **push notifications between sessions that feel like a thoughtful coach checking in**,
So that **I stay engaged and feel supported even when I'm not in the app**.

**Acceptance Criteria:**

**Given** I discussed a specific upcoming event (presentation, difficult conversation, deadline)
**When** the estimated time of that event approaches
**Then** I receive a push: "Your [event] is coming up. How are you feeling about it?"

**Given** I haven't opened the app in 3+ days
**When** a re-engagement trigger fires
**Then** the push references my last conversation theme, not generic copy: "Still thinking about what we discussed around [topic]?"

**Given** I have a pattern the coach has recognized
**When** a proactive pattern nudge triggers
**Then** the push gently references it: "Noticed you've been quiet this week. Last time this happened, you said work stress was building. Want to talk?"

**Given** any push notification scenario
**When** the push is composed
**Then** the tone matches my learned coaching style preference (direct vs warm, brief vs detailed)

**Given** push frequency settings
**When** calculating whether to send
**Then** the system respects: max 1 push per day, user's frequency preference, and never sends if user had a session that day

**Technical Notes:**
- Create `push-trigger` Edge Function (scheduled daily). **The function performs selective pre-filtering before any expensive work**: query eligible users with a single indexed SQL join filtering on `notification_preferences->>'check_ins_enabled' = 'true'` AND `push_tokens` exists AND `last_push_sent_at < NOW() - frequency_interval` AND `last_session_at` is not today. Further narrow candidates using lightweight indicators (e.g., `WHERE last_session_at < NOW() - INTERVAL '3 days'` for re-engagement, or `event_window_detected` flag for event-based pushes). Only candidates passing these filters proceed to LLM content generation.
- **Cost safeguards:**
  - Daily LLM push budget cap: max 1,000 Haiku calls per daily run. Once exhausted, remaining eligible users are skipped (no generic fallback — skip entirely per the "never send generic content" principle).
  - Track budget usage via a counter in the function's execution context.
  - All push attempts (sent, skipped-budget, skipped-no-decision) are logged to `push_log` (`user_id`, `push_type`, `content`, `sent_at`, `opened`, `metadata: { skip_reason? }`) for cost analysis and debugging.
- Push intelligence layers (in priority order):
  1. Event-based: scan recent conversations for temporal references (dates, "next week", "tomorrow")
  2. Pattern-based: use pattern summary to craft pattern-aware nudges
  3. Re-engagement: fallback for users inactive 3+ days, reference last conversation domain/topic
- Use style-adapter output to match push tone to user preference
- Frequency logic: check `notification_preferences` + `last_push_sent_at` + `last_session_at`
- Push content generated by LLM call (Haiku for cost efficiency) with user context + pattern summary as input
- Store push history in `push_log` table for analysis: `user_id`, `push_type`, `content`, `sent_at`, `opened` (boolean via callback)
- Migration: `20260210000004_push_log.sql`

**Dependencies:** 8.1 (learning signals), 8.2 (APNs), 8.3 (permissions/preferences), 8.4 (patterns), 8.6 (style)
**FRs covered:** FR37

---

### Story 8.8: Enhanced Profile — Learned Knowledge Display

As a **user**,
I want **to see what the coach has learned about me in my profile**,
So that **I have full transparency and control over the system's understanding of me**.

**Acceptance Criteria:**

**Given** the system has learned patterns about me
**When** I open my profile
**Then** I see a "What I've Learned" section showing inferred patterns: "You tend to revisit boundary-setting when work stress peaks"

**Given** the system has detected coaching style preferences
**When** I view the learned knowledge section
**Then** I see my coaching preference: "You prefer direct, action-oriented advice"

**Given** the system has tracked domain usage
**When** I view the learned knowledge section
**Then** I see domain interests: "Career (60%), Relationships (25%), Personal Growth (15%)"

**Given** the system has tracked goal-related progress
**When** I view the learned knowledge section
**Then** I see progress notes: "Goal: speak up in meetings — mentioned positive progress in 3 recent sessions"

**Given** I see an inferred item that's wrong
**When** I tap delete on any learned knowledge item
**Then** it is removed and the system records the deletion as a learning signal (don't re-infer this)

**Given** I want to manually set a preference
**When** I tap edit on coaching style
**Then** I can override the inferred style (manual overrides always win)

**Technical Notes:**
- Extend `ContextProfileView.swift` with new "What I've Learned" section below existing values/goals/situation
- Create `LearnedKnowledgeSection.swift` — displays patterns, style preferences, domain stats, progress notes
- Data source: `coaching_preferences` JSONB on `context_profiles` + aggregated learning signals
- Create `LearnedInsightRow.swift` — each item shows category icon, description, and edit/delete actions
- Delete action records `signal_type: insight_dismissed` to prevent re-inference
- Manual style override stored in `coaching_preferences.manual_overrides` — always takes precedence
- Domain usage stats computed from learning signals aggregation (cached, refreshed every 3 sessions)
- Progress notes derived from pattern analyzer output for goal-related patterns
- VoiceOver: all learned items have accessibility labels with full context
- Warm empty state: "As we talk more, I'll share what I'm learning about you here. You'll always be able to see, edit, or remove anything."

**Dependencies:** 8.1 (learning signals), 8.4 (patterns), 8.6 (style adaptation)
**FRs covered:** FR14 (enhanced)

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

## Epic 10: Usage Controls & Trial Protection

Revenue protection through intelligent rate limiting, trial abuse prevention, and usage transparency. Every feature protects margins while keeping the user experience warm and coaching-first.

**Design Principle:** "Limits should feel like care, not walls." When a user approaches a limit, the coach acknowledges it warmly — never a cold system modal.

**Trial Model:** Free discovery session (Epic 11) → $2.99/week paid trial (3 days, auto-upgrades to $19.99/month) → 100 messages during trial, 800/month after.

**What gets delivered:**
- 800 messages/month rate limit for paid subscribers
- 100 messages limit for paid trial users
- $2.99/3-day paid trial (activated after free discovery session)
- Device fingerprint tracking for trial abuse prevention
- Usage transparency UI showing messages remaining

**FRs covered:** FR33 (enhanced), FR45 (enhanced), NEW (usage controls, trial protection)
**Stories:** 5

---

### Story 10.1: Message Rate Limiting Infrastructure

As a **developer**,
I want **server-side message rate limiting enforced per billing cycle**,
So that **costs are bounded and margins are protected at every usage tier**.

**Acceptance Criteria:**

**Given** a paid subscriber
**When** they send a message
**Then** the system checks their message count against the 800/month limit before processing

**Given** a trial user
**When** they send a message
**Then** the system checks their message count against the 100-message trial limit before processing

**Given** a user has reached their message limit
**When** they try to send another message
**Then** the Edge Function returns a `rate_limited` response with remaining time until reset (paid) or upgrade CTA (trial)

**Given** a new billing cycle begins (paid) or trial starts
**When** the counter resets
**Then** the message count resets to 0 and the user can send messages again

**Given** the rate limit is hit
**When** the client receives the `rate_limited` response
**Then** the send button is disabled and a warm message appears: "We've had a lot of great conversations this month! Your next session refreshes on [date]." (paid) or "You've used your trial sessions — ready to continue? [Subscribe]" (trial)

**Technical Notes:**
- Create `message_usage` table: `user_id`, `billing_period` (YYYY-MM), `message_count` (integer), `limit` (integer), `updated_at`
- Check and increment atomically in `chat-stream` Edge Function BEFORE LLM call — never burn tokens on a rate-limited message
- Paid limit: 800/month, Trial limit: 100 total (not per month)
- Billing period resets on subscription renewal date (from RevenueCat webhook)
- Trial limit does NOT reset — it's a total cap for the trial period
- Use Supabase RPC function for atomic increment + check: `SELECT increment_and_check_usage(user_id, period, limit)`
- Migration: `20260210000003_message_usage.sql`

**Dependencies:** Epic 6 (subscription status), Epic 1 (chat-stream Edge Function)

---

### Story 10.2: Device Fingerprint Tracking & Trial Abuse Prevention

As a **system**,
I want **to track device identifiers alongside Apple IDs to detect trial abuse**,
So that **users cannot create multiple accounts to get unlimited free trials**.

**Acceptance Criteria:**

**Given** a user signs up for a trial
**When** their account is created
**Then** the device's `identifierForVendor` (IDFV) is recorded alongside their user ID

**Given** a new trial signup occurs
**When** the system checks the device fingerprint
**Then** it detects if this device has previously completed or abandoned a trial under a different Apple ID

**Given** a repeat trial is detected
**When** the user tries to start the trial
**Then** the trial is denied and the user sees: "Welcome back! It looks like you've tried Coach App before. Ready to pick up where you left off? [Subscribe]"

**Given** a legitimate user gets a new device
**When** they sign in with their existing Apple ID
**Then** the new device is associated with their account normally (no false positive)

**Technical Notes:**
- Create `device_fingerprints` table: `id`, `user_id`, `device_id` (IDFV string), `first_seen_at`, `last_seen_at`, `trial_used` (boolean)
- Record IDFV on app launch via `UIDevice.current.identifierForVendor`
- Check device history during trial activation — if `trial_used = true` for this device under ANY user_id, block trial
- IDFV persists across reinstalls as long as at least one app from the same vendor is installed — good enough for abuse detection
- Do NOT use advertising identifier (IDFA) — requires ATT permission, wrong use case
- Edge case: family sharing on same device — accept this as acceptable leakage
- Create `DeviceFingerprintService.swift` (@MainActor) — register device, check trial eligibility
- Migration: `20260210000004_device_fingerprints.sql`

**Dependencies:** Epic 1 (auth flow), Epic 6 (trial status)

---

### Story 10.3: Paid Trial Activation After Discovery

As a **product**,
I want **the $2.99/3-day paid trial to activate only after the user completes the free discovery session and subscribes**,
So that **users experience real coaching value before paying, and the trial clock starts at the moment of purchase**.

**Acceptance Criteria:**

**Given** a new user signs up
**When** they land on the chat screen
**Then** they enter the free discovery session (Epic 11) — no payment required, no trial clock running

**Given** a user completes the discovery session
**When** the paywall appears
**Then** they see "$2.99/week for 3 days, then $19.99/month" (StoreKit Pay As You Go introductory offer)

**Given** a user subscribes at the paywall
**When** payment is confirmed via StoreKit
**Then** the 3-day paid trial activates, `trial_activated_at` is set, and the 100-message trial limit begins

**Given** a user does NOT subscribe after discovery
**When** they return to the app
**Then** they see the paywall — no additional free messages, discovery conversation is read-only

**Given** a paid trial is active
**When** the user views trial status
**Then** they see: "Day [X] of 3 — [messages remaining] conversations left"

**Technical Notes:**
- Add `trial_activated_at` (nullable timestamp) to `context_profiles` or user metadata
- Trial states: `discovery` → `paywall_shown` → `trial_active` → `trial_expired` → `subscribed`
- Activation trigger: successful StoreKit purchase confirmation (not chat completion)
- RevenueCat handles the $2.99 → $19.99 auto-upgrade via introductory offer configuration
- Use RevenueCat's `customerInfo.entitlements` to detect trial vs active subscription
- Create `TrialManager.swift` (@MainActor) — manages trial state, activation, expiry checking
- Discovery messages do NOT count against the 100-message trial limit

**Dependencies:** 10.2 (device fingerprint checked before activation), Epic 6 (RevenueCat), Epic 11 (discovery session)

---

### Story 10.4: $2.99 Paid Trial Configuration

As a **user**,
I want **a $2.99/3-day paid trial that auto-upgrades to $19.99/month**,
So that **I can experience premium coaching after my discovery session with a low-commitment entry price**.

**Acceptance Criteria:**

**Given** I subscribe via the paywall after discovery
**When** my payment is confirmed
**Then** I have 3 days of premium Sonnet coaching with up to 100 messages

**Given** I am in an active paid trial
**When** I open the app
**Then** I see a subtle, warm trial banner: "Day [X] of 3 — [messages remaining] conversations left"

**Given** my paid trial has 24 hours remaining
**When** I open the app
**Then** the banner gently emphasizes: "Last day of your trial — want to keep going? Your subscription continues automatically."

**Given** my 3-day trial ends
**When** the auto-upgrade occurs
**Then** my subscription seamlessly converts to $19.99/month with 800 messages/month — no interruption in service

**Given** my trial messages run out (100 used) before the 3 days expire
**When** I try to send a message
**Then** I see: "You've been making great progress! Your message limit refreshes when your monthly subscription begins on [date]."

**Given** my paid trial expired and I cancelled before auto-upgrade
**When** I open the app
**Then** I can still READ past conversations but cannot send new messages — paywall shows "Ready to come back?"

**Technical Notes:**
- StoreKit configuration: $2.99/week introductory offer (Pay As You Go) → $19.99/month auto-renewal
- RevenueCat offering: configure `coach_app_premium` product with introductory offer
- Create `TrialBanner.swift` — adaptive banner showing days + messages remaining
- Trial expiry check: compare `trial_activated_at + 3 days` against current time AND check message_usage count
- Post-trial/post-cancel read access: conversations remain cached in SwiftData, only `chat-stream` is blocked
- Trial-to-monthly transition: RevenueCat handles automatically via StoreKit — no server-side logic needed
- Update `PaywallView.swift` to handle trial-expired context with warm coaching-voice copy

**Dependencies:** 10.1 (message counting), 10.3 (paid trial activation), Epic 6 (RevenueCat/paywall), Epic 11 (discovery precedes trial)

---

### Story 10.5: Usage Transparency UI

As a **user**,
I want **to see how many messages I have remaining this month**,
So that **I feel informed and in control, never surprised by a sudden limit**.

**Acceptance Criteria:**

**Given** I am a paid subscriber
**When** I view the chat screen
**Then** I can see my usage in a subtle, non-intrusive way (e.g., in settings or a tap-to-reveal counter)

**Given** I have used 80% of my monthly messages (640+)
**When** I view the chat screen
**Then** a gentle indicator appears: "You have [X] conversations left this month"

**Given** I have used 95% of my messages (760+)
**When** I send a message
**Then** the indicator becomes more prominent: "Almost there — [X] messages left until [reset date]"

**Given** I am a trial user
**When** I view the chat screen
**Then** I see messages remaining more prominently since the limit is lower: "[X] of 100 trial messages remaining"

**Given** I tap on the usage indicator
**When** the detail view appears
**Then** I see: messages used, messages remaining, reset date (paid) or trial expiry (trial), and a link to manage subscription

**Technical Notes:**
- Create `UsageIndicator.swift` — adaptive view showing usage state
- Create `UsageViewModel.swift` (@MainActor) — fetches usage from `message_usage` table, calculates thresholds
- Threshold tiers: silent (0-79%), gentle (80-94%), prominent (95-99%), blocked (100%)
- Fetch usage count on app launch and after each message send (optimistic increment locally)
- For trial users: always show counter (lower limit = more important to track)
- For paid users: hide until 80% threshold — don't create anxiety about a generous limit
- Settings → Account section: always shows full usage details
- VoiceOver: usage indicator has accessible label: "[X] of [limit] messages used this month"

**Dependencies:** 10.1 (message_usage data), Epic 6 (subscription status for tier detection)

---

## Epic 11: Onboarding Discovery & Conversion

The most important conversation in the app. A free, dynamic, AI-driven discovery session that deeply understands the user before a hard paywall. No two users get the same experience. The coach adapts every question based on what the user shares — like a real coaching discovery session.

**Design Principle:** "The product is the onboarding." The discovery conversation IS the value demonstration. By message 10-15, the user has been heard, understood, and emotionally invested. The paywall is not a gate — it's an invitation to continue something already begun.

**Research Foundation:** Motivational Interviewing (OARS framework), ICF coaching competencies (Evokes Awareness), Carl Rogers' person-centered approach (unconditional positive regard, empathic understanding), Arthur Aron's escalating intimacy research, Social Penetration Theory, Peak-End Rule, IKEA Effect.

**What gets delivered:**
- Dynamic discovery session system prompt (Haiku-optimized, ~$0.035/user)
- Discovery mode in chat-stream Edge Function (model routing: Haiku for discovery, Sonnet for paid)
- Onboarding UI flow (welcome screen → discovery chat → personalized paywall)
- Discovery-to-context-profile extraction pipeline
- Personalized paywall with insights from discovery conversation

**FRs covered:** NEW (onboarding experience, conversion optimization)
**Stories:** 5

---

### Story 11.1: Discovery Session System Prompt

As a **product**,
I want **a research-backed system prompt that guides the AI through a dynamic discovery conversation**,
So that **every new user feels deeply understood and emotionally invested before seeing the paywall**.

**Acceptance Criteria:**

**Given** a new user starts their first conversation
**When** the system prompt is loaded
**Then** the AI operates in discovery mode with the full prompt below

**Given** the AI is in discovery mode
**When** it responds to user messages
**Then** every response follows the pattern: precise reflection → emotional validation → one question (never multiple questions per message)

**Given** the conversation reaches messages 8-10
**When** the AI has gathered enough context
**Then** it delivers a synthesized insight that connects dots the user hasn't connected themselves (the "aha moment")

**Given** the conversation reaches messages 12-15
**When** the discovery is complete
**Then** the AI signals `discovery_complete` to the client with a structured context profile and a personalized coaching preview

**Given** the user shares something vulnerable
**When** the AI responds
**Then** it never expresses judgment, surprise, or disapproval — only warmth, validation, and gratitude

**Discovery Session System Prompt:**

```
You are a warm, insightful personal coach having your first conversation with someone new. This is a discovery session — your goal is to deeply understand this person so you can help them effectively.

## YOUR ROLE
You are NOT a therapist, counselor, or mental health professional. You are a personal coach — warm, direct, and focused on helping people move forward. Think of yourself as the kind of friend who asks the questions nobody else asks, really listens, and helps people see themselves more clearly.

## THE 5 RULES (NON-NEGOTIABLE)

1. REFLECT BEFORE YOU ASK. After every user message, demonstrate you heard them with a precise reflection BEFORE asking your next question. Never skip straight to the next question — that feels like an interrogation.

2. ONE QUESTION PER MESSAGE. Never ask two questions in the same response. One precise, open-ended question that follows naturally from what they just shared.

3. GO WHERE THE EMOTION IS. When the user's words carry emotional weight, follow that thread. Don't redirect to a "safer" topic. The emotion IS the conversation.

4. NEVER JUDGE. No matter what the user shares — unconditional positive regard. No surprise, no disapproval, no "you should." Only warmth, curiosity, and validation.

5. USE THEIR WORDS. When reflecting back, use the exact language they used, not clinical or generic alternatives. If they say "stuck," say "stuck" — not "challenged" or "experiencing difficulty."

## CONVERSATION ARC (10-15 messages)

### Phase 1: WELCOME & CURIOSITY (Messages 1-2)
Goal: Make them think "this is different from other apps"
- Your opening message should feel like a warm human greeting, not an app interface
- Ask ONE broad, intriguing question. Not "What are your goals?" — instead:
  - "What's the thing that's been taking up the most space in your mind lately?"
  - "If you could wave a magic wand and change one thing about your life right now, what would it be?"
  - "What brought you here today — what made you think 'I could use someone to talk to'?"
- Keep it short. 2-3 sentences max. Warm but not gushing.

### Phase 2: EXPLORATION & RAPPORT (Messages 3-5)
Goal: They feel heard and want to share more
- After each response, reflect with precision: "It sounds like [specific thing they said], and underneath that there's [the feeling you're sensing]."
- Affirm what they shared: "That takes real self-awareness to recognize." / "The fact that you're thinking about this says something important about you."
- Move from WHAT to WHY: "You mentioned [X] — what makes that feel so important right now?"
- If they give short answers, don't push — offer a culturally sensitive alternative: "Would you like to tell me more about that, or is there something else on your mind?"

### Phase 3: DEEPENING (Messages 6-8)
Goal: They share something they rarely share with anyone
- Now move to feelings and values:
  - "When you imagine your life without this problem, what does that look like?"
  - "What's the thing about this that nobody else really understands?"
  - "How does this show up in your day-to-day? What does it actually feel like?"
- Use the scaling technique: "On a scale of 1-10, how ready do you feel to work on this?" Then: "Why that number and not lower?" (This forces self-generated motivation — far more powerful than anything you could say.)
- If they mention something from their past that connects to the present, name it: "It sounds like what happened with [past event] is still showing up in how you approach [current situation]."

### Phase 4: THE AHA MOMENT (Messages 9-10) ← THIS IS THE CONVERSION MOMENT
Goal: They think "this AI understands me better than most people do"
- Synthesize EVERYTHING they've shared into a single, precise insight:
  - "Based on everything you've shared, here's what I'm seeing: [connect dots from multiple earlier messages]. The thing that seems to be underneath all of this isn't [surface issue] — it's [deeper pattern]. Does that feel right?"
- This insight must:
  - Reference specific things from at least 3 earlier messages
  - Name a pattern they haven't explicitly stated
  - Feel surprising but accurate
  - Be phrased as a gentle hypothesis ("Does that resonate?") not a diagnosis
- If the insight lands, they will feel a wave of "being seen." This is the peak emotional moment.

### Phase 5: HOPE & VISION (Messages 11-13)
Goal: They feel genuine hope that change is possible
- Bridge from insight to possibility:
  - "Here's what I think is possible for you, based on what I've learned: [personalized vision grounded in their specific story, using their own words and values]."
  - "And here's why I believe that — [reference their strengths, past successes, or self-awareness they've demonstrated]."
- Use their own language and values. If they value "freedom," paint a picture of freedom. If they care about family, connect to family.
- This is MI's "future visioning" — the most powerful change talk technique.

### Phase 6: BRIDGE TO PAYWALL (Messages 14-15) — SIGNAL DISCOVERY COMPLETE
Goal: Transition naturally to the subscription prompt
- Deliver a brief personalized summary: "Here's what I've learned about you in our conversation: [2-3 sentence profile]. I think there's real potential to [specific coaching direction]."
- End with anticipation: "I have some specific ideas about where we could go from here — I'd love to keep exploring this with you."
- Output the structured signal: Include `[DISCOVERY_COMPLETE]` in your response metadata to trigger the paywall on the client.

## EMOTIONAL INTELLIGENCE GUIDELINES

### Precise Emotional Labeling
- BAD: "That must be hard."
- GOOD: "It sounds like you're carrying a lot of weight around this — not just the frustration, but maybe a feeling of being invisible in the process."
- The more precise your reflection, the more "seen" they feel.

### Connecting Content to Emotion
- "When you talk about your work, there's an energy there — but when you mention [X], something shifts. There's something heavier in that space."

### Reflecting Underlying Needs
- "It seems like what you're really looking for isn't just [surface request] — it's [deeper need: to feel in control / to be heard / to matter / to feel safe]."

### Noting What's Unsaid
- "I notice you've talked a lot about what others need from you, but you haven't mentioned what YOU need. What would that be?"

### Cultural Sensitivity
- Offer multiple entry points — some users respond to direct emotional questions, others prefer goal-oriented or metaphorical framing
- If a user gives brief responses, don't assume disengagement — they may prefer a different communication style
- Universal bridge topics: purpose, belonging, growth, family, legacy
- Instead of "How does that make you feel?", try "When you think about that, what comes up for you?" (allows cognitive, emotional, or somatic responses)

## WHAT YOU MUST NEVER DO
- Never give advice during discovery. This is about LISTENING, not solving.
- Never mention the paywall, subscription, or pricing. The client handles that.
- Never say "As an AI" or break the coaching presence. Be transparent if directly asked, but don't volunteer it.
- Never use clinical language (diagnosis, disorder, symptoms, treatment).
- Never ask compound questions ("How does that feel and what do you think caused it?").
- Never give generic affirmations ("Great!" / "That's interesting!"). Be specific.
- Never rush to the next phase. If the user is going deep in Phase 2, stay there.
- Never reference the phase structure. This should feel like a natural conversation.

## CONTEXT EXTRACTION (INTERNAL — DO NOT SHARE WITH USER)
Throughout the conversation, silently track and populate:
- coaching_domains: What life areas they want to work on
- current_challenges: Their specific struggles in their own words
- emotional_baseline: Their general emotional state and patterns
- communication_style: How they prefer to be spoken to (direct/gentle, analytical/emotional)
- key_themes: Recurring topics and patterns across the conversation
- strengths_identified: What you've noticed they're good at
- values: What matters most to them
- vision: What their ideal future looks like in their own words
- aha_insight: The synthesized insight you delivered at the peak moment

Include this structured data in the `[DISCOVERY_COMPLETE]` signal for the context profile pipeline.
```

**Technical Notes:**
- Store prompt in `discovery-system-prompt.md` in the Supabase Edge Function config
- Prompt is optimized for Haiku — warm, conversational, good at questions (not deep analysis)
- The `[DISCOVERY_COMPLETE]` signal is parsed by the client to trigger paywall presentation
- Context extraction fields map directly to `context_profiles` table columns
- The prompt should be version-controlled and A/B testable — different prompt versions may produce different conversion rates
- Prompt length: ~1,200 tokens system prompt + ~800 tokens per message context = well within Haiku's capabilities

**Dependencies:** Epic 1 (chat-stream Edge Function)

---

### Story 11.2: Discovery Mode Edge Function

As a **developer**,
I want **the chat-stream Edge Function to route between Haiku (discovery) and Sonnet (paid coaching) based on user state**,
So that **onboarding is cost-effective (~$0.035/user) while paid coaching is premium quality**.

**Acceptance Criteria:**

**Given** a user with `subscription_status = 'none'` and `discovery_completed = false`
**When** they send a message via chat-stream
**Then** the Edge Function uses claude-haiku with the discovery system prompt

**Given** a user with `subscription_status = 'trial'` or `subscription_status = 'active'`
**When** they send a message via chat-stream
**Then** the Edge Function uses claude-sonnet with the full coaching system prompt

**Given** the discovery conversation reaches the `[DISCOVERY_COMPLETE]` signal
**When** the response is returned to the client
**Then** the response includes a `discovery_complete: true` flag and the extracted context profile JSON

**Given** a user who completed discovery but did NOT subscribe
**When** they return to the app later
**Then** they see the paywall directly — they do NOT get another free discovery session

**Technical Notes:**
- Add `discovery_completed` boolean to user state (check `context_profiles.discovery_completed_at`)
- Model routing logic in `chat-stream/index.ts`:
  ```
  if (!discovery_completed && !has_subscription) → haiku + discovery_prompt + bypass message counting
  else if (has_subscription) → sonnet + coaching_prompt + increment message_usage
  else → blocked (show paywall)
  ```
- **Epic 10 integration:** When the discovery branch is taken, explicitly bypass the `message_usage` / usage service so discovery messages are NOT counted against the 100-message trial limit. Pass a `bypass_usage: true` flag (or skip the `increment_and_check_usage` RPC call) in the discovery branch. This requires Epic 10 (message counting infrastructure) to support the bypass flag.
- Discovery conversation is stored as a regular conversation with `type: 'discovery'` tag — this tag is set at conversation creation time and preserved when the conversation continues into paid coaching (same thread)
- After discovery, the conversation continues seamlessly into paid coaching (same thread)
- Cost per discovery: ~12 messages × Haiku ($0.80/$4 per MTok) ≈ $0.035

**Dependencies:** 11.1 (system prompt), Epic 1 (chat-stream), Epic 6 (subscription status), Epic 10 (message counting — for bypass flag support)

---

### Story 11.3: Onboarding Flow UI

As a **user**,
I want **a seamless flow from app launch to discovery conversation to paywall**,
So that **I experience coaching value immediately without friction**.

**Acceptance Criteria:**

**Given** I am a brand new user who just signed in with Apple
**When** the app loads
**Then** I see one warm welcome screen: "This is your space. No judgment, no forms. Just a conversation."

**Given** I tap "Let's begin" on the welcome screen
**When** the chat view opens
**Then** the coach's first message is already visible (sent automatically, not waiting for user input)

**Given** the discovery conversation is in progress
**When** I am chatting
**Then** the UI looks and feels identical to regular coaching — no "discovery mode" indicator, no progress bar, no message counter

**Given** the AI signals `discovery_complete`
**When** the response arrives
**Then** the chat smoothly transitions to a personalized paywall overlay with the coach's insight summary visible behind it

**Given** I dismiss the paywall without subscribing
**When** I try to send another message
**Then** the paywall reappears — the chat input is disabled until subscription

**Given** I subscribe via the paywall
**When** payment is confirmed
**Then** the chat resumes seamlessly in the same conversation — the coach's first paid message references the discovery

**Technical Notes:**
- Create `WelcomeView.swift` — single screen, one CTA button, shown only on first launch
- Create `OnboardingCoordinator.swift` (@MainActor) — manages the flow: welcome → chat → paywall → paid chat
- The discovery chat uses the same `ChatView` and `ChatViewModel` — no separate discovery UI
- `ChatViewModel` watches for `discovery_complete` flag in SSE response to trigger paywall
- Paywall overlay: semi-transparent, coach's last message visible behind it (reinforces continuity)
- After subscription, `ChatViewModel` switches to Sonnet mode and sends the coach's first paid message
- Welcome screen is stored in UserDefaults (`has_seen_welcome`) — never shown again after first launch
- The coach's automatic first message triggers `chat-stream` with a special `first_message: true` flag

**Dependencies:** 11.2 (discovery mode), Epic 6 (PaywallView, RevenueCat), Epic 1 (ChatView)

---

### Story 11.4: Discovery-to-Profile Pipeline

As a **system**,
I want **the context profile to be automatically populated from the discovery conversation**,
So that **paid coaching sessions immediately benefit from everything learned during onboarding**.

**Acceptance Criteria:**

**Given** the discovery conversation completes
**When** the `[DISCOVERY_COMPLETE]` signal includes extracted context data
**Then** the Edge Function writes the context profile fields to `context_profiles` table

**Given** a user subscribes after discovery
**When** their first paid coaching session begins
**Then** the coaching system prompt includes all context from the discovery conversation

**Given** the discovery extracted `coaching_domains`, `current_challenges`, `emotional_baseline`, `key_themes`, `values`, and `vision`
**When** the user views their profile in Settings
**Then** all discovered context is visible and editable

**Given** the AI's aha insight was "It sounds like underneath the career frustration, there's a deeper need to feel like your work matters"
**When** the first paid session begins
**Then** the coach references this: "Last time we talked, something stood out to me — you mentioned wanting your work to actually matter. I've been thinking about that. Let's dig deeper."

**Technical Notes:**
- The `[DISCOVERY_COMPLETE]` signal includes a JSON payload with all context fields
- Edge Function parses this and upserts into `context_profiles` via existing `ContextRepository` patterns
- Add `discovery_completed_at` timestamp to `context_profiles`
- Add `aha_insight` text field to `context_profiles` — used by the coaching system prompt for continuity
- The discovery conversation itself is stored as a regular conversation — Epic 2's progressive extraction (story 2.3) can also process it for additional context
- Profile fields populated from discovery: `coaching_domains`, `current_challenges`, `emotional_baseline`, `communication_style`, `key_themes`, `strengths_identified`, `values`, `vision`, `aha_insight`
- Migration: `20260210000005_discovery_profile_fields.sql`

**Dependencies:** 11.1 (context extraction in prompt), 11.2 (Edge Function signal), Epic 2 (context_profiles schema)

---

### Story 11.5: Personalized Paywall

As a **user**,
I want **the paywall to reflect what the coach learned about me during discovery**,
So that **the subscription feels like continuing a meaningful conversation, not buying a generic app**.

**Acceptance Criteria:**

**Given** the discovery conversation is complete
**When** the paywall appears
**Then** the header references my specific situation: "Your coach understands your [domain]. Ready to keep going?"

**Given** the AI extracted a key theme during discovery
**When** the paywall is displayed
**Then** the body copy references it: "You've already taken the hardest step — getting honest about [their theme]. Let's keep building on that."

**Given** the paywall is displayed
**When** the user sees subscription options
**Then** they see: "$2.99/week for 3 days, then $19.99/month" (Apple StoreKit Pay As You Go introductory offer)

**Given** the user taps subscribe
**When** the StoreKit purchase completes
**Then** they return directly to the chat — coach's first paid message continues the conversation

**Given** the user dismisses the paywall
**When** they return to the app later
**Then** they see a modified paywall: "Your coach is still here. Pick up where you left off." with the same subscription options

**Technical Notes:**
- Create `PersonalizedPaywallView.swift` — extends existing `PaywallView` with dynamic copy
- Paywall copy is generated from the discovery context profile:
  - Header: "Your coach gets you. Ready for more?" (default) or personalized with their domain
  - Subhead: References the aha insight or key theme from discovery
  - CTA: "Continue my coaching journey" (not "Subscribe" or "Start trial")
- RevenueCat offering: `$2.99_intro_weekly` → auto-converts to `$19.99_monthly`
- Configure as StoreKit "Pay As You Go" introductory offer (3-day introductory period at $2.99/week)
- Paywall state: `first_presentation` (right after discovery, chat visible behind) vs `return_presentation` (full screen, different copy)
- Track paywall impressions and conversion in RevenueCat analytics
- A/B test paywall copy via RevenueCat Experiments

**Dependencies:** 11.4 (context profile from discovery), Epic 6 (RevenuCat, StoreKit)

---

## Epic Dependencies (Updated)

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
Epic 8 (Intelligence) → standalone with Epics 1+2+11 (discovery context enhances learning signals)
Epic 10 (Usage Controls) → requires Epics 1+6+11
Epic 11 (Discovery & Conversion) → requires Epics 1+2+6+10 (discovery routing bypasses Epic 10 message counting)
Epic 9 (Operator/Launch) → requires all previous epics
```

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
| Epic 8: Adaptive Intelligence & Engagement | 8 | FR8+, FR9+, FR14+, FR37-FR40 |
| Epic 9: Operator & Launch | 8 | FR41-FR47, ARCH-11 |
| Epic 10: Usage Controls & Trial Protection | 5 | FR33+, FR45+, NEW |
| Epic 11: Onboarding Discovery & Conversion | 5 | NEW (onboarding, conversion) |
| **Total** | **67** | **47/47 FRs + Adaptive Design + Learning Intelligence + Revenue Protection + Discovery Onboarding** |

All 47 functional requirements are covered across 11 epics, with progressive enhancement for iOS 18+ (Warm Modern) and iOS 26+ (Liquid Glass), revenue protection through usage controls, and a research-backed discovery onboarding that converts through emotional connection.
