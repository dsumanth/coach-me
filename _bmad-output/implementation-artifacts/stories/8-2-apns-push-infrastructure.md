# Story 8.2: APNs Push Infrastructure

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want **push notifications configured with Apple Push Notification service**,
So that **the app can deliver proactive coaching nudges between sessions**.

## Acceptance Criteria

1. **Given** the app launches and user has granted push permission, **When** the device token is obtained from APNs, **Then** it is registered in the `push_tokens` table in Supabase (upsert — same user+device updates existing row).

2. **Given** a push notification is triggered from the backend, **When** it is sent via the `push-send` Edge Function through APNs HTTP/2 API, **Then** the notification appears correctly on the user's device with title, body, and custom payload.

3. **Given** a user taps a push notification, **When** the app opens, **Then** it navigates to the relevant conversation (if `conversation_id` is in the payload) or starts a new one.

4. **Given** the app relaunches or resumes from background, **When** the device token may have changed, **Then** the service re-registers the current token with the backend (token refresh).

5. **Given** APNs returns an invalid/expired token error, **When** the `push-send` Edge Function detects it, **Then** the stale token row is deleted from `push_tokens` and the error is logged (no retry to dead token).

6. **Given** the user has not yet granted push permission, **When** `PushNotificationService` is initialized, **Then** it does NOT request permission (permission timing is Story 8.3) — it only registers if already authorized.

## Tasks / Subtasks

