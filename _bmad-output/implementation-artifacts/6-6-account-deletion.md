# Story 6.6: Account Deletion

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want **to delete my account and all my data from within the app**,
so that **I have full control over my privacy and meet App Store compliance requirements (FR29)**.

## Acceptance Criteria

1. **Given** I want to delete my account, **When** I tap "Delete Account" in Settings, **Then** I see a confirmation dialog with warm copy explaining what will happen: "This will permanently remove your account, conversations, and everything I know about you. This can't be undone."

2. **Given** I see the confirmation dialog, **When** I tap "Cancel", **Then** the dialog dismisses and nothing happens.

3. **Given** I confirm deletion, **When** the action is processing, **Then** I see a loading overlay with the message "Removing your account..." and all UI interaction is blocked.

4. **Given** I confirm deletion, **When** the server-side deletion completes, **Then** all my data is removed from Supabase (auth user, public.users, conversations, messages, context_profiles, usage_logs, pattern_syntheses — all via CASCADE from auth.users deletion).

5. **Given** server-side deletion succeeds, **When** local cleanup runs, **Then** Keychain auth data is cleared, SwiftData caches (CachedContextProfile) are purged, and in-memory caches (ConversationListCache, ChatMessageCache) are cleared. Device-level preferences (appearance mode) are preserved.

6. **Given** my account is fully deleted, **When** the process completes, **Then** I am navigated to the Welcome screen for new users.

7. **Given** account deletion fails (network error, server error), **When** I see the error, **Then** a warm first-person error message is shown: "I couldn't remove your account right now. Please check your connection and try again."

8. **Given** I open the app after account deletion, **When** the app launches, **Then** I see the Welcome screen with Sign in with Apple — no trace of my previous account exists locally.

## Tasks / Subtasks

