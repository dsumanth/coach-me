# Story 6.6: Account Deletion

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to delete my account and all my data from within the app**,
so that **I have full control over my privacy and meet App Store compliance requirements (FR29, NFR16)**.

## Acceptance Criteria

1. **Given** I want to delete my account, **When** I tap "Delete Account" in Settings, **Then** I see a confirmation dialog with warm copy: "This will permanently remove your account, conversations, and everything I know about you. This can't be undone."

2. **Given** I see the confirmation dialog, **When** I tap "Cancel", **Then** the dialog dismisses and nothing happens.

3. **Given** I confirm deletion, **When** the action is processing, **Then** I see a loading overlay with "Removing your account..." and all UI interaction is blocked.

4. **Given** I confirm deletion, **When** the server-side deletion completes, **Then** all my data is removed from Supabase (auth user, public.users, conversations, messages, context_profiles, usage_logs, pattern_syntheses — all via CASCADE from auth.users deletion).

5. **Given** server-side deletion succeeds, **When** local cleanup runs, **Then** Keychain auth data is cleared, SwiftData caches (CachedContextProfile) are purged, in-memory caches (ConversationListCache, ChatMessageCache) are cleared, and RevenueCat user is logged out. Device-level preferences (appearance mode) are preserved.

6. **Given** my account is fully deleted, **When** the process completes, **Then** I am navigated to the Welcome screen for new users.

7. **Given** account deletion fails (network error, server error), **When** I see the error, **Then** a warm first-person error message is shown: "I couldn't remove your account right now. Please check your connection and try again."

8. **Given** I open the app after account deletion, **When** the app launches, **Then** I see the Welcome screen with Sign in with Apple — no trace of my previous account exists locally.

## Tasks / Subtasks

