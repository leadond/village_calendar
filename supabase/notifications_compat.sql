-- Fix (applied 2026-05-30): the notifications table is a V1/V2 hybrid with a
-- legacy `message` column that is NOT NULL (and `user_id`), while our triggers
-- write the V2 `body`/`recipient_id`. Inserts failed the NOT NULL check and
-- rolled back the parent action (e.g. a direct message returned HTTP 400).
-- This BEFORE INSERT trigger keeps the V1 and V2 columns in sync for every
-- notification insert.
create or replace function public.notifications_compat()
returns trigger language plpgsql as $$
begin
  new.message := coalesce(nullif(new.message, ''), new.body, new.title, '');
  if new.body is null or new.body = '' then new.body := new.message; end if;
  new.user_id := coalesce(new.user_id, new.recipient_id);
  new.recipient_id := coalesce(new.recipient_id, new.user_id);
  return new;
end; $$;

drop trigger if exists trg_notifications_compat on public.notifications;
create trigger trg_notifications_compat before insert on public.notifications
for each row execute function public.notifications_compat();
