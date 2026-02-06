---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - 'prd.md'
  - 'product-brief-Coach App-2026-01-27.md'
workflowType: 'architecture'
lastStep: 8
status: 'complete'
completedAt: '2026-02-05'
project_name: 'Coach App'
user_name: 'Sumanth'
date: '2026-02-05'
pivotNote: 'Native iOS with progressive enhancement: iOS 18+ minimum, Liquid Glass on iOS 26+, Warm Modern fallback'
---

# Architecture Decision Document

_This document defines the complete technical architecture for Coach App as a native iOS application built with Swift and SwiftUI, with progressive enhancement supporting iOS 18+ (Warm Modern design) and iOS 26+ (Liquid Glass design)._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
47 FRs across 8 capability areas defining the complete capability contract. The heaviest architectural investment falls in three areas: (1) Coaching Conversation (FR1-FR9) — real-time streaming, domain routing, pattern recognition, and cross-domain synthesis; (2) Personal Context (FR10-FR15) — the persistent context layer that is the product's core differentiator; and (3) Adaptive Design System — supporting both iOS 26 Liquid Glass and iOS 18-25 Warm Modern experiences.

**Non-Functional Requirements:**
36 NFRs define quality thresholds. The most architecturally constraining are: 500ms time-to-first-token (NFR1), 100ms domain routing (NFR3), provider-agnostic LLM integration (NFR31), zero data loss for personal context (NFR35), 60fps animations on both iOS tiers (NFR6), and WCAG 2.1 AA accessibility with VoiceOver support (NFR25-NFR30).

**Scale & Complexity:**

- Primary domain: Native iOS with AI integration
- Complexity level: Medium-High
- Estimated architectural components: 10-12 major components (auth, context engine, coaching engine, domain router, LLM abstraction, streaming layer, creator system, StoreKit integration, push notification service, offline/sync layer, crisis detection, operator dashboard)

### Technical Constraints & Dependencies

- **Solo developer** — architecture must minimize operational complexity and favor managed services
- **iOS 18+ minimum** — broad market reach (~90% of devices), progressive enhancement for iOS 26+
- **Native iOS only** — Swift 6 + SwiftUI, no cross-platform frameworks
- **Adaptive design system** — runtime version detection for Liquid Glass (iOS 26+) vs Warm Modern (iOS 18-25)
- **Supabase for backend** — PostgreSQL, Auth, Edge Functions (works great with iOS)
- **RevenueCat for subscriptions** — unified layer handling Apple IAP with subscription lifecycle management
- **LLM API dependency** — core product functionality requires external LLM provider; architecture must abstract this dependency
- **Zero-retention LLM policy** — chosen providers must not train on user data
- **App Store compliance** — AI content disclosure, account deletion, privacy nutrition labels

### Cross-Cutting Concerns Identified

| Concern | Affected Components | Architectural Implication |
|---|---|---|
| **Personal context injection** | Every coaching response | Context retrieval must be fast (<200ms) and reliable; prompt construction must include user profile + relevant history |
| **Adaptive design system** | All UI components | Runtime iOS version detection; Liquid Glass (iOS 26+) vs Warm Modern (iOS 18-25) |
| **Authentication** | All user-facing features | Sign in with Apple + biometric unlock, session management |
| **Content safety** | All coaching interactions | Crisis detection pipeline must intercept before response delivery |
| **Error handling / degradation** | LLM calls, payments, push, sync | Every external dependency needs fallback behavior |
| **Cost management** | LLM calls, monitoring | Per-user API cost tracking embedded in backend |
| **Security** | Storage, transport, auth, logging | AES-256 at rest, TLS 1.3 in transit, no PII in logs |
| **Offline capability** | Conversations, context, sync | Local storage with sync-on-reconnect |

## Technology Stack

### Full Technology Stack Summary

