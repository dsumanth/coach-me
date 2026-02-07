# Story 2.1: Context Profile Data Model & Storage

Status: complete

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **a context profile data model stored in Supabase and cached locally**,
So that **user context persists across sessions and works offline**.

## Acceptance Criteria

1. **Given** a new user
   **When** they sign up
   **Then** a context_profiles row is created with empty JSONB for values, goals, situation

2. **Given** context is updated
   **When** I save changes
   **Then** data is synced to Supabase and cached in SwiftData

3. **Given** the app launches offline
   **When** I need context
   **Then** I can load from SwiftData cache

## Tasks / Subtasks

- [x] Task 1: Create Supabase Database Migration (AC: #1)
  - [x] 1.1 Create migration file `20260206000003_context_profiles.sql` with table schema
  - [x] 1.2 Define JSONB columns for `values`, `goals`, `situation`, `extracted_insights`
  - [x] 1.3 Add foreign key to users table with ON DELETE CASCADE
  - [x] 1.4 Create RLS policies for user-only access
  - [x] 1.5 Add indexes on user_id and updated_at
  - [x] 1.6 Migration file ready for deployment

- [x] Task 2: Create Swift Data Models (AC: #1, #2)
  - [x] 2.1 Create `ContextProfile.swift` Codable model in `Features/Context/Models/`
  - [x] 2.2 Define types: `ContextValue.swift`, `ContextGoal.swift`, `ContextSituation.swift`, `ExtractedInsight.swift`
  - [x] 2.3 Add CodingKeys for snake_case conversion (per existing patterns)
  - [x] 2.4 Add factory methods for empty profile creation
  - [x] 2.5 Create `ContextProfileInsert` struct for minimal inserts

- [x] Task 3: Create SwiftData Local Cache Model (AC: #3)
  - [x] 3.1 Create `CachedContextProfile.swift` @Model in `Core/Data/Local/`
  - [x] 3.2 Store encoded ContextProfile JSON as Data for flexibility
  - [x] 3.3 Add `lastSyncedAt` timestamp for sync tracking
  - [x] 3.4 Register model in ModelContainer (CoachMeApp.swift)

- [x] Task 4: Create Context Repository (AC: #1, #2, #3)
  - [x] 4.1 Create `ContextRepository.swift` in `Core/Data/Repositories/`
  - [x] 4.2 Implement `createProfile(userId:)` - creates empty profile on signup
  - [x] 4.3 Implement `fetchProfile(userId:)` - remote fetch with local cache fallback
  - [x] 4.4 Implement `updateProfile(_:)` - sync to Supabase + update local cache
  - [x] 4.5 Implement `getLocalProfile(userId:)` - SwiftData query for offline
  - [x] 4.6 Add proper error handling with `ContextError` enum

- [x] Task 5: Integrate with Auth Flow (AC: #1)
  - [x] 5.1 Modify `AuthService.swift` to trigger profile creation on first sign-in
  - [x] 5.2 Add `profileExists(userId:)` check to avoid duplicate creation
  - [x] 5.3 Handle profile creation failure gracefully (non-blocking)

- [x] Task 6: Write Unit Tests
  - [x] 6.1 Test ContextProfile encoding/decoding with CodingKeys (30 tests)
  - [x] 6.2 Test CachedContextProfile SwiftData operations (13 tests)
  - [x] 6.3 Test offline fallback and cache staleness
  - [x] 6.4 Test empty profile factory method

## Dev Notes

### Architecture Compliance

**CRITICAL - Follow these patterns established in Epic 1:**

1. **Service Pattern**: Use singleton `@MainActor` services (like `ConversationService.swift:12-30`)
2. **Supabase Access**: Always via `AppEnvironment.shared.supabase` (like `ConversationService.swift:32`)
3. **Models**: Use Codable + CodingKeys for snake_case (like `ChatMessage.swift:5-25`)
4. **ViewModels**: Use `@Observable` not `@ObservableObject` (like `ChatViewModel.swift:8`)
5. **Error Handling**: Custom `LocalizedError` enums with first-person messages per UX-11

### Technical Requirements

**Database Schema** (from architecture.md):
```sql
-- context_profiles table
CREATE TABLE context_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    values JSONB DEFAULT '[]'::jsonb,     -- Array of user values
    goals JSONB DEFAULT '[]'::jsonb,      -- Array of user goals
    situation JSONB DEFAULT '{}'::jsonb,  -- Life situation object
    extracted_insights JSONB DEFAULT '[]'::jsonb, -- Progressive extraction
    context_version INTEGER DEFAULT 1,    -- For migrations
    first_session_complete BOOLEAN DEFAULT false,
    prompt_dismissed_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- RLS Policy
ALTER TABLE context_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access own context"
    ON context_profiles FOR ALL
    USING (auth.uid() = user_id);

-- Index
CREATE INDEX idx_context_profiles_user_id ON context_profiles(user_id);
```

**Swift Model Structure**:
```swift
// Features/Context/Models/ContextProfile.swift
struct ContextProfile: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var values: [ContextValue]        // JSONB array
    var goals: [ContextGoal]          // JSONB array
    var situation: ContextSituation   // JSONB object
    var extractedInsights: [ExtractedInsight]
    var contextVersion: Int
    var firstSessionComplete: Bool
    var promptDismissedCount: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case values, goals, situation
        case extractedInsights = "extracted_insights"
        case contextVersion = "context_version"
        case firstSessionComplete = "first_session_complete"
        case promptDismissedCount = "prompt_dismissed_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func empty(userId: UUID) -> ContextProfile {
        ContextProfile(
            id: UUID(),
            userId: userId,
            values: [],
            goals: [],
            situation: .empty,
            extractedInsights: [],
            contextVersion: 1,
            firstSessionComplete: false,
            promptDismissedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// Supporting types
struct ContextValue: Codable, Sendable, Identifiable {
    let id: UUID
    var content: String
    var source: ContextSource  // "user" or "extracted"
    var confidence: Double?    // For extracted values
    let addedAt: Date
}

struct ContextGoal: Codable, Sendable, Identifiable {
    let id: UUID
    var content: String
    var domain: String?        // Coaching domain if known
    var source: ContextSource
    var status: GoalStatus     // "active", "achieved", "archived"
    let addedAt: Date
}

struct ContextSituation: Codable, Sendable {
    var lifeStage: String?
    var occupation: String?
    var relationships: String?
    var challenges: String?
    var freeform: String?

    static let empty = ContextSituation(
        lifeStage: nil,
        occupation: nil,
        relationships: nil,
        challenges: nil,
        freeform: nil
    )
}

enum ContextSource: String, Codable, Sendable {
    case user = "user"
    case extracted = "extracted"
}

enum GoalStatus: String, Codable, Sendable {
    case active = "active"
    case achieved = "achieved"
    case archived = "archived"
}
```

**SwiftData Cache Model**:
```swift
// Core/Data/Local/CachedContextProfile.swift
import SwiftData

@Model
final class CachedContextProfile {
    @Attribute(.unique) var userId: UUID
    var profileData: Data  // Encoded ContextProfile JSON
    var lastSyncedAt: Date

    init(userId: UUID, profileData: Data, lastSyncedAt: Date = Date()) {
        self.userId = userId
        self.profileData = profileData
        self.lastSyncedAt = lastSyncedAt
    }
}
```

**Repository Pattern** (following ConversationService):
```swift
// Core/Data/Repositories/ContextRepository.swift
@MainActor
final class ContextRepository {
    static let shared = ContextRepository()

    private var supabase: SupabaseClient {
        AppEnvironment.shared.supabase
    }

    func createProfile(for userId: UUID) async throws -> ContextProfile {
        let profile = ContextProfile.empty(userId: userId)
        try await supabase
            .from("context_profiles")
            .insert(profile)
            .execute()
        return profile
    }

    func fetchProfile(userId: UUID) async throws -> ContextProfile {
        // Try remote first, fallback to cache
        do {
            let profiles: [ContextProfile] = try await supabase
                .from("context_profiles")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let profile = profiles.first else {
                throw ContextError.notFound
            }

            // Update local cache
            try await cacheProfile(profile)
            return profile
        } catch {
            // Fallback to local cache
            if let cached = try await getLocalProfile(userId: userId) {
                return cached
            }
            throw error
        }
    }

    func updateProfile(_ profile: ContextProfile) async throws {
        var updated = profile
        updated.updatedAt = Date()

        try await supabase
            .from("context_profiles")
            .update(updated)
            .eq("id", value: profile.id)
            .execute()

        try await cacheProfile(updated)
    }

    // Private helpers for SwiftData caching
    private func cacheProfile(_ profile: ContextProfile) async throws { }
    private func getLocalProfile(userId: UUID) async throws -> ContextProfile? { }
}

enum ContextError: LocalizedError, Equatable {
    case notFound
    case notAuthenticated
    case saveFailed(String)
    case cacheError(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "I don't have your context yet. Let's set that up."
        case .notAuthenticated:
            return "I need you to sign in first."
        case .saveFailed(let reason):
            return "I couldn't save your context. \(reason)"
        case .cacheError(let reason):
            return "I had trouble with local storage. \(reason)"
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```
CoachMe/CoachMe/
├── Core/Data/
│   ├── Local/
│   │   └── CachedContextProfile.swift    # NEW - SwiftData model
│   └── Repositories/
│       └── ContextRepository.swift        # NEW - Repository service
├── Features/Context/
│   └── Models/
│       ├── ContextProfile.swift           # NEW - Main Codable model
│       ├── ContextValue.swift             # NEW - Value type
│       ├── ContextGoal.swift              # NEW - Goal type
│       └── ContextSituation.swift         # NEW - Situation type
└── Supabase/
    └── migrations/
        └── 00007_context_profiles.sql     # NEW - DB migration
```

**Files to Modify:**
```
CoachMe/CoachMe/App/Environment/AppEnvironment.swift
  - Register SwiftData ModelContainer with CachedContextProfile

CoachMe/CoachMe/Features/Auth/Services/AuthService.swift
  - Add profile creation on first sign-in
```

### Previous Epic Learnings (Epic 1 Completed)

**From Git History (3 commits):**
- `f6da5f5` - Fixed message input text box colors for light mode
- `1aa8476` - Redesigned message input to match iMessage style
- `4f9cc33` - Initial commit with Epic 1 complete

**Key Patterns Established:**
1. Use `@MainActor` for all services and ViewModels
2. Access Supabase via `AppEnvironment.shared.supabase`
3. Use AsyncThrowingStream for streaming operations
4. Error messages are warm, first-person (per UX-11)
5. Factory methods for model creation (e.g., `ChatMessage.userMessage()`)

### Testing Requirements

**Unit Tests to Create:**
```swift
// CoachMeTests/Features/Context/ContextProfileTests.swift
final class ContextProfileTests: XCTestCase {
    func testEmptyProfileCreation()
    func testEncodingDecodingWithSnakeCase()
    func testValueAddition()
    func testGoalStatusTransitions()
}

// CoachMeTests/Core/Data/ContextRepositoryTests.swift
final class ContextRepositoryTests: XCTestCase {
    func testCreateProfile()
    func testFetchProfileRemote()
    func testFetchProfileOfflineFallback()
    func testUpdateProfile()
}
```

### References

- [Source: architecture.md#Data-Architecture] - Database schema specifications
- [Source: architecture.md#Frontend-Architecture] - MVVM + Repository pattern
- [Source: architecture.md#Implementation-Patterns] - Naming conventions, CodingKeys
- [Source: epics.md#Story-2.1] - Original story requirements
- [Source: ux-design-specification.md#Context-Profile] - UX treatment of context
- [Source: ConversationService.swift] - Service pattern reference
- [Source: ChatMessage.swift] - Codable model pattern reference

### Web Research Notes

**SwiftData iOS 18+ Best Practices (2026):**
- Use `@Attribute(.unique)` for unique constraints
- Store complex Codable objects as Data for flexibility
- Use `@Query` for reactive SwiftUI bindings
- ModelContainer should be created once at app launch
- Use background context for heavy operations

**Supabase Swift SDK (v2.x):**
- JSONB columns map directly to Codable types
- Use `.select()` without arguments for all columns
- RLS policies require `auth.uid()` function
- Use `.upsert()` for create-or-update patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Fixed Swift 6 strict concurrency issues with FetchDescriptor predicates by using fetch-all-and-filter pattern
- Fixed CachedContextProfile methods to use @MainActor for Codable operations
- Fixed test for ExtractedInsight encoding (needed to provide conversationId to test snake_case)

### Code Review Fixes (Post-Implementation)

1. **Issue 7 - Dual ModelContainer**: Consolidated to single source of truth in AppEnvironment; CoachMeApp now uses `AppEnvironment.shared.modelContainer`
2. **Issues 1-3 - ContextRepository.createProfile()**: Changed to use `ContextProfileInsert` (minimal data), `upsert()` for atomic race-safe creation, and fetch-after-insert for server-assigned values
3. **Issue 6 - Duplicate Migration**: Removed duplicate at `CoachMe/Supabase/migrations/`; kept canonical at `CoachMe/Supabase/supabase/migrations/`
4. **Issue 4 - Missing Repository Tests**: Added `ContextRepositoryTests.swift` with 10 tests for cache operations and offline scenarios

### Completion Notes List

1. **Task 1**: Created database migration `20260206000003_context_profiles.sql` with full schema, RLS policies, and indexes
2. **Task 2**: Created 5 Swift model files: ContextProfile.swift, ContextValue.swift, ContextGoal.swift, ContextSituation.swift, ExtractedInsight.swift
3. **Task 3**: Created CachedContextProfile SwiftData model with encode/decode methods and staleness tracking
4. **Task 4**: Created ContextRepository with full CRUD operations and offline fallback support
5. **Task 5**: Integrated with AuthService to create context profile on first sign-in (non-blocking)
6. **Task 6**: Created 53 unit tests covering encoding/decoding, factory methods, mutations, SwiftData operations, and repository cache behavior

### File List

**Created Files:**
- `CoachMe/Supabase/supabase/migrations/20260206000003_context_profiles.sql` - Database migration (canonical location)
- `CoachMe/CoachMe/Features/Context/Models/ContextProfile.swift` - Main profile model
- `CoachMe/CoachMe/Features/Context/Models/ContextValue.swift` - Value type with factory methods
- `CoachMe/CoachMe/Features/Context/Models/ContextGoal.swift` - Goal type with status transitions
- `CoachMe/CoachMe/Features/Context/Models/ContextSituation.swift` - Life situation model
- `CoachMe/CoachMe/Features/Context/Models/ExtractedInsight.swift` - AI-extracted insight model
- `CoachMe/CoachMe/Core/Data/Local/CachedContextProfile.swift` - SwiftData cache model
- `CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift` - Repository with Supabase + cache
- `CoachMe/CoachMeTests/ContextProfileTests.swift` - 30 unit tests for models
- `CoachMe/CoachMeTests/CachedContextProfileTests.swift` - 13 unit tests for cache
- `CoachMe/CoachMeTests/ContextRepositoryTests.swift` - 10 unit tests for repository cache operations

**Modified Files:**
- `CoachMe/CoachMe/CoachMeApp.swift` - Uses AppEnvironment's ModelContainer (single source of truth)
- `CoachMe/CoachMe/App/Environment/AppEnvironment.swift` - Added modelContainer and modelContext properties
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` - Added context profile creation on sign-in

