# Story 1.3: Supabase Project Setup & Core Database Schema

Status: done

## Story

As a **developer**,
I want **Supabase configured with the core database schema**,
So that **user data and conversations can be stored securely**.

## Acceptance Criteria

1. **AC1 — Supabase Project Created with Apple OAuth**
   - Given a new Supabase project
   - When I configure auth settings
   - Then Apple OAuth provider is enabled and configured with proper redirect URLs

2. **AC2 — Core Tables Created with Migrations**
   - Given Supabase auth is configured
   - When I create migrations for `users`, `conversations`, `messages` tables
   - Then tables are created with proper foreign keys, indexes, and JSONB columns per architecture

3. **AC3 — Row Level Security Enabled**
   - Given tables exist
   - When I add Row Level Security policies
   - Then users can only read/write their own data (no cross-user data access)

4. **AC4 — iOS App Connects to Supabase**
   - Given the Supabase project is configured
   - When I update environment variables in Xcode Configuration.swift
   - Then the iOS app can successfully connect to Supabase and verify the connection

## Tasks / Subtasks

- [x] Task 1: Create Supabase Project (AC: #1)
  - [x] 1.1 Go to [supabase.com](https://supabase.com) and create a new project named "coach-app"
  - [x] 1.2 Select region closest to target users (e.g., us-east-1)
  - [x] 1.3 Set a strong database password and save it securely
  - [x] 1.4 Wait for project provisioning to complete
  - [x] 1.5 Copy Project URL and Publishable API key from Settings → API
  - **Note:** Project URL: `https://xzsvzbjxlsnhxyrglvjp.supabase.co`

- [x] Task 2: Configure Apple OAuth Provider (AC: #1) — **COMPLETED**
  - [x] 2.1 In Supabase Dashboard: Authentication → Providers → Apple
  - [x] 2.2 Enable Apple provider
  - [x] 2.3 Note the callback URL: `https://xzsvzbjxlsnhxyrglvjp.supabase.co/auth/v1/callback`
  - [x] 2.4 In Apple Developer Portal:
    - [x] 2.4.1 Create a Services ID for Sign in with Apple (`com.yourname.coachme.auth`)
    - [x] 2.4.2 Configure the Services ID with Supabase callback URL as redirect
    - [x] 2.4.3 Create/download a Key for Sign in with Apple (Key ID: H8R998WZJ6)
  - [x] 2.5 In Supabase Dashboard, enter:
    - [x] 2.5.1 Apple Client ID: `com.yourname.coachme.auth`
    - [x] 2.5.2 Apple Secret Key: JWT generated from .p8 file
    - [x] 2.5.3 Apple Key ID: `H8R998WZJ6`
    - [x] 2.5.4 Apple Team ID: `R67735N7V8`
  - [x] 2.6 Save provider settings
  - **Note:** JWT secret expires 2026-08-04. Script saved at `generate_apple_secret.js` to regenerate.

- [x] Task 3: Create Initial Schema Migration (AC: #2)
  - [x] 3.1 Create migration file: `CoachMe/Supabase/migrations/20260205000001_initial_schema.sql`
  - [x] 3.2 Add `users` table (extends auth.users):
    ```sql
    -- Users table extending Supabase Auth
    -- Note: auth.users is managed by Supabase Auth; this table stores app-specific fields
    CREATE TABLE IF NOT EXISTS public.users (
        id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
        email TEXT,
        display_name TEXT,
        avatar_url TEXT,
        subscription_status TEXT DEFAULT 'trial',
        trial_ends_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Enable RLS
    ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

    -- Create index for lookups
    CREATE INDEX idx_users_email ON public.users(email);
    CREATE INDEX idx_users_subscription_status ON public.users(subscription_status);
    ```
  - [x] 3.3 Add `conversations` table:
    ```sql
    -- Conversations table
    CREATE TABLE IF NOT EXISTS public.conversations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        title TEXT,
        domain TEXT, -- coaching domain: life, career, relationships, mindset, creativity, fitness, leadership
        last_message_at TIMESTAMPTZ,
        message_count INTEGER DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Enable RLS
    ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

    -- Indexes
    CREATE INDEX idx_conversations_user_id ON public.conversations(user_id);
    CREATE INDEX idx_conversations_last_message_at ON public.conversations(last_message_at DESC);
    CREATE INDEX idx_conversations_domain ON public.conversations(domain);
    ```
  - [x] 3.4 Add `messages` table:
    ```sql
    -- Messages table
    CREATE TABLE IF NOT EXISTS public.messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
        content TEXT NOT NULL,
        token_count INTEGER,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Enable RLS
    ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

    -- Indexes
    CREATE INDEX idx_messages_conversation_id ON public.messages(conversation_id);
    CREATE INDEX idx_messages_user_id ON public.messages(user_id);
    CREATE INDEX idx_messages_created_at ON public.messages(created_at);
    ```
  - [x] 3.5 Add updated_at trigger function:
    ```sql
    -- Trigger function for updated_at
    CREATE OR REPLACE FUNCTION public.handle_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    -- Apply trigger to users table
    CREATE TRIGGER users_updated_at
        BEFORE UPDATE ON public.users
        FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

    -- Apply trigger to conversations table
    CREATE TRIGGER conversations_updated_at
        BEFORE UPDATE ON public.conversations
        FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
    ```

- [x] Task 4: Create RLS Policies Migration (AC: #3)
  - [x] 4.1 Create migration file: `CoachMe/Supabase/migrations/20260205000002_rls_policies.sql`
  - [x] 4.2 Add users table RLS policies:
    ```sql
    -- Users: users can only access their own row
    CREATE POLICY "Users can view own profile"
        ON public.users FOR SELECT
        USING (auth.uid() = id);

    CREATE POLICY "Users can update own profile"
        ON public.users FOR UPDATE
        USING (auth.uid() = id);

    CREATE POLICY "Users can insert own profile"
        ON public.users FOR INSERT
        WITH CHECK (auth.uid() = id);

    CREATE POLICY "Users can delete own profile"
        ON public.users FOR DELETE
        USING (auth.uid() = id);
    ```
  - [x] 4.3 Add conversations table RLS policies:
    ```sql
    -- Conversations: users can only access their own conversations
    CREATE POLICY "Users can view own conversations"
        ON public.conversations FOR SELECT
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can create own conversations"
        ON public.conversations FOR INSERT
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own conversations"
        ON public.conversations FOR UPDATE
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can delete own conversations"
        ON public.conversations FOR DELETE
        USING (auth.uid() = user_id);
    ```
  - [x] 4.4 Add messages table RLS policies:
    ```sql
    -- Messages: users can only access their own messages
    CREATE POLICY "Users can view own messages"
        ON public.messages FOR SELECT
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can create own messages"
        ON public.messages FOR INSERT
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own messages"
        ON public.messages FOR UPDATE
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can delete own messages"
        ON public.messages FOR DELETE
        USING (auth.uid() = user_id);
    ```

- [x] Task 5: Apply Migrations to Supabase (AC: #2, #3) — **COMPLETED**
  - [x] 5.1 In Supabase Dashboard: SQL Editor
  - [x] 5.2 Run the contents of `20260205000001_initial_schema.sql`
  - [x] 5.3 Verify tables created: Database → Tables should show users, conversations, messages
  - [x] 5.4 Run the contents of `20260205000002_rls_policies.sql`
  - [x] 5.5 Verify RLS enabled: Database → Tables → each table shows "RLS enabled"
  - [x] 5.6 Verify policies: Authentication → Policies shows all policies
  - [x] 5.7 Run the contents of `20260205000003_user_sync_trigger.sql`
  - **Note:** All three migrations run successfully by user on 2026-02-05

- [x] Task 6: Create User Sync Function (AC: #2)
  - [x] 6.1 Create migration file: `CoachMe/Supabase/migrations/20260205000003_user_sync_trigger.sql`
  - [x] 6.2 Add function to auto-create public.users row when auth.users row is created:
    ```sql
    -- Function to sync auth.users to public.users
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO public.users (id, email, display_name, trial_ends_at)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
            NOW() + INTERVAL '7 days'
        );
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- Trigger on auth.users insert
    CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
    ```
  - [x] 6.3 Apply migration via SQL Editor — **Completed via Task 5**

- [x] Task 7: Update iOS Configuration (AC: #4)
  - [x] 7.1 Update `CoachMe/CoachMe/App/Environment/Configuration.swift`:
    ```swift
    import Foundation

    enum Environment {
        case development
        case staging
        case production
    }

    struct Configuration {
        static let current: Environment = .development

        static var supabaseURL: String {
            switch current {
            case .development:
                return "https://YOUR_PROJECT_REF.supabase.co"
            case .staging:
                return "https://YOUR_STAGING_PROJECT_REF.supabase.co"
            case .production:
                return "https://YOUR_PRODUCTION_PROJECT_REF.supabase.co"
            }
        }

        static var supabaseAnonKey: String {
            switch current {
            case .development:
                return "YOUR_ANON_KEY_HERE"
            case .staging:
                return "YOUR_STAGING_ANON_KEY_HERE"
            case .production:
                return "YOUR_PRODUCTION_ANON_KEY_HERE"
            }
        }

        /// Validates configuration at app launch (DEBUG only)
        static func validateConfiguration() {
            #if DEBUG
            if supabaseURL.contains("YOUR_PROJECT_REF") || supabaseAnonKey.contains("YOUR_ANON_KEY") {
                print("⚠️ WARNING: Supabase credentials not configured. Update Configuration.swift with your project credentials.")
            }
            #endif
        }
    }
    ```
  - [x] 7.2 Replace placeholder values with actual Supabase project URL and Publishable key
  - [x] 7.3 Ensure AppEnvironment.swift uses Configuration values (already done in Story 1.1)
  - **Note:** Updated to use new `supabasePublishableKey` (replaces deprecated anon key)

- [x] Task 8: Verify iOS Connection (AC: #4)
  - [x] 8.1 Add a simple connection test in `AppEnvironment.swift`:
    ```swift
    /// Test Supabase connection (DEBUG only)
    func testConnection() async {
        #if DEBUG
        do {
            // Simple health check - fetch auth settings
            let _ = try await supabase.auth.session
            print("✅ Supabase connection successful")
        } catch {
            print("❌ Supabase connection failed: \(error.localizedDescription)")
        }
        #endif
    }
    ```
  - [x] 8.2 Build and run app on iOS simulator
  - [x] 8.3 Check Xcode console for connection status message
  - [x] 8.4 Verify no compile errors with Supabase SDK
  - **Note:** Build succeeded on both iOS 18.5 and iOS 26.2 simulators

- [x] Task 9: Create Database Documentation (AC: #2, #3)
  - [x] 9.1 Create `CoachMe/Supabase/README.md`:
    ```markdown
    # Supabase Backend

    ## Database Schema

    ### Tables

    | Table | Purpose | RLS |
    |-------|---------|-----|
    | users | App-specific user data (extends auth.users) | Yes |
    | conversations | Chat conversation threads | Yes |
    | messages | Individual messages in conversations | Yes |

    ### Key Relationships

    - `auth.users` → `public.users` (1:1, synced via trigger)
    - `users` → `conversations` (1:N)
    - `conversations` → `messages` (1:N)
    - `users` → `messages` (1:N, denormalized for RLS)

    ### Running Migrations

    1. Open Supabase Dashboard → SQL Editor
    2. Run migrations in order:
       - `20260205000001_initial_schema.sql`
       - `20260205000002_rls_policies.sql`
       - `20260205000003_user_sync_trigger.sql`

    ### Apple OAuth Setup

    See Apple Developer Portal for:
    - Services ID configuration
    - Sign in with Apple key (.p8)
    - Redirect URL: `https://<project-ref>.supabase.co/auth/v1/callback`
    ```

## Dev Notes

### Architecture Compliance

**CRITICAL REQUIREMENTS:**
- **ARCH-4:** Backend: Supabase (PostgreSQL, Auth, Edge Functions)
- **ARCH-8:** Auth: Sign in with Apple + Supabase Auth sync
- **ARCH-10:** Data model uses JSONB columns for flexible fields

**Database Naming Conventions (per architecture.md):**
- Tables: `snake_case`, plural — `users`, `conversations`, `messages`
- Columns: `snake_case` — `user_id`, `created_at`, `token_count`
- Foreign keys: `{referenced_table_singular}_id` — `user_id`, `conversation_id`
- Indexes: `idx_{table}_{column}` — `idx_messages_conversation_id`

**Migration File Naming:**
- Format: `YYYYMMDDHHMMSS_short_description.sql`
- Example: `20260205000001_initial_schema.sql`

### Row Level Security (RLS) Rules

**CRITICAL:** RLS must be enabled on ALL tables. Per Supabase documentation:
- Once RLS is enabled, no data is accessible via API until policies are created
- Each operation (SELECT, INSERT, UPDATE, DELETE) requires a separate policy
- Use `auth.uid()` to get the authenticated user's ID
- USING clause filters existing rows; WITH CHECK clause validates new/updated rows

### Supabase Auth Integration

The `auth.users` table is managed by Supabase Auth. Our `public.users` table:
- References `auth.users(id)` with ON DELETE CASCADE
- Is auto-populated via trigger when new auth user is created
- Stores app-specific fields (subscription_status, trial_ends_at)

### Security Considerations

- **Never expose** the service_role key in iOS app — only use anon key
- **RLS policies** enforce data isolation at database level
- **Cascade deletes** ensure data consistency when users are deleted
- **SECURITY DEFINER** on trigger function runs with elevated privileges (necessary for auth.users access)

### Future Tables (Not in This Story)

Per architecture.md, these tables will be added in future stories:
- `context_profiles` — Story 2.1 (Epic 2)
- `coaching_personas` — Story 5.1 (Epic 5)
- `usage_logs` — Story 9.2 (Epic 9)
- `push_tokens` — Story 8.1 (Epic 8)

### Critical Anti-Patterns to Avoid

- **DO NOT** use service_role key in iOS app
- **DO NOT** disable RLS on any table
- **DO NOT** store sensitive data without encryption
- **DO NOT** expose raw auth.users table via API
- **DO NOT** create tables without enabling RLS
- **DO NOT** hardcode production credentials in source code

### Testing Checklist

- [x] Tables created in Supabase Dashboard
- [x] RLS enabled on all tables
- [x] RLS policies show in Authentication → Policies
- [ ] New auth user triggers public.users insert (will test in Story 1.4)
- [x] iOS app connects without errors
- [x] iOS app shows connection success message in console

### References

- [Source: architecture.md#Data-Architecture] — Data model and table structure
- [Source: architecture.md#Authentication-Security] — Auth flow and RLS requirements
- [Source: architecture.md#Naming-Patterns] — Database naming conventions
- [Source: epics.md#Story-1.3] — Acceptance criteria and requirements

### External References

- [Supabase Documentation](https://supabase.com/docs) — Official docs
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) — RLS guide
- [Supabase iOS Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui) — Swift integration
- [Supabase Database Migrations](https://supabase.com/docs/guides/deployment/database-migrations) — Migration guide
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift) — GitHub repository

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Researched Supabase API key changes (2026): `anon` key deprecated, replaced with `sb_publishable_` format
- Build succeeded on iOS 18.5 (iPhone 16 Pro simulator) and iOS 26.2 (iPhone 17 Pro simulator)
- Fixed warning about non-optional Session comparison in AppEnvironment.swift

### Completion Notes List

- ✅ Created 3 SQL migration files for initial schema, RLS policies, and user sync trigger
- ✅ Updated Configuration.swift with new `supabasePublishableKey` property (replaces deprecated `supabaseAnonKey`)
- ✅ Added legacy alias for backward compatibility
- ✅ Updated AppEnvironment.swift with connection test method and new key usage
- ✅ Created comprehensive Supabase README.md documentation
- ✅ Build verified on both iOS 18.5 and iOS 26.2 simulators
- ✅ All three SQL migrations executed successfully in Supabase Dashboard (Task 5)
- ✅ Apple OAuth configured in Supabase with JWT client secret (Task 2)
- ✅ All acceptance criteria met - Story complete!

### File List

**New Files:**
- `CoachMe/Supabase/migrations/20260205000001_initial_schema.sql`
- `CoachMe/Supabase/migrations/20260205000002_rls_policies.sql`
- `CoachMe/Supabase/migrations/20260205000003_user_sync_trigger.sql`
- `CoachMe/Supabase/README.md`
- `.gitignore` (project root - protects sensitive files from git)
- `generate_apple_secret.js` (project root - JWT generator for Apple OAuth renewal)

**Modified Files:**
- `CoachMe/CoachMe/App/Environment/Configuration.swift` (added real Supabase credentials, renamed to supabasePublishableKey)
- `CoachMe/CoachMe/App/Environment/AppEnvironment.swift` (added testConnection() method, uses supabasePublishableKey)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-05 | Story created with comprehensive implementation tasks | Claude Opus 4.5 |
| 2026-02-05 | Implemented Tasks 1, 3, 4, 6, 7, 8, 9 - created migration files, updated iOS config with Publishable API key, added connection test, created documentation | Claude Opus 4.5 |
| 2026-02-06 | Code Review: Fixed Task 6.3 status, added missing files to File List (.gitignore, generate_apple_secret.js), updated Testing Checklist, fixed README Apple Secret Key documentation | Claude Opus 4.5 |
