# Story 1.1: Initialize Expo Project with Core Dependencies

Status: done

## Story

As a **developer**,
I want **the project scaffolded with Expo and all core dependencies installed**,
So that **I have a working foundation to build Coach App features**.

## Acceptance Criteria

1. **AC1 — Expo Project Created**
   - Given no existing project
   - When I run `npx create-expo-app@latest coach-app`
   - Then the project is created with Expo SDK 54

2. **AC2 — Core Dependencies Installed**
   - Given the Expo project exists
   - When I install dependencies (NativeWind v4.2.1, Tailwind CSS v3.3.2, Supabase SDK, TanStack Query, React Native Reanimated, expo-secure-store)
   - Then all dependencies are installed without version conflicts

3. **AC3 — NativeWind Configured**
   - Given dependencies are installed
   - When I configure NativeWind with `tailwind.config.js`, `metro.config.js`, and `babel.config.js`
   - Then Tailwind classes work in React Native components

4. **AC4 — App Launches Successfully**
   - Given the project is configured
   - When I run `npx expo start`
   - Then the app launches on iOS simulator and web browser

5. **AC5 — Directory Structure Created**
   - Given the project structure
   - When I create the directory structure per architecture spec
   - Then all folders are in place following the architecture spec

## Tasks / Subtasks

