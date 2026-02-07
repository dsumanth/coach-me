-- Migration: 20260205000001_initial_schema.sql
-- Description: Create core tables for Coach App (users, conversations, messages)
-- Author: Coach App Development Team
-- Date: 2026-02-05

-- ============================================================================
-- USERS TABLE
-- Extends Supabase auth.users with app-specific fields
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'expired', 'cancelled')),
    trial_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (CRITICAL: Must be enabled on all tables)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_subscription_status ON public.users(subscription_status);

COMMENT ON TABLE public.users IS 'App-specific user data extending Supabase auth.users';
COMMENT ON COLUMN public.users.subscription_status IS 'User subscription state: trial, active, expired, cancelled';

-- ============================================================================
-- CONVERSATIONS TABLE
-- Stores coaching conversation threads
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT,
    domain TEXT CHECK (domain IN ('life', 'career', 'relationships', 'mindset', 'creativity', 'fitness', 'leadership', NULL)),
    last_message_at TIMESTAMPTZ,
    message_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- Indexes for conversations table
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON public.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON public.conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_domain ON public.conversations(domain);

COMMENT ON TABLE public.conversations IS 'Coaching conversation threads';
COMMENT ON COLUMN public.conversations.domain IS 'Coaching domain: life, career, relationships, mindset, creativity, fitness, leadership';

-- ============================================================================
-- MESSAGES TABLE
-- Stores individual messages within conversations
-- ============================================================================
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

-- Enable Row Level Security
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Indexes for messages table
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON public.messages(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);

COMMENT ON TABLE public.messages IS 'Individual messages within coaching conversations';
COMMENT ON COLUMN public.messages.role IS 'Message sender: user, assistant (AI coach), or system';
COMMENT ON COLUMN public.messages.metadata IS 'Flexible JSONB field for additional message data (e.g., memory references, pattern insights)';

-- ============================================================================
-- UPDATED_AT TRIGGER FUNCTION
-- Automatically updates the updated_at timestamp on row updates
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to users table
DROP TRIGGER IF EXISTS users_updated_at ON public.users;
CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Apply updated_at trigger to conversations table
DROP TRIGGER IF EXISTS conversations_updated_at ON public.conversations;
CREATE TRIGGER conversations_updated_at
    BEFORE UPDATE ON public.conversations
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- VERIFICATION QUERIES (run after migration to verify)
-- ============================================================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