- [x] **Task 1 — Supabase migration: `push_tokens` table** (AC: #1, #4, #5)
  - [x] 1.1 Create migration file `20260210000003_push_tokens.sql` (sequenced after existing 20260210000002)
  - [x] 1.2 Create `push_tokens` table with columns: `id`, `user_id`, `device_token`, `platform`, `created_at`, `updated_at`
  - [x] 1.3 Add UNIQUE constraint on (`user_id`, `device_token`) for upsert
  - [x] 1.4 Enable RLS — users can only read/write/delete their own tokens
  - [x] 1.5 Add index on `user_id` for efficient lookup
  - [x] 1.6 Add `updated_at` trigger for automatic timestamp update
  - [x] 1.7 Add table/column comments

- [x] **Task 2 — `PushNotificationService.swift`** (AC: #1, #4, #6)
  - [x] 2.1 Create `PushNotificationService.swift` in `Core/Services/`
  - [x] 2.2 Follow `@MainActor` singleton pattern with test-injectable init
  - [x] 2.3 Implement `registerDeviceToken(_ tokenData: Data)` — converts to hex string, upserts to Supabase `push_tokens`
  - [x] 2.4 Implement `checkCurrentAuthorization() -> UNAuthorizationStatus` — returns current permission status without prompting
  - [x] 2.5 Implement `registerForRemoteNotificationsIfAuthorized()` — calls `UIApplication.shared.registerForRemoteNotifications()` only if already `.authorized`
  - [x] 2.6 Implement `handleRegistrationError(_ error: Error)` — logs failure, does not crash
  - [x] 2.7 Implement `removeDeviceToken()` — deletes current token from Supabase on sign-out

- [x] **Task 3 — AppDelegate push integration** (AC: #1, #3, #4)
  - [x] 3.1 Create `AppDelegate.swift` in `App/` with `UIApplicationDelegate` conformance
  - [x] 3.2 Implement `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` — forwards to `PushNotificationService`
  - [x] 3.3 Implement `application(_:didFailToRegisterForRemoteNotificationsWithError:)` — logs error
  - [x] 3.4 Adopt `UNUserNotificationCenterDelegate` — implement `userNotificationCenter(_:willPresent:)` for foreground notifications
  - [x] 3.5 Implement `userNotificationCenter(_:didReceive:)` — parse `conversation_id` from payload and navigate
  - [x] 3.6 Set `UNUserNotificationCenter.current().delegate = self` in `application(_:didFinishLaunchingWithOptions:)`
  - [x] 3.7 Wire AppDelegate into SwiftUI App lifecycle via `@UIApplicationDelegateAdaptor`

- [x] **Task 4 — Deep link navigation from notification tap** (AC: #3)
  - [x] 4.1 Define notification payload schema: `{ "conversation_id": "uuid", "domain": "string", "action": "open_conversation" | "new_conversation" }`
  - [x] 4.2 Create `NotificationRouter` to handle `conversation_id` routing
  - [x] 4.3 **Validate and sanitize notification payloads before navigation:**
    - (a) Validate payload schema — UUID(uuidString:) validation for conversation_id
    - (b) Verify conversation exists and current user has access via ConversationService.conversationExists
    - (c) On any validation failure, fall back to starting a new conversation with debug logging
  - [x] 4.4 If `conversation_id` provided and passes validation → navigate to that conversation in ChatView
  - [x] 4.5 If no `conversation_id` or validation fails → start new conversation (default/fallback behavior)
  - [x] 4.6 Handle app-not-running case (cold launch from notification) — pendingNotificationPayload stored and processed after auth restoration in RootView

- [x] **Task 5 — `push-send` Edge Function** (AC: #2, #5)
  - [x] 5.1 Create `Supabase/supabase/functions/push-send/index.ts`
  - [x] 5.2 Follow existing Edge Function pattern: CORS → auth → logic → response
  - [x] 5.3 Accept request body: `{ user_id, title, body, data: { conversation_id?, domain?, action? } }`
  - [x] 5.4 Look up device tokens from `push_tokens` WHERE `user_id` matches
  - [x] 5.5 Construct APNs HTTP/2 request with JWT-based provider authentication (`.p8` key via jose library)
  - [x] 5.6 Send notification to all user tokens (user may have multiple devices)
  - [x] 5.7 Handle APNs error responses — delete invalid/unregistered tokens from `push_tokens`
  - [x] 5.8 Return success/failure summary in response
  - [x] 5.9 Store APNs key ID, team ID, and `.p8` key content as Supabase secrets (environment variables)

- [x] **Task 6 — Xcode project configuration** (AC: #1)
  - [x] 6.1 Push Notifications capability via aps-environment entitlement (project uses PBXFileSystemSynchronizedRootGroup — no manual pbxproj edits needed)
  - [x] 6.2 Add `aps-environment` entitlement to `CoachMe.entitlements` (value: `development`)
  - [x] 6.3 Verify signing & capabilities — entitlements file already referenced in project.pbxproj CODE_SIGN_ENTITLEMENTS

- [x] **Task 7 — Tests** (AC: all)
  - [x] 7.1 Create `PushNotificationServiceTests.swift` — test token hex conversion, error descriptions, upsert encoding
  - [x] 7.2 Test notification payload parsing and routing logic (UUID validation, missing/malformed/null payloads, pending payload storage/processing, navigation)
  - [x] 7.3 Edge Function validated via code review (TypeScript — manual validation recommended)

## Dev Notes

### Architecture Patterns & Constraints

- **Swift 6 Strict Concurrency**: `PushNotificationService` MUST be `@MainActor`. All Supabase calls are `async/await`. UIApplication.registerForRemoteNotifications() must be called on main thread.
- **Singleton + DI pattern**: Use `static let shared` with `private init()` accessing `AppEnvironment.shared.supabase`. Provide `init(supabase:)` for testing.
- **No permission prompting in this story**: Story 8.3 handles permission timing/UX. This story only registers if already authorized and builds the plumbing.
- **Token format**: APNs returns `Data` — convert to hex string via `tokenData.map { String(format: "%02x", $0) }.joined()`. Do NOT use `description` (includes angle brackets).
- **Upsert pattern**: Use Supabase `.upsert(_, onConflict: "user_id,device_token")` for idempotent registration (matches existing project pattern from `ContextRepository`).
- **Error messaging**: Warm, first-person per UX-11 — "I couldn't register for notifications right now" not "Push registration failed."
- **Non-blocking**: Token registration must never block the user experience. Fire-and-forget with error logging.

### APNs Provider Authentication (Token-Based / `.p8` Key)

The `push-send` Edge Function uses **token-based authentication** (recommended over certificate-based):

1. **Secrets required** (set via `supabase secrets set`):
   - `APNS_KEY_ID` — 10-character Key ID from Apple Developer Portal
   - `APNS_TEAM_ID` — Apple Developer Team ID
   - `APNS_PRIVATE_KEY` — Contents of the `.p8` file (the private key string)
   - `APNS_BUNDLE_ID` — App bundle identifier (`com.yourteam.CoachMe`)

2. **JWT construction** in Edge Function:
   - Header: `{ "alg": "ES256", "kid": APNS_KEY_ID }`
   - Payload: `{ "iss": APNS_TEAM_ID, "iat": <unix_timestamp> }`
   - Sign with `.p8` private key using ES256
   - Cache JWT for up to 60 minutes (APNs allows 1-hour validity)

3. **APNs endpoint**:
   - Development: `https://api.sandbox.push.apple.com:443`
   - Production: `https://api.push.apple.com:443`
   - Use environment variable `APNS_ENVIRONMENT` to switch (`sandbox` vs `production`)

4. **Request format**:
   ```
   POST /3/device/{device_token}
   Headers:
     authorization: bearer {jwt}
     apns-topic: {bundle_id}
     apns-push-type: alert
     apns-priority: 10
   Body: { "aps": { "alert": { "title": ..., "body": ... }, "sound": "default" }, "data": { ... } }
   ```

### Notification Payload Schema

```json
{
  "aps": {
    "alert": {
      "title": "Your coach is thinking of you",
      "body": "Still thinking about what we discussed around career growth?"
    },
    "sound": "default",
    "badge": 1
  },
  "conversation_id": "uuid-or-null",
  "domain": "career",
  "action": "open_conversation"
}
```

- `conversation_id`: If present, deep-link to existing conversation. If null/absent, open new conversation.
- `domain`: Routing hint for new conversations (used by Story 8.7 later).
- `action`: `"open_conversation"` or `"new_conversation"` — determines navigation behavior.

### AppDelegate + SwiftUI Integration

The project currently uses a pure SwiftUI `@main App` struct. To receive push delegate callbacks:

```swift
// In CoachMeApp.swift
@main
struct CoachMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // ...
}
```

```swift
// In App/AppDelegate.swift
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    // ... push delegate methods
}
```

**Check if AppDelegate already exists** before creating — the project may already have one from Sign In with Apple or other features.

### Existing Edge Function Patterns to Follow

From `chat-stream/index.ts` and `delete-account/index.ts`:

```typescript
import { verifyAuth } from "../_shared/auth.ts";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { errorResponse } from "../_shared/response.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { userId, supabase } = await verifyAuth(req);
    // ... business logic
    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return errorResponse(error.message, 500);
  }
});
```

The `push-send` function is different: it may be called server-to-server (e.g., by a scheduled function or another Edge Function), not directly by the iOS client. Use **service role key** authentication for server-to-server calls, not user JWT. However, also support user-JWT auth for direct "send test push" scenarios with the following safeguards:

**Auth branching in push-send:**
1. **Service-role key:** Full server-to-server behavior — can send to any `user_id`, no rate limiting, used by `push-trigger` and other Edge Functions.
2. **User-JWT auth:** Restricted behavior for "send test push" scenarios:
   - Verify the JWT's `userId` matches the `payload.user_id` — reject with 403 if mismatched (users can only send test pushes to themselves).
   - Enforce per-user rate limiting: max 10 test pushes per user per rolling hour (use a Supabase query on `push_log` or an in-memory counter keyed by `userId`).
   - **Gate to non-production environments only:** Check `APNS_ENVIRONMENT` (or a dedicated `PUSH_SEND_ALLOW_USER_JWT` env var). In production (`APNS_ENVIRONMENT === 'production'`), reject user-JWT requests with 403 and a message: "Test push is only available in development environments." Service-role behavior is unchanged in all environments.

### Migration Naming Convention

Existing migrations follow: `YYYYMMDD######_description.sql`

Latest migration: `20260209000001_sync_conflict_logs.sql`

New migration: `20260210000001_push_tokens.sql`

### `push_tokens` Table Schema

```sql
CREATE TABLE IF NOT EXISTS public.push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON public.push_tokens(user_id);

-- RLS: users manage their own tokens
CREATE POLICY "Users can view own tokens" ON public.push_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own tokens" ON public.push_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own tokens" ON public.push_tokens FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own tokens" ON public.push_tokens FOR DELETE USING (auth.uid() = user_id);

-- Service role policy: The push-send Edge Function uses the Supabase service_role key
-- to delete invalid/expired tokens returned by APNs. The service_role key bypasses RLS
-- by default in Supabase, so no additional policy is needed. However, document this
-- explicitly: push-send MUST use SUPABASE_SERVICE_ROLE_KEY (not the anon key) when
-- deleting stale tokens. If RLS bypass is ever disabled for service_role, add:
-- CREATE POLICY "Service role manages tokens" ON public.push_tokens FOR ALL USING (auth.role() = 'service_role');

-- Automatic updated_at trigger — reuse the existing project-wide function
-- (public.handle_updated_at() is already used by context_profiles, learning_signals, etc.)
CREATE TRIGGER update_push_tokens_updated_at
    BEFORE UPDATE ON public.push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
```

### Project Structure Notes

- **New files follow existing structure**:
  - `CoachMe/Core/Services/PushNotificationService.swift` — alongside `ConversationService.swift`, `NetworkMonitor.swift`
  - `CoachMe/App/AppDelegate.swift` — in the App directory (check if exists first)
  - `Supabase/supabase/functions/push-send/index.ts` — alongside `chat-stream/`, `delete-account/`
  - `Supabase/migrations/20260210000001_push_tokens.sql` — follows existing migration numbering
  - `CoachMeTests/PushNotificationServiceTests.swift` — alongside existing test files
- **Entitlements**: Update `CoachMe/CoachMe/CoachMe.entitlements` to add `aps-environment`
- **Info.plist**: No changes needed — push notifications don't require Info.plist keys on iOS 18+
- **No SwiftData model needed**: `push_tokens` is server-side only. The device token is ephemeral — just register on launch, no local caching required.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.2] — Story requirements, acceptance criteria, technical notes
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 8] — Epic context: "A real coach has no dashboard" design principle
- [Source: _bmad-output/planning-artifacts/architecture.md] — Service patterns, Edge Function conventions, migration patterns, security requirements
- [Source: CoachMe/Core/Services/ConversationService.swift] — @MainActor singleton service pattern reference
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts] — Edge Function pattern reference
- [Source: CoachMe/Supabase/supabase/functions/_shared/auth.ts] — JWT verification pattern
- [Source: CoachMe/Supabase/migrations/] — Migration naming and SQL conventions
- [Source: CoachMe/CoachMe/CoachMe.entitlements] — Current entitlements (needs aps-environment added)
- [Source: CoachMe/CoachMe/App/Environment/AppEnvironment.swift] — Dependency container pattern
- [Source: CoachMe/Core/Data/Repositories/ContextRepository.swift] — Upsert pattern reference

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Migration numbering: Used `20260210000003` (not `20260210000001` as originally spec'd) because `20260210000001_learning_signals.sql` and `20260210000002_coaching_preferences.sql` already exist.
- SourceKit diagnostics for `No such module 'UIKit'` / `No such module 'XCTest'` in editor are expected — these resolve when building for iOS Simulator target.
- Project uses `PBXFileSystemSynchronizedRootGroup` — new Swift files in the `CoachMe/` and `CoachMeTests/` directories are auto-discovered by Xcode (no pbxproj edits required).

### Completion Notes List

- **Task 1**: Created `push_tokens` migration with all columns, UNIQUE constraint, RLS policies, index, trigger, and comments. Follows existing migration patterns.
- **Task 2**: `PushNotificationService` — `@MainActor` singleton with test-injectable init. Hex token conversion, upsert registration, authorization check (no prompting per AC #6), error logging, and sign-out token removal. All operations are non-blocking.
- **Task 3**: Created `AppDelegate.swift` with `UIApplicationDelegate` + `UNUserNotificationCenterDelegate`. Wired via `@UIApplicationDelegateAdaptor` in `CoachMeApp.swift`. Foreground notifications show as banners. Token refresh on each launch via `registerForRemoteNotificationsIfAuthorized()` in `RootView.checkAuthState()`.
- **Task 4**: Created `NotificationRouter` singleton. UUID validation, conversation ownership check via `ConversationService.conversationExists()`, fallback to new chat on any failure. Cold-launch support via `pendingNotificationPayload` processed after auth restoration. Connected to app `Router` via `RootView.task {}`.
- **Task 5**: `push-send` Edge Function with dual auth (service-role + user-JWT). Service-role: unrestricted. User-JWT: self-only, rate-limited (10/hr), non-production only. APNs JWT cached for 50 min using `jose` library. Stale token cleanup on BadDeviceToken/Unregistered/ExpiredToken/410 responses. Follows existing CORS/auth/response patterns.
- **Task 6**: Added `aps-environment: development` to `CoachMe.entitlements`. Entitlements file already referenced in pbxproj `CODE_SIGN_ENTITLEMENTS`.
- **Task 7**: 14 unit tests covering token hex conversion, error descriptions, CodingKeys encoding, payload parsing (valid/missing/malformed/null), pending payload lifecycle, and navigation routing.
- **AuthService integration**: Added `PushNotificationService.shared.removeDeviceToken()` call in `AuthService.signOut()` so server stops pushing after sign-out.

### Change Log

- 2026-02-09: Story 8.2 implementation complete — APNs push infrastructure with migration, iOS service, AppDelegate integration, deep link navigation, Edge Function, Xcode configuration, and tests.
- 2026-02-09: Code review fixes (Claude Opus 4.6) — H1: fixed test hex assertion typo; H2: `removeDeviceToken()` now scopes to current device only; H3: documented in-memory rate limit limitation in Edge Function; H4: added `removeDeviceToken()` to `deleteAccount()`; M1+M2: added DI to NotificationRouter + 2 new tests for conversation-exists paths; M3: added UUID validation for `user_id` in push-send.

### File List

**New files:**
- `CoachMe/Supabase/supabase/migrations/20260210000003_push_tokens.sql`
- `CoachMe/CoachMe/Core/Services/PushNotificationService.swift`
- `CoachMe/CoachMe/App/AppDelegate.swift`
- `CoachMe/CoachMe/App/Navigation/NotificationRouter.swift`
- `CoachMe/Supabase/supabase/functions/push-send/index.ts`
- `CoachMe/CoachMeTests/PushNotificationServiceTests.swift`

**Modified files:**
- `CoachMe/CoachMe/CoachMeApp.swift` — added `@UIApplicationDelegateAdaptor(AppDelegate.self)`
- `CoachMe/CoachMe/App/Navigation/RootView.swift` — added push registration on auth, NotificationRouter wiring, pending notification processing
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` — added `removeDeviceToken()` call in `signOut()` and `deleteAccount()`
- `CoachMe/CoachMe/CoachMe.entitlements` — added `aps-environment: development`
