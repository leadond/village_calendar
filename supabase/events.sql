create extension if not exists pgcrypto;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.events enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.events to authenticated;

drop policy if exists "events_select_authenticated" on public.events;
create policy "events_select_authenticated"
on public.events for select
to authenticated
using (true);

drop policy if exists "events_insert_own" on public.events;
create policy "events_insert_own"
on public.events for insert
to authenticated
with check (auth.uid() = created_by);

drop policy if exists "events_update_own" on public.events;
create policy "events_update_own"
on public.events for update
to authenticated
using (auth.uid() = created_by)
with check (auth.uid() = created_by);

drop policy if exists "events_delete_own" on public.events;
create policy "events_delete_own"
on public.events for delete
to authenticated
using (auth.uid() = created_by);
