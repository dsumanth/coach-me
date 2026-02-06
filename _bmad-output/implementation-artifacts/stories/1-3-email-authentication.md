# Story 1.3: Email Authentication

Status: review

## Story

As a **user**,
I want **to sign up and log in with my email**,
so that **I have a secure personal account for my coaching sessions**.

## Acceptance Criteria

1. **AC1 — Signup with Valid Credentials**
   - Given I am on the signup screen
   - When I enter a valid email and password (min 8 characters)
   - Then my account is created and I am navigated to the chat screen

2. **AC2 — Invalid Email Validation**
   - Given I am on the signup screen
   - When I enter an invalid email format
   - Then I see an inline error "Please enter a valid email"

3. **AC3 — Weak Password Validation**
   - Given I am on the signup screen
   - When I enter a password less than 8 characters
   - Then I see an inline error "Password must be at least 8 characters"

4. **AC4 — Login with Correct Credentials**
   - Given I have an existing account
   - When I log in with correct credentials
   - Then I am authenticated and navigated to the chat screen

5. **AC5 — Login with Incorrect Credentials**
   - Given I have an existing account
   - When I log in with incorrect password
   - Then I see an error "Invalid email or password"

6. **AC6 — Session Persistence**
   - Given I am authenticated
   - When I close and reopen the app
   - Then my session is restored automatically (no re-login required)

7. **AC7 — Visual Design & Accessibility**
   - Given the auth screens
   - When I view them on iOS and web
   - Then they follow the warm visual design with proper accessibility labels

8. **AC8 — Loading States During Auth**
   - Given I tap "Create Account" or "Log In"
   - When the auth request is in progress
   - Then the button shows a loading spinner and is disabled

## Tasks / Subtasks