| Layer | Technology | Version |
|---|---|---|
| **Language** | Swift | 6.0 |
| **UI Framework** | SwiftUI | iOS 18+ |
| **Design System** | Adaptive (Liquid Glass / Warm Modern) | iOS 26+ / iOS 18-25 |
| **iOS Minimum** | iOS | 18.0 |
| **iOS Recommended** | iOS | 26.0+ |
| **Architecture Pattern** | MVVM + Repository | Clean architecture |
| **Async/Concurrency** | Swift Concurrency | async/await, actors |
| **Backend / Database** | Supabase (PostgreSQL) | Latest |
| **Auth** | Sign in with Apple + Supabase Auth | Native + backend sync |
| **Backend Functions** | Supabase Edge Functions (Deno) | Latest |
| **Payments** | RevenueCat + StoreKit 2 | Latest |
| **Push Notifications** | APNs + Supabase | Native |
| **Local Storage** | SwiftData + Keychain | iOS 18+ |
| **Networking** | URLSession + SSE | Native |
| **Error Tracking** | Sentry iOS SDK | Latest |

### Technology Selection Rationale

**Swift 6 + SwiftUI:**
- iOS 26 Liquid Glass support via `.glassEffect()` modifier with graceful fallback
- iOS 18-25 uses standard SwiftUI materials (`.ultraThinMaterial`, etc.)
- Swift Concurrency (async/await, actors) for streaming and network operations
- SwiftData for local persistence with automatic CloudKit sync capability
- Best performance and smallest app size for iOS

**Supabase:**
- PostgreSQL database with Row Level Security
- Works excellently with iOS via REST API
- Edge Functions for server-side LLM orchestration
- Built-in auth that syncs with Sign in with Apple
- Cost-effective for solo developer

**RevenueCat:**
- Abstracts StoreKit complexity
- Handles subscription lifecycle (purchase, renewal, cancellation, refund)
- Server-side receipt validation
- Analytics and monitoring built-in

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Data model structure (relational + JSONB in Supabase PostgreSQL)
- Authentication flow (Sign in with Apple + Supabase Auth sync)
- LLM streaming architecture (Edge Function SSE proxy)
- MVVM + Repository pattern for clean separation

**Important Decisions (Shape Architecture):**
- SwiftData for local persistence
- Keychain for secure credential storage
- Combine/AsyncSequence for reactive data flow
- Sentry for error tracking

**Deferred Decisions (Post-MVP):**
- CloudKit sync (can add later if needed)
- Advanced offline capabilities (conflict resolution)
- Multi-provider LLM failover

### Data Architecture

**Backend Database:** Supabase PostgreSQL (managed)

**Data Modeling Approach:** Relational model with JSONB for flexible fields.

Core tables:
- `users` — standard user record, linked to Supabase Auth (syncs with Sign in with Apple)
- `context_profiles` — one per user; JSONB columns for `values`, `goals`, `situation`
- `conversations` — linked to user; `domain` enum column for coaching domain classification
- `messages` — linked to conversation; stores role (user/assistant), content, timestamps, token counts
- `coaching_personas` — creator-defined configs; JSONB for `domain`, `tone`, `methodology`, `personality`
- `usage_logs` — per-request LLM cost tracking (model, tokens_in, tokens_out, cost_usd, user_id)

**Local Storage (iOS):**
- **SwiftData:** Conversations, messages, context profile cache for offline access
- **Keychain:** Auth tokens, sensitive credentials via `Security` framework
- **UserDefaults:** Non-sensitive preferences (theme, notification settings)

**Data Validation:**
- Swift `Codable` with custom validation in models
- Supabase RLS for row-level authorization

**Caching Strategy:**
- Server-side: Supabase built-in connection pooling
- Client-side: SwiftData local cache with sync-on-reconnect
- Network: URLCache for API responses with appropriate cache headers

### Authentication & Security

**Auth Flow:**
1. User taps "Sign in with Apple"
2. iOS presents Sign in with Apple sheet
3. On success, receive Apple ID credential with user identifier and identity token
4. Send identity token to Supabase Edge Function for verification
5. Edge Function creates/updates Supabase user, returns Supabase session
6. Store Supabase tokens in Keychain
7. Subsequent launches: check Keychain, refresh Supabase session if needed