- [x] Task 1: Create `delete-account` Supabase Edge Function (AC: #4)
  - [x] 1.1: Create `supabase/functions/delete-account/index.ts` following the `chat-stream/index.ts` boilerplate
  - [x] 1.2: Import and use `_shared/cors.ts` `handleCors()` for OPTIONS preflight
  - [x] 1.3: Import and use `_shared/auth.ts` `verifyAuth()` to extract `userId` from JWT
  - [x] 1.4: Create admin Supabase client with `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')` — NOT anon key
  - [x] 1.5: Call `supabase.auth.admin.deleteUser(userId)` — triggers full CASCADE chain
  - [x] 1.6: Return standardized response via `_shared/response.ts` — `{ data: { success: true } }` on 200
  - [x] 1.7: Handle errors: 401 for bad JWT, 500 for deletion failure, with warm error messages

- [x] Task 2: Add `deleteAccount()` to AuthService (AC: #4, #5)
  - [x] 2.1: Add `AuthError.accountDeletionFailed` case with message: "I couldn't remove your account right now. Please check your connection and try again."
  - [x] 2.2: Add `deleteAccount()` async throws method
  - [x] 2.3: Call Edge Function via `URLSession` POST to `Configuration.supabaseURL + "/functions/v1/delete-account"` with Bearer token
  - [x] 2.4: Set headers: `Authorization: Bearer {token}`, `Content-Type: application/json`, `apikey: {supabaseKey}`
  - [x] 2.5: On success: call `try? await SubscriptionService.shared.logOutUser()` (non-blocking RevenueCat cleanup)
  - [x] 2.6: On success: call `clearSession()` (clears Keychain + in-memory caches)
  - [x] 2.7: On success: purge SwiftData — `AppEnvironment.shared.modelContainer` → `ModelContext` → fetch all `CachedContextProfile` → delete each → save
  - [x] 2.8: On success: set `currentUser = nil`
  - [x] 2.9: On failure: throw error — do NOT clear any local state (user remains signed in)

- [x] Task 3: Add `deleteAccount()` to SettingsViewModel (AC: #3, #6, #7)
  - [x] 3.1: Add `showDeleteAccountConfirmation: Bool` state
  - [x] 3.2: Add `isDeletingAccount: Bool` state (separate from conversation deletion `isDeleting`)
  - [x] 3.3: Add `SettingsError.accountDeletionFailed` case with warm message
  - [x] 3.4: Implement `deleteAccount() async -> Bool` — calls `AuthService.shared.deleteAccount()`, returns success/failure
  - [x] 3.5: On failure: set error state for display, return false

- [x] Task 4: Add account deletion UI to SettingsView (AC: #1, #2, #3, #6)
  - [x] 4.1: Add "Delete Account" row in `accountSection` below Sign Out — red icon (`trash`) + text + chevron
  - [x] 4.2: Add `.alert()` for confirmation with destructive "Delete Account" button and "Cancel" button
  - [x] 4.3: Add loading overlay using `isDeletingAccount` state with message "Removing your account..."
  - [x] 4.4: On success: navigate to Welcome via `router.navigateToWelcome()`
  - [x] 4.5: Add accessibility: `accessibilityLabel("Delete account")` + `accessibilityHint("Permanently deletes your account and all data")`

- [x] Task 5: Write tests (AC: all)
  - [x] 5.1: Unit test `SettingsViewModel.deleteAccount()` success path — verify returns true
  - [x] 5.2: Unit test `SettingsViewModel.deleteAccount()` failure path — verify error state set, returns false
  - [x] 5.3: Unit test Edge Function auth validation (JWT required, user ID match)

## Dev Notes

### Critical Order of Operations

**AuthService.deleteAccount() MUST follow this exact sequence:**
1. Call Edge Function FIRST — needs valid JWT (still signed in)
2. RevenueCat logout (non-blocking, wrapped in `try?`)
3. Call `clearSession()` — clears Keychain + in-memory caches
4. Purge SwiftData CachedContextProfile records
5. Set `currentUser = nil`

**On failure at step 1**: throw error, do NOT proceed to steps 2-5. User stays signed in.

### Database CASCADE Chain (Zero Manual Cleanup)

```text
auth.users(id) DELETE
  → public.users(id) CASCADE
    → conversations(user_id) CASCADE
      → messages(conversation_id) CASCADE
        → usage_logs(message_id) CASCADE
    → messages(user_id) CASCADE
    → context_profiles(user_id) CASCADE
    → usage_logs(user_id) CASCADE
    → pattern_syntheses(user_id) CASCADE
```

All server-side data removal is handled by `supabase.auth.admin.deleteUser(userId)`. No manual table deletes needed.

### Edge Function Implementation

**File**: `supabase/functions/delete-account/index.ts`

**Pattern** — mirror `chat-stream/index.ts`:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { verifyAuth } from "../_shared/auth.ts";

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { userId } = await verifyAuth(req);

    // Admin client with service role key for auth.admin operations
    const adminSupabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { error } = await adminSupabase.auth.admin.deleteUser(userId);
    if (error) throw error;

    return new Response(
      JSON.stringify({ data: { success: true } }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    // ... error handling with warm messages
  }
});
```

**Key**: `verifyAuth()` in `_shared/auth.ts` extracts and validates the JWT, returning `{ userId, supabase }`. The user can only delete their own account — no need for extra ID parameter since the JWT IS the user identity.

### AuthService Pattern

Mirror the existing `signOut()` at AuthService.swift:315-341. Key differences:
- `signOut()` calls `supabase.auth.signOut()` (client SDK) → `deleteAccount()` calls Edge Function (server admin)
- `deleteAccount()` must call the Edge Function via `URLSession` (not Supabase SDK) since there's no client SDK method for admin user deletion
- Both share the same local cleanup: `clearSession()` handles Keychain + caches

**Authenticated request pattern** — follow `ChatStreamService`:
```swift
var request = URLRequest(url: URL(string: "\(Configuration.supabaseURL)/functions/v1/delete-account")!)
request.httpMethod = "POST"
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(Configuration.supabasePublishableKey, forHTTPHeaderField: "apikey")
```

### SettingsView Integration

**Add below the Sign Out button** in `accountSection` (SettingsView.swift ~line 230):
- Same visual pattern: `Image(systemName: "trash")` with `.foregroundColor(.red)` + "Delete Account" text
- `.alert()` matching the sign-out confirmation pattern at SettingsView.swift:99-112
- Loading overlay: same pattern as `isDeleting` overlay (~line 62-77) but with `isDeletingAccount` and "Removing your account..."

### SettingsViewModel Pattern

Mirror existing `signOut()` method in SettingsViewModel.swift:
```swift
func deleteAccount() async -> Bool {
    isDeletingAccount = true
    defer { isDeletingAccount = false }
    do {
        try await AuthService.shared.deleteAccount()
        return true
    } catch {
        self.error = .accountDeletionFailed
        return false
    }
}
```

### Local State Cleanup Details

**SwiftData** — fetch-all-and-filter pattern (Swift 6 safe):
```swift
let context = ModelContext(AppEnvironment.shared.modelContainer)
let profiles = try context.fetch(FetchDescriptor<CachedContextProfile>())
for profile in profiles { context.delete(profile) }
try context.save()
```

**Keychain**: `keychainManager.clearAllAuthData()` — clears `.accessToken`, `.refreshToken`, `.userId`

**In-Memory Caches**: `ConversationListCache.clear()` + `ChatMessageCache.clearAll()` — called by `clearSession()`

**UserDefaults**: DO NOT clear `@AppStorage(AppAppearance.storageKey)` — it's a device preference, not user data

**RevenueCat**: `try? await SubscriptionService.shared.logOutUser()` — non-blocking, resets to anonymous user (same as signOut)

### Error Messages (UX-11 Compliance)

| Scenario | Message |
|----------|---------|
| Deletion failed | "I couldn't remove your account right now. Please check your connection and try again." |
| Network error | "I couldn't reach the server. Please try again when you're online." |

### Accessibility

- Delete Account button: `accessibilityLabel("Delete account")` + `accessibilityHint("Permanently deletes your account and all data")`
- Confirmation alert: standard SwiftUI `.alert()` — VoiceOver reads title + message + buttons automatically
- Loading overlay: `accessibilityLabel("Removing your account")`

### Testing Standards

Use **Swift Testing** framework (NOT XCTest) — matches all Epic 6 tests:
- `import Testing`
- `@Test` function annotations
- `#expect()` assertions
- `@MainActor` on test structs
- Test file location: `CoachMe/CoachMeTests/`

### Previous Story Learnings (Epic 6)

From **Story 6-1** (RevenueCat Integration):
- RevenueCat SDK already installed (`purchases-ios` v5.57.1) — do NOT re-add
- `SubscriptionService.shared.logOutUser()` already exists for RevenueCat cleanup
- All RevenueCat calls in auth flow are non-blocking (`Task { try? ... }`)
- `Configuration.revenueCatAPIKey` provides API key access

From **Story 6-4** (Subscription Management):
- `SubscriptionManagementViewModel` uses `customerInfoStream` — account deletion should cancel any active subscription stream listeners
- `@MainActor @Observable` pattern for all ViewModels (NOT `@ObservableObject/@Published`)
- SettingsView has subscription section between Appearance and Data sections — Account section is at the bottom
- `.adaptiveGlass()` for section containers, never nested glass-on-glass

### Project Structure Notes

**Files to CREATE:**
- `supabase/functions/delete-account/index.ts` — New Edge Function

**Files to MODIFY:**
- [AuthService.swift](CoachMe/CoachMe/Features/Auth/Services/AuthService.swift) — Add `deleteAccount()` + `AuthError.accountDeletionFailed`
- [SettingsViewModel.swift](CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift) — Add `deleteAccount()` + state properties
- [SettingsView.swift](CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift) — Add delete button + alert + loading overlay

**Alignment**: Follows existing MVVM pattern. No new architectural patterns introduced. No new files beyond Edge Function.

### References

- [Source: architecture.md#Authentication & Security] — Auth flow, JWT tokens, Keychain storage
- [Source: architecture.md#API & Communication Patterns] — Edge Function patterns, error handling
- [Source: architecture.md#Project Structure] — File organization, naming conventions
- [Source: epics.md#Story 6.6] — FR29 Account deletion, ARCH-6 Keychain
- [Source: prd.md#FR29] — Account deletion requirement
- [Source: prd.md#NFR16] — Permanent data removal within 30 days
- [Source: prd.md#Personal Data Privacy] — AES-256, TLS 1.3, user control, no third-party sharing
- [Source: 20260205000001_initial_schema.sql] — CASCADE DELETE chain from auth.users
- [Source: 20260205000002_rls_policies.sql] — RLS policies for all tables (user can delete own data)
- [Source: 20260206000003_context_profiles.sql] — context_profiles CASCADE
- [Source: 20260207000001_pattern_syntheses.sql] — pattern_syntheses CASCADE
- [Source: AuthService.swift:315-341] — Existing signOut() pattern to mirror
- [Source: SettingsView.swift:210-246] — Account section with Sign Out button
- [Source: SettingsView.swift:99-112] — Sign-out confirmation alert pattern
- [Source: SettingsViewModel.swift:94-113] — Existing signOut() method pattern
- [Source: ContextRepository.swift:636-652] — SwiftData fetch-all-and-filter deletion pattern
- [Source: CachedContextProfile.swift] — SwiftData model to purge
- [Source: supabase/functions/_shared/auth.ts] — `verifyAuth()` JWT verification helper
- [Source: supabase/functions/_shared/cors.ts] — `handleCors()` CORS handler
- [Source: supabase/functions/_shared/response.ts] — Standardized error response format
- [Source: chat-stream/index.ts] — Complete Edge Function boilerplate pattern
- [Source: Story 6-1] — RevenueCat patterns, `SubscriptionService.shared.logOutUser()`
- [Source: Story 6-4] — `@MainActor @Observable` ViewModel pattern, SettingsView section ordering

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None — clean implementation with no blocking issues.

### Completion Notes List
- **Task 1**: Created `delete-account` Edge Function using `Deno.serve()` pattern (matching existing `chat-stream`). Uses `verifyAuth()` for JWT validation, admin client with `SUPABASE_SERVICE_ROLE_KEY` for `auth.admin.deleteUser()`. Returns 200 on success, 401 for auth errors, 500 for server errors.
- **Task 2**: Added `deleteAccount()` to `AuthService` following critical order: Edge Function call (with valid JWT) → RevenueCat logout → `clearSession()` → SwiftData purge → nil user. On failure at step 1, throws error without clearing any local state.
- **Task 3**: Added `deleteAccount()` to `SettingsViewModel` with `isDeletingAccount` and `showDeleteAccountConfirmation` state. Returns Bool for success/failure. Error case uses warm UX-11 message.
- **Task 4**: Added "Delete Account" row below Sign Out in `accountSection` with red trash icon. Confirmation alert with warm copy. Loading overlay with "Removing your account..." message. Navigates to Welcome on success. Full accessibility labels/hints.
- **Task 5**: Added Swift Testing tests for SettingsViewModel delete account (initial state, failure path with error state, error message validation, UX-11 compliance). Created Deno test for Edge Function (auth header validation, response shapes, CORS).

### Implementation Plan
Followed story task sequence exactly. Used existing patterns from `signOut()` for AuthService, SettingsViewModel, and SettingsView. Edge Function mirrors `chat-stream/index.ts` boilerplate with admin client for user deletion.

### File List

**Created:**
- `supabase/functions/delete-account/index.ts` — Account deletion Edge Function
- `supabase/functions/delete-account/delete-account.test.ts` — Deno tests for Edge Function

**Modified:**
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` — Added `import SwiftData`, `AuthError.accountDeletionFailed`, `deleteAccount()` method
- `CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift` — Added `showDeleteAccountConfirmation`, `isDeletingAccount`, `SettingsError.accountDeletionFailed`, `deleteAccount()` method
- `CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift` — Added Delete Account row, confirmation alert, loading overlay
- `CoachMe/CoachMeTests/SettingsViewModelTests.swift` — Added `AccountDeletionViewModelTests` test struct with 7 tests

## Change Log

- **2026-02-09**: Implemented Story 6.6 Account Deletion — Edge Function, AuthService, SettingsViewModel, SettingsView UI, and tests. All 5 tasks with 25 subtasks completed.