- [x] Task 1: Install dependencies and create Zod validation schemas (AC: #2, #3)
  - [x] 1.0 Install Zod: `npx expo install zod`
  - [x] 1.1 Create `lib/validation/auth.ts` with `emailSchema` and `passwordSchema`
  - [x] 1.2 Create `signupSchema` combining email + password with custom error messages
  - [x] 1.3 Create `loginSchema` for login form validation
  - [x] 1.4 Verify schemas match architecture patterns (camelCase, `Schema` suffix)

- [x] Task 2: Create auth feature hooks (AC: #1, #4, #5, #6, #8)
  - [x] 2.1 Create `features/auth/hooks/useAuth.ts` with auth state and methods:
    - `user` - current authenticated user (null when signed out)
    - `isLoading` - auth state loading indicator
    - `isAuthenticating` - true during signUp/signIn API calls (for button loading)
    - `signUp(email, password)` - create account via Supabase Auth
    - `signIn(email, password)` - login via Supabase Auth
    - `signOut()` - logout and clear session
  - [x] 2.2 Hook uses `useSupabase()` from `hooks/useSupabase.ts` (already exists from Story 1.2)
  - [x] 2.3 Handle Supabase Auth errors and map to user-friendly messages
  - [x] 2.4 Verify session persists across app restarts (AsyncStorage adapter configured in Story 1.2)

- [x] Task 3: Create AuthProvider context (AC: #6)
  - [x] 3.1 Create `features/auth/AuthProvider.tsx` wrapping `useAuth` for global access
  - [x] 3.2 Add `onAuthStateChange` listener to sync auth state with Supabase
  - [x] 3.3 Export `useAuthContext()` hook for child components
  - [x] 3.4 Integrate AuthProvider in `app/_layout.tsx`:
    - Import AuthProvider from `features/auth/AuthProvider`
    - Wrap INSIDE QueryClientProvider (auth hooks may use queries)
    - Wrap OUTSIDE Stack (screens need auth context)
    - **Final provider order:** SafeAreaProvider > QueryClientProvider > AuthProvider > Stack

- [x] Task 4: Create shared UI atoms (AC: #7, #8)
  - [x] 4.1 Create `components/ui/Input.tsx` with NativeWind styling:
    - Props: `label`, `placeholder`, `value`, `onChangeText`, `error`, `secureTextEntry`, `testID`
    - Include `accessibilityLabel`, `accessibilityRole="none"` (TextInput has implicit role)
    - Error state shows red border and error message
    - **Required TextInput props for auth:**
      - `keyboardType="email-address"` for email fields
      - `autoCapitalize="none"` for email and password
      - `autoCorrect={false}` for email and password
      - `textContentType="emailAddress"` / `"password"` for iOS autofill
      - `returnKeyType="next"` / `"done"` for keyboard flow
      - `onSubmitEditing` for form field navigation
    - **NativeWind classes:**
      ```
      Container: className="mb-4"
      Label: className="text-warmGray-600 text-sm font-medium mb-1"
      Input (default): className="bg-white border border-warmGray-300 rounded-xl px-4 py-3 text-warmGray-800 text-base"
      Input (focused): className="border-terracotta"
      Input (error): className="border-red-500"
      Error text: className="text-red-600 text-sm mt-1"
      ```
  - [x] 4.2 Create `components/ui/Button.tsx` with variants:
    - Props: `variant` (primary, secondary, outline), `disabled`, `loading`, `onPress`, `testID`
    - Primary uses terracotta (#C2410C), disabled state grayed
    - Include loading spinner (ActivityIndicator) when `loading={true}`
    - **NativeWind classes:**
      ```
      Primary: className="bg-terracotta py-4 px-6 rounded-xl items-center justify-center"
      Primary text: className="text-white font-semibold text-base"
      Disabled: className="bg-warmGray-300"
      Loading container: className="flex-row items-center justify-center gap-2"
      ```
  - [x] 4.3 Create `components/ui/Text.tsx` with typography variants:
    - Props: `variant` (heading, body, label, error, link)
    - Warm color palette (warmGray-600 for body, terracotta for links/accents)
  - [x] 4.4 Verify all atoms have proper accessibility props and testID

- [x] Task 5: Create Signup screen (AC: #1, #2, #3, #7, #8)
  - [x] 5.1 Create `app/(auth)/signup.tsx` with:
    - `KeyboardAvoidingView` wrapper (behavior="padding" for iOS)
    - `ScrollView` for form content (handles small screens)
    - Email input field with validation (testID="signup-email-input")
    - Password input field with secure entry (testID="signup-password-input")
    - "Create Account" button (testID="signup-button", disabled until form valid OR during loading)
    - Link to login screen ("Already have an account?")
  - [x] 5.2 Use Zod validation on form submission (see Form State Management pattern)
  - [x] 5.3 Show inline errors below each field when validation fails
  - [x] 5.4 Call `signUp()` from `useAuthContext()` on submit
  - [x] 5.5 Handle email confirmation if enabled (see Email Confirmation section)
  - [x] 5.6 Navigate to `(tabs)` on successful signup with session
  - [x] 5.7 Apply warm visual design (cream background, terracotta accent)

- [x] Task 6: Create Login screen (AC: #4, #5, #7, #8)
  - [x] 6.1 Create `app/(auth)/login.tsx` with:
    - `KeyboardAvoidingView` wrapper (behavior="padding" for iOS)
    - `ScrollView` for form content
    - Email input field (testID="login-email-input")
    - Password input field with secure entry (testID="login-password-input")
    - "Log In" button (testID="login-button")
    - Link to signup screen ("Don't have an account?")
    - Link to forgot-password screen ("Forgot password?")
  - [x] 6.2 Use Zod validation on form submission
  - [x] 6.3 Call `signIn()` from `useAuthContext()` on submit
  - [x] 6.4 Show error message when login fails (testID="login-error")
  - [x] 6.5 Navigate to `(tabs)` on successful login
  - [x] 6.6 Apply warm visual design matching signup screen

- [x] Task 7: Create (auth) and (tabs) layouts (AC: #6, #7)
  - [x] 7.1 Create `app/(auth)/_layout.tsx` as Stack navigator
  - [x] 7.2 Configure header with app title and warm styling (or headerShown: false for custom)
  - [x] 7.3 Ensure screens are accessible via Expo Router navigation
  - [x] 7.4 Create `app/(tabs)/_layout.tsx` with basic Tab navigator (placeholder for Story 1.6):
    ```typescript
    import { Tabs } from 'expo-router';
    export default function TabsLayout() {
      return <Tabs screenOptions={{ headerShown: false }}><Tabs.Screen name="index" options={{ title: 'Chat' }} /></Tabs>;
    }
    ```
  - [x] 7.5 Create `app/(tabs)/index.tsx` as placeholder chat screen:
    ```typescript
    import { View, Text } from 'react-native';
    export default function ChatScreen() {
      return <View className="flex-1 bg-cream items-center justify-center"><Text className="text-warmGray-600">Chat coming in Story 1.6</Text></View>;
    }
    ```

- [x] Task 8: Implement auth-gated routing (AC: #6)
  - [x] 8.1 Update `app/_layout.tsx` to check auth state on mount
  - [x] 8.2 Redirect to `(auth)/login` when no session
  - [x] 8.3 Redirect to `(tabs)` when session exists
  - [x] 8.4 Show loading screen while checking auth state:
    ```typescript
    if (isLoading) {
      return (
        <View className="flex-1 bg-cream items-center justify-center">
          <ActivityIndicator size="large" color="#C2410C" />
        </View>
      );
    }
    ```

- [x] Task 9: Create forgot-password screen (Optional Enhancement)
  - [x] 9.1 Create `app/(auth)/forgot-password.tsx` with email input
  - [x] 9.2 Call Supabase `resetPasswordForEmail()` on submit
  - [x] 9.3 Show success message "Check your email for reset link"
  - [x] 9.4 Add link from login screen to forgot-password

- [ ] Task 10: Manual testing verification (AC: #1-#8)
  - [ ] 10.1 Test signup flow on iOS Simulator
  - [ ] 10.2 Test login flow on iOS Simulator
  - [ ] 10.3 Test session persistence (close and reopen app)
  - [ ] 10.4 Test validation errors for invalid email/password
  - [ ] 10.5 Test loading states on buttons during auth
  - [ ] 10.6 Test on web browser (Expo Web)
  - [ ] 10.7 Verify accessibility labels with VoiceOver/screen reader

## Dev Notes

### Architecture Compliance

**File Structure (MANDATORY):**
```
app/
  (auth)/
    _layout.tsx           # Auth stack layout
    login.tsx             # Email login screen
    signup.tsx            # Email signup screen
    forgot-password.tsx   # Password reset screen (optional)
  (tabs)/
    _layout.tsx           # Tab navigator (placeholder for Story 1.6)
    index.tsx             # Chat screen placeholder
  _layout.tsx             # Root layout with auth check + AuthProvider

components/
  ui/
    Input.tsx             # Form input component
    Button.tsx            # Action button component
    Text.tsx              # Typography component

features/
  auth/
    hooks/
      useAuth.ts          # Auth state and methods
    AuthProvider.tsx      # Global auth context provider

lib/
  validation/
    auth.ts               # Zod schemas for auth forms
```

**Naming Conventions:**
- Components: `PascalCase` files and exports (Input.tsx, Button.tsx)
- Hooks: `camelCase` with `use` prefix (useAuth.ts)
- Zod schemas: `camelCase` with `Schema` suffix (signupSchema, loginSchema)
- Variables: `camelCase` (isLoading, signInError)

**State Management:**
- Use React Context for auth state (client-only state per architecture)
- TanStack Query NOT used for auth (auth is client state, not server state)
- Supabase session managed via `onAuthStateChange` listener

### Email Confirmation Configuration

Supabase Auth requires email confirmation by default. Choose ONE approach:

**Option A — Disable for MVP (Recommended):**
1. Supabase Dashboard → Authentication → Email Templates
2. Toggle OFF "Enable email confirmations"
3. Users get immediate access after signup

**Option B — Handle Confirmation Flow:**
```typescript
const { data, error } = await supabase.auth.signUp({ email, password });

if (!error && !data.session) {
  // Email confirmation required - session is null until confirmed
  // Navigate to "Check your email" screen instead of tabs
  router.replace('/(auth)/check-email');
}
```

### Form State Management Pattern

Use controlled components with useState for auth forms:

```typescript
const [email, setEmail] = useState('');
const [password, setPassword] = useState('');
const [errors, setErrors] = useState<{ email?: string; password?: string }>({});

const handleSubmit = async () => {
  // Validate with Zod
  const result = signupSchema.safeParse({ email, password });
  if (!result.success) {
    const fieldErrors = result.error.flatten().fieldErrors;
    setErrors({
      email: fieldErrors.email?.[0],
      password: fieldErrors.password?.[0],
    });
    return;
  }

  // Clear errors and proceed
  setErrors({});
  try {
    await signUp(email, password);
    router.replace('/(tabs)');
  } catch (err) {
    // Handle auth error
  }
};
```

### Error State Behavior

- Clear field-specific error when user starts typing in that field
- Clear global auth error when user modifies any field
- Don't clear errors on blur (wait for user to fix the issue)

```typescript
<Input
  value={email}
  onChangeText={(text) => {
    setEmail(text);
    setErrors(prev => ({ ...prev, email: undefined }));
    setAuthError(null); // Clear global auth error too
  }}
  error={errors.email}
/>
```

### Keyboard Handling Pattern

Wrap auth forms with KeyboardAvoidingView for iOS keyboard:

```typescript
import { KeyboardAvoidingView, Platform, ScrollView } from 'react-native';

<KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  className="flex-1"
>
  <ScrollView
    contentContainerStyle={{ flexGrow: 1 }}
    keyboardShouldPersistTaps="handled"
  >
    {/* Form content */}
  </ScrollView>
</KeyboardAvoidingView>
```

### Critical Anti-Patterns

- **NEVER** store passwords in state after form submission
- **NEVER** log email or password values (PII protection)
- **NEVER** use `any` type — use proper TypeScript types
- **NEVER** import `lib/supabase` directly in components — use `useSupabase()` hook
- **NEVER** skip accessibility props on form inputs
- **NEVER** forget to disable button during loading (prevents double-submit)

### Zod Validation Schema Reference

```typescript
// lib/validation/auth.ts
import { z } from 'zod';

export const emailSchema = z
  .string()
  .min(1, 'Email is required')
  .email('Please enter a valid email');

export const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters');

export const signupSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
});

export const loginSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
});

export type SignupFormData = z.infer<typeof signupSchema>;
export type LoginFormData = z.infer<typeof loginSchema>;
```

### useAuth Hook Reference

```typescript
// features/auth/hooks/useAuth.ts
import { useState, useEffect, useCallback } from 'react';
import { useSupabase } from '../../../hooks/useSupabase';
import type { User } from '@supabase/supabase-js';

export function useAuth() {
  const supabase = useSupabase();
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticating, setIsAuthenticating] = useState(false);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      setIsLoading(false);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setUser(session?.user ?? null);
      }
    );

    return () => subscription.unsubscribe();
  }, [supabase]);

  const signUp = useCallback(async (email: string, password: string) => {
    setIsAuthenticating(true);
    try {
      const { data, error } = await supabase.auth.signUp({ email, password });
      if (error) throw error;
      return data;
    } finally {
      setIsAuthenticating(false);
    }
  }, [supabase]);

  const signIn = useCallback(async (email: string, password: string) => {
    setIsAuthenticating(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      return data;
    } finally {
      setIsAuthenticating(false);
    }
  }, [supabase]);

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }, [supabase]);

  return { user, isLoading, isAuthenticating, signUp, signIn, signOut };
}
```

### NativeWind Styling Reference

Colors are pre-configured in `tailwind.config.js` (Story 1.1). Use these classes:

**Backgrounds:** `bg-cream`, `bg-white`, `bg-terracotta`, `bg-warmGray-300`
**Text:** `text-warmGray-600`, `text-warmGray-400`, `text-terracotta`, `text-white`
**Borders:** `border-warmGray-300`, `border-terracotta`, `border-red-500`
**Error:** `text-red-600`, `border-red-500`

### Supabase Auth Error Handling

Map Supabase error codes to user-friendly messages:

| Supabase Error | User Message |
|----------------|--------------|
| `invalid_credentials` | "Invalid email or password" |
| `user_already_exists` | "An account with this email already exists" |
| `weak_password` | "Password must be at least 8 characters" |
| `email_not_confirmed` | "Please check your email to confirm your account" |
| `over_request_rate_limit` | "Too many attempts. Please wait a moment." |
| Default | "Something went wrong. Please try again." |

### Expo Router Navigation

**Auth Flow:**
1. App opens → `app/_layout.tsx` checks session via `useAuthContext()`
2. `isLoading=true` → Show loading screen with ActivityIndicator
3. `isLoading=false` + no user → Redirect to `/(auth)/login`
4. `isLoading=false` + user exists → Redirect to `/(tabs)`
5. After signup/login success → `router.replace('/(tabs)')`
6. After signout → `router.replace('/(auth)/login')`

**Navigation Example:**
```typescript
import { useRouter } from 'expo-router';

const router = useRouter();

// After successful login
router.replace('/(tabs)');

// After signout
router.replace('/(auth)/login');
```

### Test IDs for E2E Testing

Include testID props on all interactive elements:

| Element | testID |
|---------|--------|
| Signup email input | `signup-email-input` |
| Signup password input | `signup-password-input` |
| Signup button | `signup-button` |
| Login email input | `login-email-input` |
| Login password input | `login-password-input` |
| Login button | `login-button` |
| Login error message | `login-error` |
| Signup error message | `signup-error` |

### Previous Story Context

**Story 1.1 Created:**
- Expo project with dependencies (NOT including Zod — install in this story)
- `app/_layout.tsx` with URL polyfill import and provider structure
- `lib/queryClient.ts` — TanStack Query client
- NativeWind configured with warm color palette in `tailwind.config.js`

**Story 1.2 Created:**
- `lib/supabase.ts` — Supabase client with AsyncStorage adapter
- `hooks/useSupabase.ts` — React hook wrapper (use this, not lib/supabase directly)
- `types/database.ts` — Auto-generated TypeScript types
- Database tables: profiles, conversations, messages (with RLS)
- Session persistence already configured via AsyncStorage

### Testing Notes

**Manual Test Checklist:**
1. Signup with new email → should create account, redirect to tabs
2. Signup with existing email → should show "account already exists" error
3. Signup with invalid email → should show inline validation error
4. Signup with short password → should show inline validation error
5. Login with valid credentials → should authenticate, redirect to tabs
6. Login with wrong password → should show "Invalid email or password"
7. Close app while logged in → reopen → should auto-restore session
8. Button loading state → should show spinner during auth request
9. Button disabled state → should not allow double-tap during loading
10. VoiceOver: all inputs should announce labels correctly

### References

- [architecture.md#Authentication-Security] — Auth methods, Supabase Auth configuration
- [architecture.md#Auth-Flow-Pattern] — 6-step auth flow pattern (lines 475-478)
- [architecture.md#Frontend-Architecture] — State management (React Context for auth)
- [architecture.md#Process-Patterns] — Error handling, loading states
- [architecture.md#Naming-Patterns] — Code naming conventions (lines 326-333)
- [architecture.md#Structure-Patterns] — File organization (app/(auth)/, features/auth/)
- [epics.md#Story-1.3] — Original acceptance criteria (lines 484-519)
- [Story 1.2] — Supabase client and session persistence setup

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Zod installed via `npx expo install zod`
- TypeScript check passed: `npx tsc --noEmit` returned no errors
- Web export verified: `npx expo export --platform web` completed successfully

### Completion Notes List

1. **Task 1**: Installed Zod and created validation schemas in `lib/validation/auth.ts` with emailSchema, passwordSchema, signupSchema, loginSchema, and exported types
2. **Task 2**: Created `features/auth/hooks/useAuth.ts` with full auth state management (user, isLoading, isAuthenticating) and methods (signUp, signIn, signOut) with user-friendly error mapping
3. **Task 3**: Created `features/auth/AuthProvider.tsx` with React Context and `useAuthContext()` hook; integrated into `app/_layout.tsx` with correct provider order
4. **Task 4**: Created UI atoms - Input.tsx (with forwardRef), Button.tsx (with loading states), Text.tsx (with variant support and className prop)
5. **Task 5**: Created `app/(auth)/signup.tsx` with full form validation, error handling, keyboard handling, and warm visual design
6. **Task 6**: Created `app/(auth)/login.tsx` with matching design and forgot-password link
7. **Task 7**: Created `app/(auth)/_layout.tsx` (Stack) and `app/(tabs)/_layout.tsx` (Tabs) with `app/(tabs)/index.tsx` placeholder
8. **Task 8**: Updated `app/_layout.tsx` with AuthGate component for auth-gated routing (redirects based on session state)
9. **Task 9**: Created `app/(auth)/forgot-password.tsx` with email validation and success state
10. **TypeScript fix**: Added className prop to Text component and fixed Zod error access (issues → errors)

### File List

**Created:**
- `lib/validation/auth.ts` — Zod schemas for auth forms
- `lib/validation/auth.test.ts` — Unit tests for Zod validation schemas
- `features/auth/hooks/useAuth.ts` — Auth state and methods with error mapping
- `features/auth/AuthProvider.tsx` — Global auth context provider
- `components/ui/Input.tsx` — Form input component with NativeWind
- `components/ui/Input.test.tsx` — Unit tests for Input component
- `components/ui/Button.tsx` — Action button with loading state
- `components/ui/Button.test.tsx` — Unit tests for Button component
- `components/ui/Text.tsx` — Typography component with variants
- `components/ui/Text.test.tsx` — Unit tests for Text component
- `app/(auth)/_layout.tsx` — Auth stack layout
- `app/(auth)/login.tsx` — Email login screen
- `app/(auth)/signup.tsx` — Email signup screen
- `app/(auth)/forgot-password.tsx` — Password reset screen
- `app/(tabs)/_layout.tsx` — Tab navigator placeholder
- `app/(tabs)/index.tsx` — Chat screen placeholder with sign out
- `jest.config.js` — Jest configuration for Expo
- `__tests__/setup.ts` — Test environment setup and mocks

**Modified:**
- `app/_layout.tsx` — Added AuthProvider wrapper and AuthGate for auth-gated routing
- `package.json` — Zod dependency, jest-expo, @testing-library/react-native, test scripts added
- `app.json` — Updated for Expo Router entry point

**Deleted:**
- `App.tsx` — Replaced by Expo Router file-based routing in `app/`
- `index.ts` — Replaced by `expo-router/entry` in package.json main field

## Change Log

- 2026-01-28: Initial implementation of email authentication (Tasks 1-9 complete)
- 2026-01-28: Code review fixes — Added unit tests (H1), fixed signup email confirmation flow (H2), fixed textContentType for signup password to "newPassword" (H3), synced sprint-status.yaml (M2), added accessibilityHint to Input (M3), added accessibilityLabel to Button (M4), documented deleted/modified files in File List (M1)
