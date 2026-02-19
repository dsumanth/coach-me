# Story 10.2: Device Fingerprint Tracking & Trial Abuse Prevention

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **system**,
I want **to track device identifiers alongside Apple IDs to detect trial abuse**,
so that **users cannot create multiple accounts to get unlimited free trials**.

## Acceptance Criteria

1. **Given** a user signs up for a trial **When** their account is created **Then** the device's `identifierForVendor` (IDFV) is recorded alongside their user ID

2. **Given** a new trial signup occurs **When** the system checks the device fingerprint **Then** it detects if this device has previously completed or abandoned a trial under a different Apple ID

3. **Given** a repeat trial is detected **When** the user tries to start the trial **Then** the trial is denied and the user sees: "Welcome back! It looks like you've tried Coach App before. Ready to pick up where you left off? [Subscribe]"

4. **Given** a legitimate user gets a new device **When** they sign in with their existing Apple ID **Then** the new device is associated with their account normally (no false positive)

## Tasks / Subtasks

- [x] Task 1: Create `device_fingerprints` database migration (AC: #1, #2)
  - [x] 1.1 Create migration file `CoachMe/Supabase/supabase/migrations/20260211000004_device_fingerprints.sql`
  - [x] 1.2 Define `device_fingerprints` table: `id` (UUID PK DEFAULT gen_random_uuid()), `user_id` (UUID NOT NULL FK → users ON DELETE CASCADE), `device_id` (TEXT NOT NULL — IDFV string), `first_seen_at` (TIMESTAMPTZ DEFAULT NOW()), `last_seen_at` (TIMESTAMPTZ DEFAULT NOW()), `trial_used` (BOOLEAN DEFAULT FALSE), `created_at` (TIMESTAMPTZ DEFAULT NOW()), `updated_at` (TIMESTAMPTZ DEFAULT NOW())
  - [x] 1.3 Add `UNIQUE(device_id)` constraint — one fingerprint record per physical device (NOT per user+device)
  - [x] 1.4 Enable RLS: `ALTER TABLE public.device_fingerprints ENABLE ROW LEVEL SECURITY`
  - [x] 1.5 RLS policies: users can SELECT, INSERT, UPDATE own records (`auth.uid() = user_id`)
  - [x] 1.6 Index: `idx_device_fingerprints_device_id ON (device_id)` — fast lookup during trial eligibility check
  - [x] 1.7 Index: `idx_device_fingerprints_user_id ON (user_id)` — user device listing
  - [x] 1.8 Add `updated_at` trigger via existing `handle_updated_at()` function
  - [x] 1.9 Add `COMMENT ON TABLE` describing purpose
  - [x] 1.10 Mirror migration to `supabase/migrations/20260211000006_device_fingerprints.sql` (root deploy path)

- [x] Task 2: Create `check_device_trial_eligibility` Supabase RPC function (AC: #2, #3, #4)
  - [x] 2.1 Add RPC to the same migration file as Task 1
  - [x] 2.2 Function signature: `check_device_trial_eligibility(p_device_id TEXT, p_user_id UUID) RETURNS JSON`
  - [x] 2.3 Logic: if no record for `p_device_id` → `{ eligible: true, reason: 'new_device' }`
  - [x] 2.4 Logic: if record exists with `user_id = p_user_id` → `{ eligible: true, reason: 'same_account' }`
  - [x] 2.5 Logic: if record exists with different `user_id` AND `trial_used = true` → `{ eligible: false, reason: 'trial_already_used' }`
  - [x] 2.6 Logic: if record exists with different `user_id` AND `trial_used = false` → `{ eligible: true, reason: 'device_transferred' }`
  - [x] 2.7 Use `SECURITY DEFINER` and `SET search_path = public, pg_catalog, pg_temp` (matches 10-1 RPC pattern)

- [x] Task 3: Create Swift models for device fingerprint (AC: #1)
  - [x] 3.1 Create `DeviceFingerprint` struct (Codable, Sendable, Equatable) — inline in `DeviceFingerprintService.swift`
  - [x] 3.2 Properties: `id: UUID`, `userId: UUID`, `deviceId: String`, `firstSeenAt: Date`, `lastSeenAt: Date`, `trialUsed: Bool`
  - [x] 3.3 `enum CodingKeys: String, CodingKey` with snake_case mapping: `user_id`, `device_id`, `first_seen_at`, `last_seen_at`, `trial_used`
  - [x] 3.4 Create `DeviceFingerprintUpsert` struct (Codable, Sendable) — properties: `userId: UUID`, `deviceId: String`; CodingKeys: `user_id`, `device_id`
  - [x] 3.5 Create `TrialEligibility` enum (Sendable, Equatable) — cases: `.eligible`, `.denied(reason: String)`
  - [x] 3.6 Create `TrialEligibilityResponse` struct (Codable) — properties: `eligible: Bool`, `reason: String`

- [x] Task 4: Create `DeviceFingerprintService.swift` (AC: #1, #2, #3, #4)
  - [x] 4.1 Create `@MainActor final class DeviceFingerprintService` in `CoachMe/CoachMe/Core/Services/`
  - [x] 4.2 `static let shared = DeviceFingerprintService()`, `private let supabase: SupabaseClient`
  - [x] 4.3 `private init()` accessing `AppEnvironment.shared.supabase`
  - [x] 4.4 Test-injectable `init(supabase: SupabaseClient)` (matches PushNotificationService, LearningSignalService)
  - [x] 4.5 Method: `registerDevice(userId: UUID) async throws` — get IDFV via `UIDevice.current.identifierForVendor?.uuidString`, guard nil (log + return silently), upsert with `onConflict: "device_id"`, update `last_seen_at` on conflict
  - [x] 4.6 Method: `checkTrialEligibility(userId: UUID) async throws -> TrialEligibility` — get IDFV (return `.eligible` if nil for simulator), call RPC `check_device_trial_eligibility`, parse response
  - [x] 4.7 Method: `markTrialUsed(userId: UUID) async throws` — get IDFV, update `trial_used = true` WHERE `device_id = IDFV AND user_id = userId`

- [x] Task 5: Integrate device registration into auth flow (AC: #1, #4)
  - [x] 5.1 In `AuthService.swift` → `signInWithApple()` success path: add non-blocking `Task { try? await DeviceFingerprintService.shared.registerDevice(userId: session.user.id) }` AFTER existing RevenueCat `Task` (~line 259)
  - [x] 5.2 In `AuthService.swift` → `restoreSession()` success path: add same non-blocking device registration call AFTER RevenueCat sync (~line 296)
  - [x] 5.3 Registration must NOT block or fail the auth flow — fire-and-forget `try?` pattern

- [x] Task 6: Expose trial eligibility API for downstream stories (AC: #2, #3)
  - [x] 6.1 `checkTrialEligibility()` and `markTrialUsed()` are public methods — consumed by Story 10.3
  - [x] 6.2 No additional wiring needed in this story — just expose the API

- [x] Task 7: Write unit tests (AC: #1-4)
  - [x] 7.1 Create `DeviceFingerprintServiceTests.swift` in `CoachMeTests/`
  - [x] 7.2 Test: `DeviceFingerprint` model encodes with correct snake_case keys
  - [x] 7.3 Test: `DeviceFingerprintUpsert` encodes `user_id` and `device_id` correctly
  - [x] 7.4 Test: `TrialEligibilityResponse` decodes from JSON correctly (eligible + denied cases)
  - [x] 7.5 Test: `TrialEligibility` enum equality
  - [x] 7.6 Test: Service initializes with injected Supabase client
  - [x] 7.7 Test: nil IDFV returns silently without error (simulator edge case)

## Dev Notes

### Design Principle
"Limits should feel like care, not walls." (Epic 10 design principle). The trial denial message uses warm, coaching-first voice per UX-11 error guidelines — never a cold system modal.

### Revenue Model Context
- **Trial model:** Free discovery session (Epic 11) → $2.99/week paid trial (3 days, auto-upgrades to $19.99/month) → 100 messages during trial, 800/month after
- **Device fingerprinting prevents** users from creating multiple Apple IDs to get unlimited free trials
- **IDFV persists** across reinstalls as long as at least one app from the same vendor is installed — good enough for abuse detection

### Architecture Patterns & Constraints

**Service Pattern (MUST follow):**
```swift
@MainActor
final class DeviceFingerprintService {
    static let shared = DeviceFingerprintService()
    private let supabase: SupabaseClient

    private init() {
        self.supabase = AppEnvironment.shared.supabase
    }

    // Test-injectable
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
}
```
[Source: CoachMe/Core/Services/PushNotificationService.swift — exact pattern]
[Source: CoachMe/Core/Services/LearningSignalService.swift — exact pattern]

**Non-blocking Auth Integration Pattern:**
```swift
// In AuthService.signInWithApple() success path, AFTER RevenueCat sync:
Task {
    try? await DeviceFingerprintService.shared.registerDevice(userId: session.user.id)
}
```
[Source: CoachMe/Features/Auth/Services/AuthService.swift:259-261 — RevenueCat Task pattern]

**Codable Model Pattern:**
```swift
struct DeviceFingerprintUpsert: Codable, Sendable {
    let userId: UUID
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
    }
}
```
[Source: CoachMe/Features/Context/Models/ContextProfile.swift — CodingKeys convention]
[Source: CoachMe/Core/Services/PushNotificationService.swift — PushTokenUpsert inline struct]

### Critical Guardrails

1. **Do NOT use IDFA** (advertising identifier) — requires App Tracking Transparency permission, wrong use case, Apple **will reject** for misuse
2. **Use ONLY `UIDevice.current.identifierForVendor`** (IDFV) — no permissions needed, available immediately
3. **IDFV can be nil on simulators** — always `guard let` and fail gracefully (return `.eligible` for eligibility, return silently for registration)
4. **Device registration is NON-BLOCKING**: Auth flow must NEVER be delayed or fail due to fingerprint failure. Use `try?` inside `Task { }`
5. **RPC function is `SECURITY DEFINER`**: Runs server-side with elevated permissions to bypass RLS — prevents client-side manipulation
6. **Family sharing edge case**: Same physical device, different Apple IDs — accepted as "acceptable leakage" per product decision. Do NOT try to solve.
7. **UNIQUE on `device_id` NOT `(user_id, device_id)`**: One record per device. If a different user signs in on same device, original record persists — this is how abuse is detected
8. **The RPC checks across ALL users**: Must look at ALL records for a `device_id`, not just current user's records

### Database Schema

```sql
CREATE TABLE IF NOT EXISTS public.device_fingerprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    trial_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id)
);

-- RPC function for server-side eligibility check
CREATE OR REPLACE FUNCTION public.check_device_trial_eligibility(
    p_device_id TEXT,
    p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
    existing_record RECORD;
BEGIN
    SELECT user_id, trial_used INTO existing_record
    FROM public.device_fingerprints
    WHERE device_id = p_device_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eligible', true, 'reason', 'new_device');
    END IF;

    IF existing_record.user_id = p_user_id THEN
        RETURN json_build_object('eligible', true, 'reason', 'same_account');
    END IF;

    IF existing_record.trial_used THEN
        RETURN json_build_object('eligible', false, 'reason', 'trial_already_used');
    END IF;

    RETURN json_build_object('eligible', true, 'reason', 'device_transferred');
END;
$$;
```

### Previous Story Intelligence (10-1)

Story 10-1 establishes the `message_usage` table and `increment_and_check_usage` RPC for rate limiting. Key patterns from 10-1 to follow in 10-2:

- **Migration naming**: Uses `20260211000003` prefix — 10-2 uses `20260211000004`
- **RPC pattern**: `SECURITY DEFINER` + `SET search_path = public, pg_catalog, pg_temp`
- **Root deploy mirror**: Story 10-1 mirrors migration to `supabase/migrations/` — 10-2 must do the same
- **Subscription status context**: Already loaded in `chat-stream/index.ts` from `users.subscription_status`
- **Session mode integration**: `determineSessionMode()` from `_shared/session-mode.ts` returns `'discovery' | 'coaching' | 'blocked'`

10-2 is **independent** of 10-1 at implementation time. Device fingerprinting does not depend on message counting. Both feed into Story 10.3 (Paid Trial Activation).

### File Locations

**New files to create:**
- `CoachMe/CoachMe/Core/Services/DeviceFingerprintService.swift` — service + models
- `CoachMe/Supabase/supabase/migrations/20260211000004_device_fingerprints.sql` — table + RPC + RLS
- `CoachMe/CoachMeTests/DeviceFingerprintServiceTests.swift` — unit tests
- `supabase/migrations/20260211000006_device_fingerprints.sql` — root deploy mirror

**Existing files to modify:**
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift` — add 2 non-blocking `Task` calls for device registration (in `signInWithApple()` and `restoreSession()`)

**Alignment with existing patterns:**
- Migration naming: `YYYYMMDD00000N_description.sql` ✓
- RPC pattern: `SECURITY DEFINER` + `SET search_path` ✓ (matches 10-1)
- RLS pattern: `auth.uid() = user_id` ✓
- Service pattern: `@MainActor` singleton + test-injectable init ✓
- Models: inline structs with snake_case CodingKeys ✓
- iOS concurrency: `@MainActor` on all services ✓

### Testing Standards
- `@MainActor` on test class (required for Swift 6 strict concurrency)
- Mock Supabase client via test-injectable initializer
- Test CodingKeys encoding produces snake_case JSON keys
- Test nil IDFV handling (simulator edge case)
- Test eligibility response parsing
- **DO NOT run tests automatically** — user runs manually after review
- Recommended test command: `-only-testing:CoachMeTests/DeviceFingerprintServiceTests`

### Project Structure Notes

- Service in `Core/Services/` — consistent with `PushNotificationService`, `LearningSignalService`, `OfflineSyncService`
- Models inline in service file (small, tightly coupled) — consistent with `PushNotificationService` which has `PushTokenUpsert` as private struct
- Migration in `CoachMe/Supabase/supabase/migrations/` — consistent with all existing migrations
- Tests in `CoachMeTests/` flat directory — consistent with all existing test files
- No detected conflicts or variances with existing project structure

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.2] — Story requirements, AC, technical notes
- [Source: _bmad-output/implementation-artifacts/stories/10-1-message-rate-limiting-infrastructure.md] — Previous story patterns, RPC convention, migration naming
- [Source: CoachMe/Features/Auth/Services/AuthService.swift] — auth flow, non-blocking Task pattern (lines 259-261, 296-299)
- [Source: CoachMe/Core/Services/PushNotificationService.swift] — @MainActor singleton service pattern, PushTokenUpsert inline model
- [Source: CoachMe/Core/Services/LearningSignalService.swift] — fire-and-forget write pattern
- [Source: CoachMe/Features/Context/Models/ContextProfile.swift] — CodingKeys snake_case convention
- [Source: CoachMe/Supabase/supabase/migrations/20260210000001_learning_signals.sql] — migration structure pattern
- [Source: CoachMe/Supabase/supabase/migrations/20260208000001_increment_surface_count_rpc.sql] — SECURITY DEFINER RPC pattern
- [Source: CoachMe/Features/Subscription/Services/SubscriptionService.swift] — RevenueCat integration
- [Source: CoachMe/Supabase/supabase/functions/_shared/session-mode.ts] — subscription status handling

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build error: Mixed dictionary types in `markTrialUsed()` update call. Fixed by introducing `TrialUsedUpdate` Codable struct.

### Completion Notes List

- Ultimate context engine analysis completed — comprehensive developer guide created
- Created `device_fingerprints` table with UNIQUE(device_id) constraint, RLS policies (SELECT/INSERT/UPDATE), indexes, and updated_at trigger
- Created `check_device_trial_eligibility` RPC (SECURITY DEFINER) with 4 eligibility paths: new_device, same_account, trial_already_used, device_transferred
- Created `DeviceFingerprintService` with @MainActor singleton pattern, test-injectable init, 3 public methods (registerDevice, checkTrialEligibility, markTrialUsed)
- Inline models: DeviceFingerprint, DeviceFingerprintUpsert, TrialEligibility enum, TrialEligibilityResponse — all with snake_case CodingKeys
- Integrated non-blocking device registration into AuthService (signInWithApple + restoreSession) using fire-and-forget `Task { try? await ... }` pattern
- 13 unit tests covering: model encoding/decoding, CodingKeys snake_case, TrialEligibility enum equality, service initialization, JSON response parsing
- Main app target BUILD SUCCEEDED; test target has pre-existing failures in unrelated files (ContextProfile mock conformance issues from previous stories)

### Implementation Plan

- Followed exact patterns from PushNotificationService (singleton, inline models, test-injectable init)
- RPC uses SECURITY DEFINER to bypass RLS for cross-user device checks
- IDFV nil handling: graceful degradation (return .eligible on simulator, return silently on registration)
- Auth integration: fire-and-forget pattern matching RevenueCat sync pattern

### File List

**New files:**
- `CoachMe/CoachMe/Core/Services/DeviceFingerprintService.swift`
- `CoachMe/Supabase/supabase/migrations/20260211000004_device_fingerprints.sql`
- `CoachMe/CoachMeTests/DeviceFingerprintServiceTests.swift`
- `supabase/migrations/20260211000006_device_fingerprints.sql`

**Modified files:**
- `CoachMe/CoachMe/Features/Auth/Services/AuthService.swift`

### Change Log

- 2026-02-10: Story 10.2 implementation complete — device fingerprint tracking, trial eligibility RPC, service layer, auth integration, and unit tests