**Biometric Unlock:**
1. After initial auth, prompt to enable Face ID / Touch ID
2. Store encrypted session reference in Keychain with biometric protection
3. On app launch: verify biometric → unlock Keychain → restore session

**Authorization:**
- Supabase Row Level Security (RLS) policies on all tables
- Users can only read/write their own data
- Creator personas readable by anyone (shared links), editable only by creator

**Security Measures:**
- System prompts stored server-side in Edge Functions, never in client
- User input sanitized before inclusion in LLM prompts
- Creator persona configs validated and sandboxed
- JWT tokens with automatic refresh
- AES-256 encryption at rest (Supabase default)
- TLS 1.3 for all data in transit
- No PII in application logs (Sentry configured to scrub)

### API & Communication Patterns

**API Design:** Hybrid approach.
- **Supabase REST API:** CRUD operations for conversations, messages, context profiles, creator personas
- **Supabase Edge Functions:** Business logic: LLM streaming, domain routing, context injection, crisis detection, cost tracking, push triggers

**Real-Time Streaming Architecture (Critical Path):**

```
iOS App → POST /functions/v1/chat-stream → Edge Function
  1. Verify auth token, extract user ID
  2. Load user context profile from PostgreSQL (<200ms)
  3. Load recent conversation history
  4. Classify coaching domain (<100ms, NLP classification)
  5. Load domain config (tone, methodology, system prompt)
  6. Construct full prompt: system + domain + context + history + message
  7. Run crisis detection on user message (pre-response safety check)
  8. Call LLM API with streaming enabled
  9. Proxy SSE stream back to client (token-by-token)
  10. On stream complete: save assistant message to database, log usage/cost
iOS App ← SSE stream ← Edge Function
```

**iOS SSE Client Implementation:**

```swift
// Using URLSession with AsyncBytes for SSE
func streamChat(message: String) -> AsyncThrowingStream<ChatToken, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let request = buildStreamRequest(message: message)
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    if let token = parseToken(data) {
                        continuation.yield(token)
                    }
                }
            }
            continuation.finish()
        }
    }
}
```

**Error Handling:**
- Edge Functions: return standardized `{ data, error }` JSON response
- iOS: Swift `Result` type for all async operations
- User-facing errors: warm, first-person messages ("I couldn't connect right now")
- LLM failures: "Coach is taking a moment. Let's try again." within 3 seconds
- Stream interruption: display partial response + retry button

**Rate Limiting:**
- Supabase built-in rate limiting for API endpoints
- Custom per-user rate limiting in Edge Functions
- Per-user API cost tracking with alerts

### Frontend Architecture (iOS)

**Architecture Pattern:** MVVM + Repository

```
┌─────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                             │
│  └── Observe @Observable ViewModels                          │
│      └── ViewModels call Repository methods                  │
│          └── Repositories abstract data sources              │
│              ├── Remote: Supabase API                        │
│              └── Local: SwiftData                            │
└─────────────────────────────────────────────────────────────┘
```

**State Management:**
- **@Observable** (iOS 17+) for ViewModels — cleaner than @ObservableObject
- **SwiftData** for local persistence with automatic change tracking
- **@Environment** for dependency injection (repositories, services)
- **Actor-based services** for thread-safe shared state

**Adaptive Design System Implementation:**

The design system uses runtime version detection to apply appropriate styling:

```swift
// Core adaptive styling modifier
extension View {
    @ViewBuilder
    func adaptiveGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    func adaptiveInteractiveGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.interactive())
        } else {
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
    }
}

// Navigation elements with adaptive styling
struct ChatToolbar: View {
    var body: some View {
        HStack {
            Button(action: showHistory) {
                Image(systemName: "clock")
            }
            .adaptiveInteractiveGlass()

            Spacer()

            Button(action: newConversation) {
                Image(systemName: "plus")
            }
            .adaptiveInteractiveGlass()
        }
        .padding()
    }
}

// Grouping elements with adaptive container
struct ActionBar: View {
    var body: some View {
        AdaptiveGlassContainer {
            HStack(spacing: 12) {
                Button("Voice") { ... }
                    .adaptiveGlass()
                Button("Send") { ... }
                    .adaptiveGlass()
                    .tint(.accent) // Call-to-action
            }
        }
    }
}

// AdaptiveGlassContainer wraps GlassEffectContainer on iOS 26+
struct AdaptiveGlassContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { content }
        } else {
            content
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

**Accessibility Integration:**

```swift
// Both iOS 26 Liquid Glass and iOS 18-25 materials automatically handle:
// - Reduced Transparency: increases frosting/opacity
// - Increased Contrast: uses stark colors/borders
// - Reduced Motion: tones down animations

