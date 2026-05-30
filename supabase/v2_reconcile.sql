-- V2 reconciliation migration (applied 2026-05-30)
-- Fixes the V1/V2 hybrid: v2_schema.sql used `create table if not exists` for
-- profiles/villages/kid_profiles, which were no-ops because V1 tables already
-- existed. This adds the missing V2 columns non-destructively and backfills.

-- help_request_status enum: add the full V2 lifecycle (run outside a tx-using
-- statement that references the new values).
alter type public.help_request_status add value if not exists 'confirmed';
alter type public.help_request_status add value if not exists 'in_progress';
alter type public.help_request_status add value if not exists 'arrived';
alter type public.help_request_status add value if not exists 'incident';

-- PROFILES
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists reliability_score numeric(3,2) not null default 5.00;
alter table public.profiles add column if not exists total_commitments int not null default 0;
alter table public.profiles add column if not exists completed_commitments int not null default 0;
alter table public.profiles add column if not exists cancellation_count int not null default 0;
alter table public.profiles add column if not exists late_count int not null default 0;
alter table public.profiles add column if not exists gps_consent boolean not null default false;
alter table public.profiles add column if not exists push_token text;

update public.profiles
set display_name = coalesce(nullif(display_name, ''), nullif(name, ''), split_part(coalesce(email,''),'@',1))
where display_name is null or display_name = '';

-- VILLAGES
alter table public.villages add column if not exists avatar_url text;
alter table public.villages add column if not exists updated_at timestamptz not null default now();

-- KID_PROFILES (legacy birthdate/school/jsonb allergies retained)
alter table public.kid_profiles add column if not exists nickname text;
alter table public.kid_profiles add column if not exists photo_url text;
alter table public.kid_profiles add column if not exists date_of_birth date;
alter table public.kid_profiles add column if not exists school_name text;
alter table public.kid_profiles add column if not exists school_address text;
alter table public.kid_profiles add column if not exists medical_notes text;
alter table public.kid_profiles add column if not exists dietary_restrictions text;
alter table public.kid_profiles add column if not exists doctor_name text;
alter table public.kid_profiles add column if not exists doctor_phone text;
alter table public.kid_profiles add column if not exists insurance_info text;
alter table public.kid_profiles add column if not exists behavioral_notes text;
alter table public.kid_profiles add column if not exists authorized_pickup_people jsonb not null default '[]';

-- Backfill notification_settings + orphaned profiles
insert into public.profiles (id, email, display_name, name)
select u.id, coalesce(u.email,''),
       coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email,''),'@',1)),
       coalesce(u.raw_user_meta_data->>'display_name', split_part(coalesce(u.email,''),'@',1))
from auth.users u
on conflict (id) do nothing;

insert into public.notification_settings (profile_id)
select p.id from public.profiles p
on conflict (profile_id) do nothing;

-- Keep handle_new_user writing both display_name and legacy name
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.notification_settings (profile_id)
  values (new.id)
  on conflict (profile_id) do nothing;

  return new;
end;
$$;