- [x] Task 1: Scaffold Expo project (AC: #1)
  - [x] 1.1 Run `npx create-expo-app@latest coach-app`
  - [x] 1.2 Verify Expo SDK 54 in `package.json` (`expo: ~54.0.31`)
  - [x] 1.3 Verify `npx expo start` launches the default template screen

- [x] Task 2: Install core dependencies (AC: #2)
  - [x] 2.1 Install NativeWind and Tailwind:
    ```bash
    npx expo install nativewind tailwindcss@3.3.2
    ```
  - [x] 2.2 Install Supabase SDK:
    ```bash
    npx expo install @supabase/supabase-js react-native-url-polyfill @react-native-async-storage/async-storage
    ```
  - [x] 2.3 Install TanStack Query:
    ```bash
    npx expo install @tanstack/react-query
    ```
  - [x] 2.4 Install React Native Reanimated and SafeAreaContext:
    ```bash
    npx expo install react-native-reanimated react-native-safe-area-context
    ```
  - [x] 2.5 Install expo-secure-store:
    ```bash
    npx expo install expo-secure-store
    ```
  - [x] 2.6 Verify no version conflicts in `package.json` — all peer dependencies satisfied

- [x] Task 3: Configure NativeWind + Tailwind CSS (AC: #3)
  - [x] 3.1 Create `tailwind.config.js` with content paths and warm design tokens:
    ```js
    // tailwind.config.js
    module.exports = {
      content: ["./app/**/*.{js,jsx,ts,tsx}", "./components/**/*.{js,jsx,ts,tsx}", "./features/**/*.{js,jsx,ts,tsx}"],
      presets: [require("nativewind/preset")],
      theme: {
        extend: {
          colors: {
            cream: { DEFAULT: '#FEF7ED', 50: '#FFFDF8', 100: '#FEF7ED' },
            terracotta: { DEFAULT: '#C2410C', 500: '#C2410C', 600: '#9A3412' },
            warmGray: { 50: '#FAF9F7', 100: '#F5F3F0', 200: '#E8E5E0', 300: '#D5D0C8', 400: '#B0A899', 500: '#8C8372', 600: '#6B6352', 700: '#4A4438', 800: '#2E2A22', 900: '#1A1814' },
          },
        },
      },
      plugins: [],
    };
    ```
  - [x] 3.2 Update `metro.config.js` for NativeWind CSS:
    ```js
    const { getDefaultConfig } = require("expo/metro-config");
    const { withNativeWind } = require("nativewind/metro");
    const config = getDefaultConfig(__dirname);
    module.exports = withNativeWind(config, { input: "./global.css" });
    ```
  - [x] 3.3 Update `babel.config.js` with NativeWind and Reanimated plugins:
    ```js
    module.exports = function (api) {
      api.cache(true);
      return {
        presets: [["babel-preset-expo", { jsxImportSource: "nativewind" }]],
        plugins: ["react-native-reanimated/plugin"],
      };
    };
    ```
  - [x] 3.4 Create `global.css` with Tailwind directives:
    ```css
    @tailwind base;
    @tailwind components;
    @tailwind utilities;
    ```
  - [x] 3.5 Create `nativewind-env.d.ts`:
    ```ts
    /// <reference types="nativewind/types" />
    ```
  - [x] 3.6 Import `global.css` in root `app/_layout.tsx`
  - [x] 3.7 Verify: Create a test `<Text className="text-terracotta">Hello</Text>` and confirm it renders with terracotta color

- [x] Task 4: Create project directory structure (AC: #5)
  - [x] 4.1 Create all directories per architecture spec:
    ```
    components/ui/
    components/chat/
    components/layout/
    components/context/
    components/creator/
    components/auth/
    components/subscription/
    features/coaching/hooks/
    features/coaching/services/
    features/coaching/utils/
    features/context/hooks/
    features/safety/hooks/
    features/safety/constants/
    features/creator/hooks/
    features/auth/hooks/
    features/auth/services/
    features/payments/hooks/
    features/payments/services/
    features/notifications/hooks/
    features/notifications/services/
    features/offline/hooks/
    features/offline/services/
    features/operator/hooks/
    hooks/
    lib/validation/
    types/
    supabase/functions/_shared/
    supabase/functions/chat-stream/
    supabase/functions/extract-context/
    supabase/functions/push-trigger/
    supabase/functions/webhook-revenuecat/
    supabase/functions/og-metadata/
    supabase/migrations/
    assets/images/
    assets/fonts/
    assets/domain-configs/
    landing/
    __tests__/helpers/
    __tests__/e2e/
    ```
  - [x] 4.2 Add `.gitkeep` files to empty directories so they are tracked by git

- [x] Task 5: Create environment configuration (AC: #4)
  - [x] 5.1 Create `.env.example` with placeholder values:
    ```
    EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
    EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
    LLM_API_KEY=your-llm-api-key
    SENTRY_DSN=your-sentry-dsn
    REVENUECAT_API_KEY=your-revenuecat-key
    ```
  - [x] 5.2 Create `.env.local` by copying `.env.example` (do NOT commit `.env.local`)
  - [x] 5.3 Ensure `.gitignore` includes `.env.local` and `node_modules/`

- [x] Task 6: Set up root layout with providers (AC: #4)
  - [x] 6.1 Create `lib/queryClient.ts` — TanStack Query client with sensible defaults:
    ```ts
    import { QueryClient } from '@tanstack/react-query';
    export const queryClient = new QueryClient({
      defaultOptions: {
        queries: { staleTime: 1000 * 60 * 5, retry: 2 },
      },
    });
    ```
  - [x] 6.2 Update `app/_layout.tsx` to wrap app in `QueryClientProvider` and import `global.css`
  - [x] 6.3 Verify the app still launches on iOS and web after provider setup

- [x] Task 7: Verify complete setup (AC: #4)
  - [x] 7.1 Run `npx expo start` and confirm iOS simulator launch
  - [x] 7.2 Run `npx expo start --web` and confirm web browser launch
  - [x] 7.3 Confirm NativeWind class renders correctly (terracotta text test from Task 3.7)
  - [x] 7.4 Confirm no TypeScript errors: `npx tsc --noEmit`

## Dev Notes

### Architecture Compliance

- **Expo SDK Version:** Must be 54.0.31 (`expo: ~54.0.31`). Do NOT upgrade to a newer SDK unless explicitly requested.
- **NativeWind Version:** Must be v4.2.1 with Tailwind CSS v3.3.2. NOT Tailwind v4 — NativeWind v4 is pinned to Tailwind v3.
- **React Native Version:** 0.81 (comes with Expo SDK 54). Do NOT upgrade independently.
- **React Version:** 19.1 (comes with Expo SDK 54).
- **Routing:** Expo Router (file-based routing) is built into the default Expo template. Do NOT install `react-navigation` separately.
- **State Management:** TanStack Query for server state. No Redux, Zustand, or other state libraries.

### Critical Anti-Patterns to Avoid

- Do NOT use `useState` + `useEffect` + `fetch` for server data — always use TanStack Query
- Do NOT create new top-level directories outside the defined architecture structure
- Do NOT use inline styles — use NativeWind/Tailwind classes (except for truly dynamic values)
- Do NOT use `any` type — use `unknown` and narrow, or define proper types
- Do NOT install additional routing libraries (react-navigation, etc.)

### Naming Conventions (enforce from day one)

- **Components:** PascalCase files and exports — `Button.tsx`, `ChatBubble.tsx`
- **Hooks:** camelCase with `use` prefix — `useAuth.ts`, `useConversation.ts`
- **Utilities:** camelCase files and exports — `formatDate.ts`, `buildPrompt.ts`
- **Constants:** UPPER_SNAKE_CASE values — `MAX_TOKENS`, `COACHING_DOMAINS`
- **Types:** PascalCase, no `I` prefix — `User`, `Conversation`, `Message`

### Warm Design Tokens (from UX Spec)

The Tailwind config must include the Coach App warm palette:
- **Cream base:** `#FEF7ED` — app background
- **Terracotta accent:** `#C2410C` — primary action color
- **Warm grays:** gradient from `#FAF9F7` to `#1A1814` — text and surfaces
- Light mode is the default. Dark mode is a user preference toggle (later story).

### Project Structure Notes

- The Expo default template creates `app/` with `_layout.tsx`, `index.tsx`, etc. — keep this structure.
- The `supabase/` directory will hold Edge Functions and migrations (created now, populated in Story 1.2).
- `landing/` is an independent static site for SEO — exists at root but is deployed separately via Vercel.
- Test files are co-located: `Button.test.tsx` next to `Button.tsx`.

### References

- [Source: architecture.md#Starter-Template-Evaluation] — Expo default template selected, initialization command
- [Source: architecture.md#Full-Technology-Stack-Summary] — Version pinning for all dependencies
- [Source: architecture.md#Implementation-Patterns-Consistency-Rules] — Naming patterns, structure patterns
- [Source: architecture.md#Complete-Project-Directory-Structure] — Authoritative directory tree (~160 files)
- [Source: architecture.md#Decision-Impact-Analysis] — Implementation sequence (this is step 1)
- [Source: epics.md#Story-1.1] — Acceptance criteria and BDD scenarios

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- TypeScript check passed: `npx tsc --noEmit` returned no errors
- Web export successful: Built to /tmp/coach-app-export with 745 modules bundled

### Completion Notes List

- Scaffolded Expo project with SDK 54.0.32, React 19.1, React Native 0.81.5
- Installed all core dependencies: NativeWind 4.2.1, Tailwind CSS 3.3.2, Supabase SDK, TanStack Query, Reanimated, expo-secure-store
- Converted from blank-typescript to Expo Router (file-based routing)
- Configured NativeWind with warm design tokens (cream, terracotta, warmGray)
- Created complete directory structure per architecture spec (39 directories with .gitkeep)
- Set up environment configuration (.env.example, .env.local)
- Created root layout with QueryClientProvider
- Added react-native-web and react-dom for web support
- Added babel-preset-expo as devDependency

### File List

**Created:**
- coach-app/app/_layout.tsx — Root layout with providers
- coach-app/app/index.tsx — Home screen with NativeWind test
- coach-app/babel.config.js — Babel config with NativeWind and Reanimated
- coach-app/global.css — Tailwind directives
- coach-app/lib/queryClient.ts — TanStack Query client
- coach-app/metro.config.js — Metro config with NativeWind
- coach-app/nativewind-env.d.ts — NativeWind TypeScript declarations
- coach-app/tailwind.config.js — Tailwind config with warm design tokens
- coach-app/.env.example — Environment template
- coach-app/.env.local — Local environment (gitignored)
- 39 directories with .gitkeep files per architecture spec

**Modified:**
- coach-app/package.json — Entry point changed to expo-router/entry, added dependencies
- coach-app/app.json — Added scheme, bundleIdentifier, package, splash background color

**Deleted:**
- coach-app/App.tsx — Old entry point (replaced by Expo Router)
- coach-app/index.ts — Old entry point (replaced by expo-router/entry)

## Code Review Record

### Review Date
2026-01-28

### Reviewer Model
Claude Opus 4.5 (claude-opus-4-5-20251101)

### Issues Found and Fixed

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 1 | MEDIUM | Missing `react-native-url-polyfill/auto` import | Added import to _layout.tsx |
| 2 | MEDIUM | Missing SafeAreaProvider wrapper | Added SafeAreaProvider to _layout.tsx |
| 3 | MEDIUM | Index screen using View instead of SafeAreaView | Changed to SafeAreaView in index.tsx |
| 4 | MEDIUM | expo-secure-store dev build requirement undocumented | Created README.md with documentation |

### Files Modified During Review

- `app/_layout.tsx` — Added URL polyfill import and SafeAreaProvider wrapper
- `app/index.tsx` — Changed View to SafeAreaView for safe area support
- `README.md` — Created with dev build requirements and project documentation

### Final Verdict
**PASS** — All issues resolved, TypeScript check passes