// Custom accessibility (works on all iOS versions)
Text(message.content)
    .accessibilityLabel(message.accessibilityDescription)
    .accessibilityHint("Double tap to copy")
```

### Project Structure

```
CoachApp/
├── CoachApp.swift                    # App entry point
├── Info.plist
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   ├── Colors/                       # Warm color palette
│   └── Images/
│
├── App/                              # App-level configuration
│   ├── AppDelegate.swift             # Push notifications setup
│   ├── SceneDelegate.swift
│   ├── Environment/
│   │   ├── AppEnvironment.swift      # Dependency container
│   │   └── Configuration.swift       # Environment-specific config
│   └── Navigation/
│       ├── Router.swift              # Navigation coordinator
│       └── DeepLinkHandler.swift     # Universal links for sharing
│
├── Features/                         # Feature modules
│   ├── Chat/
│   │   ├── Views/
│   │   │   ├── ChatView.swift        # Main chat screen
│   │   │   ├── MessageBubble.swift   # Chat bubble with glass effects
│   │   │   ├── StreamingText.swift   # Token-by-token rendering
│   │   │   ├── MessageInput.swift    # Text + voice input
│   │   │   └── TypingIndicator.swift
│   │   ├── ViewModels/
│   │   │   └── ChatViewModel.swift
│   │   └── Models/
│   │       └── ChatMessage.swift
│   │
│   ├── Context/
│   │   ├── Views/
│   │   │   ├── ContextProfileView.swift
│   │   │   ├── ContextEditorSheet.swift
│   │   │   └── ContextPromptSheet.swift  # "Remember what matters" prompt
│   │   ├── ViewModels/
│   │   │   └── ContextViewModel.swift
│   │   └── Models/
│   │       └── ContextProfile.swift
│   │
│   ├── History/
│   │   ├── Views/
│   │   │   ├── HistoryView.swift
│   │   │   └── ConversationRow.swift
│   │   └── ViewModels/
│   │       └── HistoryViewModel.swift
│   │
│   ├── Creator/
│   │   ├── Views/
│   │   │   ├── CreatorDashboard.swift
│   │   │   ├── PersonaFormSheet.swift
│   │   │   └── ShareLinkView.swift
│   │   ├── ViewModels/
│   │   │   └── CreatorViewModel.swift
│   │   └── Models/
│   │       └── CoachingPersona.swift
│   │
│   ├── Auth/
│   │   ├── Views/
│   │   │   ├── WelcomeView.swift
│   │   │   ├── SignInWithAppleButton.swift
│   │   │   └── BiometricPromptView.swift
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   └── Services/
│   │       ├── AuthService.swift
│   │       └── BiometricService.swift
│   │
│   ├── Subscription/
│   │   ├── Views/
│   │   │   ├── PaywallView.swift
│   │   │   ├── TrialBanner.swift
│   │   │   └── SubscriptionManagement.swift
│   │   ├── ViewModels/
│   │   │   └── SubscriptionViewModel.swift
│   │   └── Services/
│   │       └── RevenueCatService.swift
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   │   ├── SettingsView.swift
│   │   │   ├── NotificationSettings.swift
│   │   │   └── AccountDeletion.swift
│   │   └── ViewModels/
│   │       └── SettingsViewModel.swift
│   │
│   ├── Safety/
│   │   ├── Views/
│   │   │   ├── CrisisResourceSheet.swift  # Warm glass container
│   │   │   └── DisclaimerView.swift
│   │   └── Services/
│   │       └── CrisisDetectionService.swift
│   │
│   └── Operator/                     # Admin-only screens
│       ├── Views/
│       │   ├── DashboardView.swift
│       │   ├── MetricsView.swift
│       │   └── DomainConfigView.swift
│       └── ViewModels/
│           └── OperatorViewModel.swift
│
├── Core/                             # Shared infrastructure
│   ├── UI/
│   │   ├── Components/
│   │   │   ├── AdaptiveButton.swift  # Version-adaptive button
│   │   │   ├── AdaptiveCard.swift    # Version-adaptive card
│   │   │   ├── AdaptiveGlassContainer.swift  # Wraps GlassEffectContainer
│   │   │   ├── WarmTextField.swift
│   │   │   └── LoadingSpinner.swift
│   │   ├── Modifiers/
│   │   │   ├── AdaptiveGlassModifiers.swift  # .adaptiveGlass(), .adaptiveInteractiveGlass()
│   │   │   ├── VersionDetection.swift  # iOS version utilities
│   │   │   └── AccessibilityModifiers.swift
│   │   └── Theme/
│   │       ├── Colors.swift          # Warm color palette (shared)
│   │       ├── Typography.swift      # Dynamic Type support
│   │       ├── Spacing.swift
│   │       └── DesignSystem.swift    # Adaptive design system coordinator
│   │
│   ├── Data/
│   │   ├── Repositories/
│   │   │   ├── ConversationRepository.swift
│   │   │   ├── ContextRepository.swift
│   │   │   ├── PersonaRepository.swift
│   │   │   └── UserRepository.swift
│   │   ├── Local/
│   │   │   ├── SwiftDataModels.swift  # @Model definitions
│   │   │   └── ModelContainer+Extension.swift
│   │   └── Remote/
│   │       ├── SupabaseClient.swift
│   │       ├── APIEndpoints.swift
│   │       └── NetworkMonitor.swift
│   │
│   ├── Services/
│   │   ├── ChatStreamService.swift    # SSE streaming client
│   │   ├── DomainRoutingService.swift
│   │   ├── PushNotificationService.swift
│   │   ├── OfflineSyncService.swift
│   │   └── CostTrackingService.swift
│   │
│   ├── Utilities/
│   │   ├── Logger.swift              # No PII logging
│   │   ├── KeychainManager.swift
│   │   ├── DateFormatter+Extensions.swift
│   │   └── String+Extensions.swift
│   │
│   └── Constants/
│       ├── AppConstants.swift
│       ├── DomainConfigs.swift       # 7 coaching domains
│       └── CrisisResources.swift     # 988, Crisis Text Line
│
├── Resources/
│   ├── DomainConfigs/                # JSON configs for coaching domains
│   │   ├── life-coaching.json
│   │   ├── career-coaching.json
│   │   ├── relationships.json
│   │   ├── mindset.json
│   │   ├── creativity.json
│   │   ├── fitness.json
│   │   └── leadership.json
│   └── Localizable.strings
│
├── Supabase/                         # Backend (version-controlled)
│   ├── functions/
│   │   ├── _shared/
│   │   │   ├── cors.ts
│   │   │   ├── auth.ts
│   │   │   ├── response.ts
│   │   │   ├── llm-client.ts         # Provider-agnostic LLM
│   │   │   ├── domain-router.ts
│   │   │   ├── crisis-detector.ts
│   │   │   ├── context-loader.ts
│   │   │   ├── prompt-builder.ts
│   │   │   └── cost-tracker.ts
│   │   ├── chat-stream/
│   │   │   └── index.ts              # Main coaching chat
│   │   ├── extract-context/
│   │   │   └── index.ts
│   │   ├── push-trigger/
│   │   │   └── index.ts
│   │   └── webhook-revenuecat/
│   │       └── index.ts
│   ├── migrations/
│   │   ├── 00001_initial_schema.sql
│   │   ├── 00002_coaching_personas.sql
│   │   ├── 00003_usage_logs.sql
│   │   ├── 00004_rls_policies.sql
│   │   ├── 00005_indexes.sql
│   │   └── 00006_push_tokens.sql
│   └── seed.sql
│
└── Tests/
    ├── Unit/
    │   ├── ViewModels/
    │   ├── Services/
    │   └── Repositories/
    ├── Integration/
    │   ├── SupabaseIntegrationTests.swift
    │   └── StreamingTests.swift
    └── UI/
        ├── ChatFlowTests.swift
        └── AuthFlowTests.swift
