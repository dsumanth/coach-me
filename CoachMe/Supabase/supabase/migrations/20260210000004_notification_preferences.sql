-- Migration: Add notification_preferences to context_profiles
-- Story 8-3: Push Permission Timing & Notification Preferences

ALTER TABLE public.context_profiles
ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT NULL;

COMMENT ON COLUMN public.context_profiles.notification_preferences IS
'User notification preferences: { "check_ins_enabled": bool, "frequency": "daily"|"few_times_a_week"|"weekly" }';
