# Supabase Backend

Coach App backend infrastructure powered by Supabase.

## Database Schema

### Tables

| Table | Purpose | RLS |
|-------|---------|-----|
| `users` | App-specific user data (extends auth.users) | Yes |
| `conversations` | Chat conversation threads | Yes |
| `messages` | Individual messages in conversations | Yes |

### Key Relationships

```
auth.users (Supabase managed)
    │
    ▼ (1:1 via trigger)
public.users
    │
    ▼ (1:N)
public.conversations
    │
    ▼ (1:N)
public.messages
```

- `auth.users` → `public.users` (1:1, synced via trigger on signup)
- `users` → `conversations` (1:N, user owns many conversations)
- `conversations` → `messages` (1:N, conversation contains many messages)
- `users` → `messages` (1:N, denormalized for RLS efficiency)

### Column Reference

#### users
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key (references auth.users) |
| email | TEXT | User's email address |
| display_name | TEXT | Display name for UI |
| avatar_url | TEXT | Profile picture URL |
| subscription_status | TEXT | trial, active, expired, cancelled |
| trial_ends_at | TIMESTAMPTZ | When trial period ends |
| created_at | TIMESTAMPTZ | Account creation time |
| updated_at | TIMESTAMPTZ | Last update time |

#### conversations
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key to users |
| title | TEXT | Conversation title |
| domain | TEXT | Coaching domain (life, career, etc.) |
| last_message_at | TIMESTAMPTZ | Time of last message |
| message_count | INTEGER | Number of messages |
| created_at | TIMESTAMPTZ | Conversation start time |
| updated_at | TIMESTAMPTZ | Last update time |

#### messages
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| conversation_id | UUID | Foreign key to conversations |
| user_id | UUID | Foreign key to users |
| role | TEXT | user, assistant, or system |
| content | TEXT | Message content |
| token_count | INTEGER | Token count for cost tracking |
| metadata | JSONB | Flexible field for extras |
| created_at | TIMESTAMPTZ | Message timestamp |

## Running Migrations

### Via Supabase Dashboard

1. Open your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run migrations in order:

```
1. 20260205000001_initial_schema.sql
2. 20260205000002_rls_policies.sql
3. 20260205000003_user_sync_trigger.sql
```

### Via Supabase CLI (Alternative)

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Link to your project
supabase link --project-ref xzsvzbjxlsnhxyrglvjp

# Push migrations
supabase db push
```

## Row Level Security (RLS)

All tables have RLS enabled. Policies ensure users can only access their own data:

- **SELECT**: `auth.uid() = id` (users) or `auth.uid() = user_id` (others)
- **INSERT**: `auth.uid() = id/user_id`
- **UPDATE**: `auth.uid() = id/user_id`
- **DELETE**: `auth.uid() = id/user_id`

## API Keys (2026 Format)

Supabase now uses new API key format:

| Key Type | Format | Usage |
|----------|--------|-------|
| Publishable | `sb_publishable_...` | iOS app, client-side |
| Secret | `sb_secret_...` | Edge Functions, server-side only |

The iOS app uses the **Publishable Key** configured in `Configuration.swift`.

## Apple OAuth Setup

### Prerequisites
- Apple Developer Program membership
- Services ID configured for Sign in with Apple

### Configuration Steps

1. **Apple Developer Portal**
   - Create a Services ID (e.g., `com.yourcompany.coachapp.auth`)
   - Enable "Sign in with Apple"
   - Add redirect URL: `https://xzsvzbjxlsnhxyrglvjp.supabase.co/auth/v1/callback`
   - Create a Sign in with Apple Key (.p8 file)

2. **Supabase Dashboard**
   - Go to Authentication → Providers → Apple
   - Enable the provider
   - Enter:
     - Client ID (Services ID identifier)
     - Secret Key (JWT generated from .p8 file - run `node generate_apple_secret.js`)
     - Key ID
     - Team ID

   **Note:** The Secret Key is NOT the raw .p8 file contents. It must be a JWT signed with the .p8 key. Use `generate_apple_secret.js` in the project root to generate it. The JWT expires every 180 days and must be regenerated.

## Future Tables

These tables will be added in later stories:

| Table | Story | Purpose |
|-------|-------|---------|
| `context_profiles` | 2.1 | User values, goals, situation |
| `coaching_personas` | 5.1 | Custom coach personas |
| `usage_logs` | 9.2 | API cost tracking |
| `push_tokens` | 8.1 | Push notification tokens |

## Troubleshooting

### Connection Issues
```swift
// In your app, call:
await AppEnvironment.shared.testConnection()
// Check Xcode console for result
```

### RLS Blocking Queries
If queries return empty when data exists:
1. Verify user is authenticated
2. Check `auth.uid()` matches the data's `user_id`
3. Verify RLS policies are created correctly

### User Not Created After Signup
If `public.users` row missing after auth signup:
1. Verify trigger exists: Check `on_auth_user_created` in database triggers
2. Check function: Verify `handle_new_user()` function exists
3. Run migration 3 if needed

## Security Notes

- **Never** use the Secret Key in the iOS app
- **Never** disable RLS on any table
- **Never** expose `auth.users` directly via API
- The Publishable Key is safe for client-side use