```

### Infrastructure & Deployment

**Build & Distribution:**
- Xcode 16+ for iOS 26 SDK (supports iOS 18+ deployment target)
- TestFlight for beta distribution (test on both iOS 18 and iOS 26 devices)
- App Store Connect for production release
- Fastlane for CI/CD automation (optional)

**Environment Configuration:**
- Xcode Schemes: Development, Staging, Production
- `.xcconfig` files for environment-specific values
- Secrets in Xcode Cloud / CI environment variables
- Never commit API keys to repository

**Monitoring & Logging:**
- **Sentry iOS SDK** for crash reporting and error tracking (NFR)
- **RevenueCat Dashboard** for subscription analytics
- **Supabase Dashboard** for database metrics, auth events, Edge Function logs
- **Custom `usage_logs` table** for per-user LLM cost tracking
- **No PII in logs** — Sentry configured to scrub sensitive data

**Scaling Strategy:**
- Database: Supabase plan tier upgrades
- LLM costs: monitored per-request, rate-limited per-user
- No self-managed infrastructure — fully managed services

## Implementation Patterns & Consistency Rules

### Naming Patterns

**Database Naming (PostgreSQL/Supabase):**
- Tables: `snake_case`, plural — `users`, `conversations`, `messages`
- Columns: `snake_case` — `user_id`, `created_at`, `token_count`
- Foreign keys: `{referenced_table_singular}_id` — `user_id`, `conversation_id`
- Indexes: `idx_{table}_{column}`
- Enums: `snake_case` values — `life_coaching`, `career_coaching`

**Swift Naming:**
- Types: `PascalCase` — `ChatMessage`, `ContextProfile`, `CoachingPersona`
- Properties/methods: `camelCase` — `messageContent`, `sendMessage()`
- Constants: `camelCase` — `maxTokens`, `coachingDomains`
- File names: Match type name — `ChatMessage.swift`, `ChatViewModel.swift`

**API Communication:**
- JSON fields: `camelCase` in Swift, `snake_case` in database
- Use `CodingKeys` for transformation

```swift
struct ChatMessage: Codable {
    let id: UUID
    let conversationId: UUID
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case content
        case createdAt = "created_at"
    }
}
```

### Structure Patterns

**Feature Module Pattern:**
Each feature is self-contained with Views, ViewModels, Models, and optionally Services.

```
Feature/
├── Views/           # SwiftUI views
├── ViewModels/      # @Observable view models
├── Models/          # Feature-specific models
└── Services/        # Feature-specific services (optional)
```

**Repository Pattern:**
Repositories abstract data sources, providing a clean interface for ViewModels.

```swift
protocol ConversationRepositoryProtocol {
    func getConversations() async throws -> [Conversation]
    func getConversation(id: UUID) async throws -> Conversation
    func createConversation() async throws -> Conversation
    func deleteConversation(id: UUID) async throws
}

