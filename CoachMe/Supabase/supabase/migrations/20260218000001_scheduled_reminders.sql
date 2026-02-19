-- Scheduled reminders for coach follow-up check-ins
-- Enables server-side "I'll remind you" behavior from chat responses.

CREATE TABLE IF NOT EXISTS public.scheduled_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    source_message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    reminder_type TEXT NOT NULL CHECK (reminder_type IN ('commitment_checkin')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    remind_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'cancelled')),
    sent_at TIMESTAMPTZ,
    last_error TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(source_message_id, reminder_type)
);

COMMENT ON TABLE public.scheduled_reminders IS
'Queued coach reminders generated from user commitments in chat.';
COMMENT ON COLUMN public.scheduled_reminders.remind_at IS
'When the reminder should be delivered to the user.';
COMMENT ON COLUMN public.scheduled_reminders.status IS
'Delivery state: pending, sent, failed, cancelled.';

CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_due
    ON public.scheduled_reminders(status, remind_at ASC)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_user
    ON public.scheduled_reminders(user_id, remind_at DESC);

ALTER TABLE public.scheduled_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own scheduled reminders" ON public.scheduled_reminders;
CREATE POLICY "Users can view own scheduled reminders"
    ON public.scheduled_reminders FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own scheduled reminders" ON public.scheduled_reminders;
CREATE POLICY "Users can insert own scheduled reminders"
    ON public.scheduled_reminders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own scheduled reminders" ON public.scheduled_reminders;
CREATE POLICY "Users can update own scheduled reminders"
    ON public.scheduled_reminders FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS scheduled_reminders_updated_at ON public.scheduled_reminders;
CREATE TRIGGER scheduled_reminders_updated_at
    BEFORE UPDATE ON public.scheduled_reminders
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
