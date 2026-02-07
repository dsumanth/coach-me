-- Migration: 20260205000002_rls_policies.sql
-- Description: Row Level Security policies for all tables
-- Author: Coach App Development Team
-- Date: 2026-02-05
--
-- CRITICAL: These policies ensure users can only access their own data.
-- RLS must be enabled on tables BEFORE these policies are created.

-- ============================================================================
-- USERS TABLE RLS POLICIES
-- Users can only access their own profile row
-- ============================================================================

-- SELECT: Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

-- INSERT: Users can create their own profile (typically done via trigger)
CREATE POLICY "Users can insert own profile"
    ON public.users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- DELETE: Users can delete their own profile
CREATE POLICY "Users can delete own profile"
    ON public.users FOR DELETE
    USING (auth.uid() = id);

-- ============================================================================
-- CONVERSATIONS TABLE RLS POLICIES
-- Users can only access their own conversations
-- ============================================================================

-- SELECT: Users can view their own conversations
CREATE POLICY "Users can view own conversations"
    ON public.conversations FOR SELECT
    USING (auth.uid() = user_id);

-- INSERT: Users can create conversations for themselves
CREATE POLICY "Users can create own conversations"
    ON public.conversations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own conversations
CREATE POLICY "Users can update own conversations"
    ON public.conversations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can delete their own conversations
CREATE POLICY "Users can delete own conversations"
    ON public.conversations FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- MESSAGES TABLE RLS POLICIES
-- Users can only access their own messages
-- ============================================================================

-- SELECT: Users can view their own messages
CREATE POLICY "Users can view own messages"
    ON public.messages FOR SELECT
    USING (auth.uid() = user_id);

-- INSERT: Users can create messages for themselves
CREATE POLICY "Users can create own messages"
    ON public.messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own messages
CREATE POLICY "Users can update own messages"
    ON public.messages FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can delete their own messages
CREATE POLICY "Users can delete own messages"
    ON public.messages FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- VERIFICATION QUERIES (run after migration to verify policies)
-- ============================================================================
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies WHERE schemaname = 'public';