final class ConversationRepository: ConversationRepositoryProtocol {
    private let supabase: SupabaseClient
    private let localStore: ModelContext

    // Implements both remote and local caching
}
```

### Communication Patterns

**ViewModel → View Communication:**
Use `@Observable` for automatic SwiftUI updates.

```swift
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var error: AppError?

    private let chatService: ChatStreamService
    private let conversationRepo: ConversationRepositoryProtocol

    func sendMessage(_ content: String) async {
        isStreaming = true
        defer { isStreaming = false }

        do {
            for try await token in chatService.streamChat(message: content) {
                // Append tokens to current message
            }
        } catch {
            self.error = .chatFailed(error)
        }
    }
}
```

**Error Handling Pattern:**

```swift
enum AppError: LocalizedError {
    case networkUnavailable
    case authenticationFailed
    case chatFailed(Error)
    case subscriptionRequired

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "I couldn't connect right now. Let's try again when you're back online."
        case .authenticationFailed:
            return "I had trouble signing you in. Let's try that again."
        case .chatFailed:
            return "Coach is taking a moment. Let's try again."
        case .subscriptionRequired:
            return "This feature requires a subscription."
        }
    }
}
```

### Process Patterns

**Offline Detection Pattern:**

```swift
@Observable
final class NetworkMonitor {
    var isConnected = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: .global())
    }
}

