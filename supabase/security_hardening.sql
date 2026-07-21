-- Security hardening (applied 2026-05-30), from Supabase security advisor.
-- Reduced warnings from 97 -> ~35 (remaining are intentional: authenticated
-- users are meant to call our RPC API; each RPC validates auth.uid() internally).

-- 1. Drop over-permissive (WITH CHECK true) INSERT policies. These tables are
--    written only by SECURITY DEFINER triggers / the service role.
drop policy if exists "Users can create notifications" on public.notifications;
drop policy if exists "va_insert" on public.village_admins;
drop policy if exists "System can insert activity" on public.activity_feed;
drop policy if exists "System can insert SMS logs" on public.sms_logs;

-- 2. Remove broad SELECT (listing) policies on public storage buckets.
drop policy if exists "kid_photos_read" on storage.objects;
drop policy if exists "Avatar View Policy" on storage.objects;

-- 3. Pin search_path on flagged functions (see migration for the full list).

-- 4. Remove blanket EXECUTE from anon/public; grant only to authenticated +
--    service_role (default privileges updated for future functions too).
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public grant execute on functions to authenticated, service_role;

-- 5. Remove trigger-only functions from the REST /rpc surface (they still fire
--    as triggers; RLS helper functions like current_village_id / is_member /
--    is_active_admin intentionally KEEP authenticated EXECUTE).
--    Revoked: notify_* (7), handle_new_user, auto_confirm_email,
--    notifications_compat, touch_updated_at.

-- STILL TODO in the Supabase dashboard (not SQL):
--   * Authentication > Providers > Email: enable "Leaked password protection".
--   * Re-enable email confirmation with a real SMTP provider before launch.
--   * Consider private kid-photos bucket + signed URLs for stronger child-photo
--     privacy (requires app changes to fetch signed URLs).