- [ ] Task 1: Create `delete-account` Supabase Edge Function (AC: #4)
  - [ ] 1.1: Create `supabase/functions/delete-account/index.ts`
  - [ ] 1.2: Verify JWT and extract user ID from auth header
  - [ ] 1.3: Call `supabase.auth.admin.deleteUser(userId)` using service role key
  - [ ] 1.4: Handle errors and return appropriate HTTP status codes
  - [ ] 1.5: Test locally with `supabase functions serve`

- [ ] Task 2: Add `deleteAccount()` to AuthService (AC: #4, #5)
  - [ ] 2.1: Add `deleteAccount()` async method to `AuthService`
  - [ ] 2.2: Call the `delete-account` Edge Function via authenticated POST request
  - [ ] 2.3: On success, clear Keychain via `keychainManager.clearAllAuthData()`
  - [ ] 2.4: Clear SwiftData model container (delete all `CachedContextProfile` records)
  - [ ] 2.5: Clear in-memory caches (`ConversationListCache.clear()`, `ChatMessageCache.clearAll()`)
  - [ ] 2.6: Reset `currentUser` to nil
  - [ ] 2.7: Add `AuthError.accountDeletionFailed` with warm first-person message

- [ ] Task 3: Add account deletion UI to SettingsView (AC: #1, #2, #3, #6)
  - [ ] 3.1: Add "Delete Account" button row to the Account section in `SettingsView` (below Sign Out)
  - [ ] 3.2: Add confirmation `.alert()` with warm copy and destructive "Delete Account" button
  - [ ] 3.3: Add loading overlay state for account deletion in progress
  - [ ] 3.4: On success, dismiss Settings and navigate to Welcome via `router.navigateToWelcome()`

- [ ] Task 4: Add `deleteAccount()` to SettingsViewModel (AC: #3, #6, #7)
  - [ ] 4.1: Add `showDeleteAccountConfirmation` state
  - [ ] 4.2: Add `isDeletingAccount` state (separate from `isDeleting` for conversations)
  - [ ] 4.3: Add `SettingsError.accountDeletionFailed` case
  - [ ] 4.4: Implement `deleteAccount()` async method that calls `AuthService.shared.deleteAccount()`
  - [ ] 4.5: Return success/failure boolean for navigation control

- [ ] Task 5: Write tests (AC: all)
  - [ ] 5.1: Unit test `SettingsViewModel.deleteAccount()` success path
  - [ ] 5.2: Unit test `SettingsViewModel.deleteAccount()` failure path (error display)
  - [ ] 5.3: Unit test Edge Function auth validation and deletion logic

## Dev Notes

### Architecture Compliance

**Pattern**: MVVM + Repository — follows existing `SettingsView` → `SettingsViewModel` → `AuthService` chain, identical to the sign-out flow.

**Edge Function Pattern**: Server-side deletion required because Supabase `auth.admin.deleteUser()` needs the service role key (never exposed to client). This matches the existing Edge Function pattern used by `chat-stream` and `extract-context`.

**Database Cascade Chain** (no manual table cleanup needed):
```
auth.users(id) DELETE
  → public.users(id) CASCADE
    → conversations(user_id) CASCADE
      → messages(conversation_id) CASCADE
    → messages(user_id) CASCADE
    → context_profiles(user_id) CASCADE
    → usage_logs(user_id) CASCADE
    → pattern_syntheses(user_id) CASCADE
```

### Critical Implementation Details

**Edge Function (`delete-account/index.ts`)**:
- Location: `CoachMe/Supabase/supabase/functions/delete-account/index.ts` (alongside existing `chat-stream/`, `extract-context/`)
- MUST handle CORS preflight (OPTIONS request) — import and use `_shared/cors.ts`
- MUST use `createClient` with `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')` (not anon key) for admin operations
- Extract user ID from the JWT in the Authorization header using shared `_shared/auth.ts` `getUserFromRequest()` helper
- Verify the requesting user ID matches the user being deleted (prevent deleting other users)
- Call `supabase.auth.admin.deleteUser(userId)` — this triggers the full CASCADE chain across all tables
- Return standardized response using `_shared/response.ts`: `{ data: { success: true } }` on 200, or `{ error: message }` on 4xx/5xx
- Reference existing `chat-stream/index.ts` for the complete Edge Function boilerplate pattern

**AuthService.deleteAccount()**:
- **Order of operations is CRITICAL**: (1) Call Edge Function first (needs valid JWT), (2) THEN clear local state (JWT will be invalid after server-side deletion)
- Call Edge Function via `URLSession` POST to `Configuration.supabaseURL` + `/functions/v1/delete-account` with Bearer token from `currentAccessToken`
- Follow the same authenticated request pattern as `ChatStreamService` (see [ChatStreamService.swift](CoachMe/CoachMe/Core/Services/ChatStreamService.swift))
- Set headers: `Authorization: Bearer {token}`, `Content-Type: application/json`, `apikey: {supabaseKey}`
- On success: call `clearSession()` (clears Keychain + caches) + purge SwiftData + reset `currentUser = nil`
- On failure: throw `AuthError.accountDeletionFailed` with warm message — do NOT clear local state on failure (user should remain signed in)

**SettingsView changes**:
- Add "Delete Account" row inside `accountSection` below the Sign Out button, using same visual pattern (red icon + text + chevron)
- Use `.alert()` pattern matching existing sign-out confirmation
- Loading overlay: reuse the existing `isDeleting` pattern but with `isDeletingAccount` and message "Removing your account..."
- After successful deletion, call `router.navigateToWelcome()` — same as sign-out flow

**SettingsViewModel changes**:
- Add `showDeleteAccountConfirmation: Bool` and `isDeletingAccount: Bool` state
- Add `SettingsError.accountDeletionFailed(String)` case with warm message: "I couldn't remove your account. {reason}"
- `deleteAccount()` method follows same pattern as `signOut()` — returns `Bool`

### Local State Cleanup (Critical)

**SwiftData**: Purge all `CachedContextProfile` records. Use `AppEnvironment.shared.modelContainer` → create `ModelContext` → `fetch(FetchDescriptor<CachedContextProfile>())` → delete each → `try modelContext.save()`. Reference: [ContextRepository.swift](CoachMe/CoachMe/Core/Data/Repositories/ContextRepository.swift) for the fetch-all-and-filter pattern.

**Keychain**: `KeychainManager.shared.clearAllAuthData()` — already clears `.accessToken`, `.refreshToken`, `.userId`.

**In-Memory Caches**: `ConversationListCache.clear()` + `ChatMessageCache.clearAll()` — already called by `clearSession()` in AuthService.

**UserDefaults**: The `@AppStorage(AppAppearance.storageKey)` appearance preference is a device setting, NOT user data — do NOT clear it. Only clear user-specific keys if any exist (currently none do).

### Error Messages (UX-11 Compliance)

All error messages MUST be warm, first-person:
- Deletion failed: "I couldn't remove your account right now. Please check your connection and try again."
- Network error: "I couldn't reach the server. Please try again when you're online."

### Accessibility Requirements

- "Delete Account" button: `accessibilityLabel("Delete account")` + `accessibilityHint("Permanently deletes your account and all data")`
- Confirmation alert: standard SwiftUI `.alert()` — VoiceOver reads title + message + buttons automatically
- Loading overlay: `accessibilityLabel("Removing your account")`

### Project Structure Notes

- Files to CREATE:
  - `CoachMe/Supabase/supabase/functions/delete-account/index.ts` — New Edge Function
- Files to MODIFY:
  - [SettingsView.swift](CoachMe/CoachMe/Features/Settings/Views/SettingsView.swift) — Add delete account button + confirmation + loading overlay
  - [SettingsViewModel.swift](CoachMe/CoachMe/Features/Settings/ViewModels/SettingsViewModel.swift) — Add deleteAccount() method + state
  - [AuthService.swift](CoachMe/CoachMe/Features/Auth/Services/AuthService.swift) — Add deleteAccount() method + AuthError case
- Alignment: Follows existing MVVM pattern; no new architectural patterns introduced

### References

- [Source: architecture.md#Authentication & Security] — Auth flow, biometric unlock, JWT tokens
- [Source: architecture.md#Project Structure] — `Features/Settings/Views/AccountDeletion.swift` mentioned in planned structure (we'll integrate into SettingsView instead to avoid unnecessary new file)
- [Source: architecture.md#API & Communication Patterns] — Edge Function patterns, error handling
- [Source: epics.md#Story 6.6] — FR29 Account deletion requirements
- [Source: 20260205000001_initial_schema.sql] — CASCADE DELETE chain from auth.users → public.users → all child tables
- [Source: 20260206000003_context_profiles.sql] — context_profiles CASCADE from users
- [Source: AuthService.swift:305-328] — Existing signOut() pattern to mirror
- [Source: SettingsView.swift:86-99] — Existing sign-out confirmation alert pattern
- [Source: SettingsViewModel.swift:94-113] — Existing signOut() method pattern
- [Source: KeychainManager.swift] — clearAllAuthData() for credential cleanup
- [Source: supabase/functions/_shared/auth.ts] — JWT verification helper
- [Source: supabase/functions/_shared/cors.ts] — CORS headers for Edge Functions
- [Source: supabase/functions/_shared/response.ts] — Standardized response format

### Git Intelligence

Recent commit pattern shows epic-level commits. Last 4 epics (1-4) are complete. Epic 6 is the first account/payment epic — no prior stories in this epic exist. The codebase follows consistent patterns established in Epics 1-4 that should be maintained.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