// In View
struct ChatView: View {
    @Environment(NetworkMonitor.self) private var network

    var body: some View {
        ZStack {
            // Chat content

            if !network.isConnected {
                OfflineBanner()
                    .glassEffect()
            }
        }
    }
}
```

**Streaming Pattern:**

```swift
// Service
final class ChatStreamService {
    func streamChat(message: String, conversationId: UUID) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var request = URLRequest(url: chatStreamURL)
                request.httpMethod = "POST"
                request.httpBody = try JSONEncoder().encode(ChatRequest(
                    message: message,
                    conversationId: conversationId
                ))
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                let (bytes, _) = try await URLSession.shared.bytes(for: request)

                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        if let event = try? JSONDecoder().decode(StreamEvent.self, from: Data(jsonString.utf8)) {
                            continuation.yield(event)
                            if event.done { break }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }
}
```

### Enforcement Guidelines

**All Development MUST:**
- Follow MVVM + Repository pattern
- Use `@Observable` for ViewModels (not `@ObservableObject`)
- Use adaptive design modifiers (`.adaptiveGlass()`, `.adaptiveInteractiveGlass()`) — never raw `.glassEffect()`
- Apply adaptive glass only to navigation/control elements, never content
- Use `AdaptiveGlassContainer` when grouping multiple glass elements
- Test on both iOS 18 and iOS 26 simulators/devices
- Include VoiceOver accessibility labels on all interactive elements
- Use warm, first-person error messages
- Never log PII, user messages, or auth credentials
- Use SwiftData for local persistence
- Use Keychain for sensitive data

**Anti-Patterns (NEVER do these):**
- Using raw `.glassEffect()` without version check — always use adaptive modifiers
- Glass on glass (stacking Liquid Glass elements on iOS 26)
- Applying adaptive glass to content (messages, lists, media)
- Using `@State` for data that should be in ViewModel
- Direct API calls from Views
- Storing API keys in code or Info.plist
- Logging user conversation content
- Using `UIKit` when SwiftUI equivalent exists
- Blocking main thread for network operations
- Testing only on iOS 26 — must verify iOS 18-25 experience

## Architectural Boundaries

### API Boundaries

| Boundary | Interface | Direction | Auth Required |
|---|---|---|---|
| iOS App → Supabase REST | HTTP REST | CRUD for conversations, messages, context, personas | Yes (JWT) |
| iOS App → Edge Functions | HTTP POST + SSE | Business logic: chat-stream, extract-context, push | Yes (JWT) |
| Edge Functions → PostgreSQL | Supabase Admin SDK | Server-side reads/writes | Service role key |
| Edge Functions → LLM Provider | HTTP REST (streaming) | Chat completion | API key (env var) |
| iOS App → RevenueCat SDK | Native SDK | Purchase flow, entitlements | RevenueCat API key |
| Edge Functions → RevenueCat | HTTP (webhook inbound) | Subscription events | Webhook signature |
| iOS App → APNs | Native iOS | Push notifications | Push certificate |

### Component Boundaries

| Layer | Owns | Communicates With | Communication Method |
|---|---|---|---|
| Views (SwiftUI) | UI presentation, Liquid Glass effects | Observes ViewModels | @Observable binding |
| ViewModels | UI state, user actions | Calls Repositories/Services | async/await methods |
| Repositories | Data abstraction | Remote + Local data sources | Protocol-based |
| Services | Business logic | Network, system APIs | Async methods |
| Core/UI | Design system | Used by all Views | SwiftUI modifiers |
| Core/Data | Data infrastructure | Used by Repositories | SwiftData, URLSession |

### Data Flow — Coaching Conversation (Critical Path)

```
User types message
  → MessageInput.swift (Features/Chat/Views)
  → ChatViewModel.sendMessage() (Features/Chat/ViewModels)
  → ChatStreamService.streamChat() (Core/Services)
  → URLSession POST /functions/v1/chat-stream
      Edge Function pipeline:
      ├─ auth.ts → verify JWT
      ├─ context-loader.ts → load context + history (<200ms)
      ├─ domain-router.ts → classify domain (<100ms)
      ├─ crisis-detector.ts → safety check
      ├─ prompt-builder.ts → construct full prompt
      ├─ llm-client.ts → call LLM API (streaming)
      ├─ SSE proxy → token-by-token to client
      └─ on complete: save message + log cost
  ← AsyncThrowingStream yields StreamEvent tokens
  ← ChatViewModel updates messages array
  ← StreamingText.swift renders token-by-token
  ← SwiftData persists for offline access
```

## Requirements Coverage Validation

### Functional Requirements (47 FRs)

| FR Category | FRs | Coverage |
|---|---|---|
| Coaching Conversation | FR1-FR9 | 9/9 fully covered |
| Personal Context | FR10-FR15 | 6/6 fully covered |
| Coaching Safety | FR16-FR22 | 7/7 fully covered |
| Creator Tools | FR23-FR26 | 4/4 fully covered |
| Account & Auth | FR27-FR32 | 6/6 fully covered |
| Payments & Subscription | FR33-FR36 | 4/4 fully covered |
| Notifications | FR37-FR40 | 4/4 fully covered |
| Operator Management | FR41-FR46 | 6/6 fully covered |
| App Store | FR47 | 1/1 fully covered |

**Result:** 47/47 FRs architecturally supported.

### Non-Functional Requirements (36 NFRs)

| NFR Category | NFRs | Coverage |
|---|---|---|
| Performance | NFR1-NFR9 | 9/9 covered |
| Security | NFR10-NFR18 | 9/9 fully covered |
| Scalability | NFR19-NFR24 | 6/6 fully covered |
| Accessibility | NFR25-NFR30 | 6/6 covered (Liquid Glass auto-handles most) |
| Integration | NFR31-NFR34 | 4/4 fully covered |
| Reliability | NFR35-NFR36 | 2/2 fully covered |

**Result:** 36/36 NFRs architecturally addressed.

## Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Native iOS 18+ with progressive enhancement for iOS 26 Liquid Glass
- Adaptive design system provides premium experience on all supported versions
- Swift Concurrency for clean async code
- SwiftData for simple local persistence
- Supabase provides backend without infrastructure management
- RevenueCat simplifies subscription management
- Clear MVVM + Repository pattern
- Every FR has traceable path to components
- Broad market reach (~90% of iOS devices)

**Implementation Sequence:**
1. Project setup (Xcode with iOS 18 deployment target, dependencies, Supabase project)
2. Adaptive design system (version detection, adaptive modifiers, theme coordination)
3. Core infrastructure (SupabaseClient, SwiftData models, Keychain)
4. Auth flow (Sign in with Apple + Supabase sync + biometric)
5. Chat UI + streaming (adaptive design chat, SSE client)
6. Context engine (profile storage, progressive extraction, injection)
7. Domain routing (NLP classification in Edge Function)
8. Crisis detection (safety layer in chat Edge Function)
9. Creator tools (persona CRUD + share links)
10. RevenueCat integration (subscription management)
11. Push notifications (APNs + Edge Function triggers)
12. Offline support (SwiftData caching + sync)
13. Operator dashboard (metrics + domain config)
14. Cross-version QA (verify iOS 18, 19, 20, 21, 22, 23, 24, 25, 26)

**First Implementation Step:**
Create new Xcode project with iOS 18.0 deployment target, configure adaptive design system foundation, then add Supabase SDK and RevenueCat SDK.
