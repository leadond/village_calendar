create extension if not exists pgcrypto;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.villages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
  admin_id uuid references auth.users(id) on delete set null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  display_name text,
  avatar_url text,
  role text not null default 'parent' check (role in ('parent', 'helper', 'admin', 'guest')),
  village_id uuid references public.villages(id) on delete set null,
  reliability_score numeric(3,2) not null default 5.00,
  total_commitments int not null default 0,
  completed_commitments int not null default 0,
  cancellation_count int not null default 0,
  late_count int not null default 0,
  subscription_tier text not null default 'free',
  gps_consent boolean not null default false,
  push_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kid_profiles (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  village_id uuid references public.villages(id) on delete cascade,
  name text not null,
  nickname text,
  photo_url text,
  date_of_birth date,
  school_name text,
  school_address text,
  grade text,
  allergies text[] not null default '{}',
  medical_notes text,
  dietary_restrictions text,
  emergency_contacts jsonb not null default '[]',
  doctor_name text,
  doctor_phone text,
  insurance_info text,
  behavioral_notes text,
  authorized_pickup_people jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.help_requests (
  id uuid primary key default gen_random_uuid(),
  village_id uuid references public.villages(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  kid_ids uuid[] not null default '{}',
  title text not null,
  description text,
  category text not null check (category in (
    'school_pickup', 'school_dropoff', 'sports_practice', 'doctor_appointment',
    'playdate', 'babysitting', 'overnight', 'emergency', 'event', 'party', 'other'
  )),
  status text not null default 'open' check (status in (
    'open', 'claimed', 'confirmed', 'in_progress', 'arrived', 'completed', 'cancelled', 'incident'
  )),
  helper_id uuid references public.profiles(id) on delete set null,
  scheduled_start timestamptz not null,
  scheduled_end timestamptz,
  pickup_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  dropoff_address text,
  dropoff_lat double precision,
  dropoff_lng double precision,
  special_instructions text,
  photo_urls text[] not null default '{}',
  is_recurring boolean not null default false,
  recurrence_rule text,
  recurrence_end_date date,
  parent_confirmed_at timestamptz,
  helper_checkin_at timestamptz,
  helper_checkin_lat double precision,
  helper_checkin_lng double precision,
  helper_checkin_photo_url text,
  arrived_at_destination_at timestamptz,
  parent_receipt_confirmed_at timestamptz,
  parent_receipt_photo_url text,
  trip_duration_minutes int,
  cancellation_reason text,
  cancelled_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.help_requests add column if not exists village_id uuid references public.villages(id) on delete cascade;
alter table public.help_requests add column if not exists creator_id uuid references public.profiles(id) on delete cascade;
alter table public.help_requests add column if not exists kid_ids uuid[] not null default '{}';
alter table public.help_requests add column if not exists title text;
alter table public.help_requests add column if not exists description text;
alter table public.help_requests add column if not exists category text;
alter table public.help_requests add column if not exists status text not null default 'open';
alter table public.help_requests add column if not exists helper_id uuid references public.profiles(id) on delete set null;
alter table public.help_requests add column if not exists scheduled_start timestamptz;
alter table public.help_requests add column if not exists scheduled_end timestamptz;
alter table public.help_requests add column if not exists pickup_address text;
alter table public.help_requests add column if not exists pickup_lat double precision;
alter table public.help_requests add column if not exists pickup_lng double precision;
alter table public.help_requests add column if not exists dropoff_address text;
alter table public.help_requests add column if not exists dropoff_lat double precision;
alter table public.help_requests add column if not exists dropoff_lng double precision;
alter table public.help_requests add column if not exists special_instructions text;
alter table public.help_requests add column if not exists photo_urls text[] not null default '{}';
alter table public.help_requests add column if not exists is_recurring boolean not null default false;
alter table public.help_requests add column if not exists recurrence_rule text;
alter table public.help_requests add column if not exists recurrence_end_date date;
alter table public.help_requests add column if not exists parent_confirmed_at timestamptz;
alter table public.help_requests add column if not exists helper_checkin_at timestamptz;
alter table public.help_requests add column if not exists helper_checkin_lat double precision;
alter table public.help_requests add column if not exists helper_checkin_lng double precision;
alter table public.help_requests add column if not exists helper_checkin_photo_url text;
alter table public.help_requests add column if not exists arrived_at_destination_at timestamptz;
alter table public.help_requests add column if not exists parent_receipt_confirmed_at timestamptz;
alter table public.help_requests add column if not exists parent_receipt_photo_url text;
alter table public.help_requests add column if not exists trip_duration_minutes int;
alter table public.help_requests add column if not exists cancellation_reason text;
alter table public.help_requests add column if not exists cancelled_by uuid references public.profiles(id);
alter table public.help_requests add column if not exists created_at timestamptz not null default now();
alter table public.help_requests add column if not exists updated_at timestamptz not null default now();

create table if not exists public.gps_breadcrumbs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.help_requests(id) on delete cascade,
  helper_id uuid not null references public.profiles(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  speed double precision,
  heading double precision,
  ts timestamptz not null default now()
);

alter table public.gps_breadcrumbs add column if not exists request_id uuid references public.help_requests(id) on delete cascade;
alter table public.gps_breadcrumbs add column if not exists helper_id uuid references public.profiles(id) on delete cascade;
alter table public.gps_breadcrumbs add column if not exists lat double precision;
alter table public.gps_breadcrumbs add column if not exists lng double precision;
alter table public.gps_breadcrumbs add column if not exists accuracy double precision;
alter table public.gps_breadcrumbs add column if not exists speed double precision;
alter table public.gps_breadcrumbs add column if not exists heading double precision;
alter table public.gps_breadcrumbs add column if not exists ts timestamptz not null default now();

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.help_requests(id) on delete cascade unique,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  overall_score numeric(2,1) not null check (overall_score between 1 and 5),
  reliability_score numeric(2,1),
  communication_score numeric(2,1),
  care_score numeric(2,1),
  comment text,
  created_at timestamptz not null default now()
);

alter table public.ratings add column if not exists request_id uuid references public.help_requests(id) on delete cascade;
alter table public.ratings add column if not exists reviewer_id uuid references public.profiles(id) on delete cascade;
alter table public.ratings add column if not exists reviewee_id uuid references public.profiles(id) on delete cascade;
alter table public.ratings add column if not exists overall_score numeric(2,1);
alter table public.ratings add column if not exists reliability_score numeric(2,1);
alter table public.ratings add column if not exists communication_score numeric(2,1);
alter table public.ratings add column if not exists care_score numeric(2,1);
alter table public.ratings add column if not exists comment text;
alter table public.ratings add column if not exists created_at timestamptz not null default now();

create table if not exists public.request_comments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.help_requests(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.request_comments add column if not exists request_id uuid references public.help_requests(id) on delete cascade;
alter table public.request_comments add column if not exists author_id uuid references public.profiles(id) on delete cascade;
alter table public.request_comments add column if not exists body text;
alter table public.request_comments add column if not exists created_at timestamptz not null default now();

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.help_requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid references public.profiles(id) on delete cascade,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.messages add column if not exists request_id uuid references public.help_requests(id) on delete cascade;
alter table public.messages add column if not exists sender_id uuid references public.profiles(id) on delete cascade;
alter table public.messages add column if not exists recipient_id uuid references public.profiles(id) on delete cascade;
alter table public.messages add column if not exists body text;
alter table public.messages add column if not exists read_at timestamptz;
alter table public.messages add column if not exists created_at timestamptz not null default now();

create table if not exists public.carpool_groups (
  id uuid primary key default gen_random_uuid(),
  village_id uuid not null references public.villages(id) on delete cascade,
  name text not null,
  category text,
  location text,
  schedule_day text,
  schedule_time time,
  rotation_order uuid[] not null default '{}',
  current_rotation_index int not null default 0,
  kid_ids uuid[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.carpool_groups add column if not exists village_id uuid references public.villages(id) on delete cascade;
alter table public.carpool_groups add column if not exists name text;
alter table public.carpool_groups add column if not exists category text;
alter table public.carpool_groups add column if not exists location text;
alter table public.carpool_groups add column if not exists schedule_day text;
alter table public.carpool_groups add column if not exists schedule_time time;
alter table public.carpool_groups add column if not exists rotation_order uuid[] not null default '{}';
alter table public.carpool_groups add column if not exists current_rotation_index int not null default 0;
alter table public.carpool_groups add column if not exists kid_ids uuid[] not null default '{}';
alter table public.carpool_groups add column if not exists active boolean not null default true;
alter table public.carpool_groups add column if not exists created_at timestamptz not null default now();
alter table public.carpool_groups add column if not exists updated_at timestamptz not null default now();

create table if not exists public.emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  village_id uuid references public.villages(id) on delete cascade,
  alert_type text not null check (alert_type in ('help_needed', 'medical', 'safety', 'missing_child')),
  message text,
  lat double precision,
  lng double precision,
  request_id uuid references public.help_requests(id),
  status text not null default 'active' check (status in ('active', 'resolved', 'false_alarm')),
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.emergency_alerts add column if not exists sender_id uuid references public.profiles(id) on delete cascade;
alter table public.emergency_alerts add column if not exists village_id uuid references public.villages(id) on delete cascade;
alter table public.emergency_alerts add column if not exists alert_type text;
alter table public.emergency_alerts add column if not exists message text;
alter table public.emergency_alerts add column if not exists lat double precision;
alter table public.emergency_alerts add column if not exists lng double precision;
alter table public.emergency_alerts add column if not exists request_id uuid references public.help_requests(id);
alter table public.emergency_alerts add column if not exists status text not null default 'active';
alter table public.emergency_alerts add column if not exists resolved_by uuid references public.profiles(id);
alter table public.emergency_alerts add column if not exists resolved_at timestamptz;
alter table public.emergency_alerts add column if not exists created_at timestamptz not null default now();

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications add column if not exists recipient_id uuid references public.profiles(id) on delete cascade;
alter table public.notifications add column if not exists type text;
alter table public.notifications add column if not exists title text;
alter table public.notifications add column if not exists body text;
alter table public.notifications add column if not exists data jsonb not null default '{}';
alter table public.notifications add column if not exists read_at timestamptz;
alter table public.notifications add column if not exists created_at timestamptz not null default now();

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.audit_logs add column if not exists actor_id uuid references public.profiles(id) on delete set null;
alter table public.audit_logs add column if not exists action text;
alter table public.audit_logs add column if not exists entity_type text;
alter table public.audit_logs add column if not exists entity_id uuid;
alter table public.audit_logs add column if not exists metadata jsonb not null default '{}';
alter table public.audit_logs add column if not exists created_at timestamptz not null default now();

create table if not exists public.notification_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  new_requests boolean not null default true,
  claim_updates boolean not null default true,
  trip_updates boolean not null default true,
  emergency_alerts boolean not null default true,
  messages boolean not null default true,
  quiet_hours_start time,
  quiet_hours_end time,
  updated_at timestamptz not null default now()
);

alter table public.notification_settings add column if not exists profile_id uuid references public.profiles(id) on delete cascade;
alter table public.notification_settings add column if not exists new_requests boolean not null default true;
alter table public.notification_settings add column if not exists claim_updates boolean not null default true;
alter table public.notification_settings add column if not exists trip_updates boolean not null default true;
alter table public.notification_settings add column if not exists emergency_alerts boolean not null default true;
alter table public.notification_settings add column if not exists messages boolean not null default true;
alter table public.notification_settings add column if not exists quiet_hours_start time;
alter table public.notification_settings add column if not exists quiet_hours_end time;
alter table public.notification_settings add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_profiles_village_id on public.profiles(village_id);
create index if not exists idx_kid_profiles_parent_id on public.kid_profiles(parent_id);
create index if not exists idx_kid_profiles_village_id on public.kid_profiles(village_id);
create index if not exists idx_help_requests_village_status on public.help_requests(village_id, status);
create index if not exists idx_help_requests_creator_id on public.help_requests(creator_id);
create index if not exists idx_help_requests_helper_id on public.help_requests(helper_id);
create index if not exists idx_help_requests_scheduled_start on public.help_requests(scheduled_start);
create index if not exists idx_gps_breadcrumbs_request_ts on public.gps_breadcrumbs(request_id, ts desc);
create index if not exists idx_notifications_recipient_read on public.notifications(recipient_id, read_at);

create or replace trigger villages_touch_updated_at
before update on public.villages
for each row execute function public.touch_updated_at();

create or replace trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

create or replace trigger kid_profiles_touch_updated_at
before update on public.kid_profiles
for each row execute function public.touch_updated_at();

create or replace trigger help_requests_touch_updated_at
before update on public.help_requests
for each row execute function public.touch_updated_at();

create or replace trigger carpool_groups_touch_updated_at
before update on public.carpool_groups
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.notification_settings (profile_id)
  values (new.id)
  on conflict (profile_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.villages enable row level security;
alter table public.profiles enable row level security;
alter table public.kid_profiles enable row level security;
alter table public.help_requests enable row level security;
alter table public.gps_breadcrumbs enable row level security;
alter table public.ratings enable row level security;
alter table public.request_comments enable row level security;
alter table public.messages enable row level security;
alter table public.carpool_groups enable row level security;
alter table public.emergency_alerts enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;
alter table public.notification_settings enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

create or replace function public.current_village_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select village_id from public.profiles where id = auth.uid()
$$;

drop policy if exists "profiles_read_self_or_village" on public.profiles;
create policy "profiles_read_self_or_village"
on public.profiles for select
to authenticated
using (id = auth.uid() or village_id = public.current_village_id());

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "villages_read_member" on public.villages;
create policy "villages_read_member"
on public.villages for select
to authenticated
using (id = public.current_village_id() or admin_id = auth.uid());

drop policy if exists "villages_create_self_admin" on public.villages;
create policy "villages_create_self_admin"
on public.villages for insert
to authenticated
with check (admin_id = auth.uid());

drop policy if exists "villages_update_admin" on public.villages;
create policy "villages_update_admin"
on public.villages for update
to authenticated
using (admin_id = auth.uid())
with check (admin_id = auth.uid());

drop policy if exists "kids_read_parent_or_village_admin" on public.kid_profiles;
create policy "kids_read_parent_or_village_admin"
on public.kid_profiles for select
to authenticated
using (
  parent_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.village_id = kid_profiles.village_id
  )
);

drop policy if exists "kids_parent_manage" on public.kid_profiles;
create policy "kids_parent_manage"
on public.kid_profiles for all
to authenticated
using (parent_id = auth.uid())
with check (parent_id = auth.uid());

drop policy if exists "requests_read_village_or_party" on public.help_requests;
create policy "requests_read_village_or_party"
on public.help_requests for select
to authenticated
using (
  village_id = public.current_village_id()
  or creator_id = auth.uid()
  or helper_id = auth.uid()
);

drop policy if exists "requests_create_self" on public.help_requests;
create policy "requests_create_self"
on public.help_requests for insert
to authenticated
with check (creator_id = auth.uid());

drop policy if exists "requests_update_party" on public.help_requests;
create policy "requests_update_party"
on public.help_requests for update
to authenticated
using (creator_id = auth.uid() or helper_id = auth.uid())
with check (creator_id = auth.uid() or helper_id = auth.uid());

drop policy if exists "request_comments_party_read" on public.request_comments;
create policy "request_comments_party_read"
on public.request_comments for select
to authenticated
using (
  exists (
    select 1 from public.help_requests r
    where r.id = request_comments.request_id
      and (r.creator_id = auth.uid() or r.helper_id = auth.uid() or r.village_id = public.current_village_id())
  )
);

drop policy if exists "request_comments_party_insert" on public.request_comments;
create policy "request_comments_party_insert"
on public.request_comments for insert
to authenticated
with check (author_id = auth.uid());

drop policy if exists "gps_party_read" on public.gps_breadcrumbs;
create policy "gps_party_read"
on public.gps_breadcrumbs for select
to authenticated
using (
  helper_id = auth.uid()
  or exists (
    select 1 from public.help_requests r
    where r.id = gps_breadcrumbs.request_id and r.creator_id = auth.uid()
  )
);

drop policy if exists "gps_helper_insert" on public.gps_breadcrumbs;
create policy "gps_helper_insert"
on public.gps_breadcrumbs for insert
to authenticated
with check (helper_id = auth.uid());

drop policy if exists "ratings_party_read" on public.ratings;
create policy "ratings_party_read"
on public.ratings for select
to authenticated
using (reviewer_id = auth.uid() or reviewee_id = auth.uid());

drop policy if exists "ratings_reviewer_insert" on public.ratings;
create policy "ratings_reviewer_insert"
on public.ratings for insert
to authenticated
with check (reviewer_id = auth.uid());

drop policy if exists "messages_party_read" on public.messages;
create policy "messages_party_read"
on public.messages for select
to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "messages_sender_insert" on public.messages;
create policy "messages_sender_insert"
on public.messages for insert
to authenticated
with check (sender_id = auth.uid());

drop policy if exists "village_tables_read_members" on public.carpool_groups;
create policy "village_tables_read_members"
on public.carpool_groups for select
to authenticated
using (village_id = public.current_village_id());

drop policy if exists "carpool_admin_manage" on public.carpool_groups;
create policy "carpool_admin_manage"
on public.carpool_groups for all
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.village_id = carpool_groups.village_id
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.village_id = carpool_groups.village_id
  )
);

drop policy if exists "emergency_alerts_village_read" on public.emergency_alerts;
create policy "emergency_alerts_village_read"
on public.emergency_alerts for select
to authenticated
using (village_id = public.current_village_id() or sender_id = auth.uid());

drop policy if exists "emergency_alerts_sender_insert" on public.emergency_alerts;
create policy "emergency_alerts_sender_insert"
on public.emergency_alerts for insert
to authenticated
with check (sender_id = auth.uid());

drop policy if exists "notifications_recipient_read" on public.notifications;
create policy "notifications_recipient_read"
on public.notifications for select
to authenticated
using (recipient_id = auth.uid());

drop policy if exists "notifications_recipient_update" on public.notifications;
create policy "notifications_recipient_update"
on public.notifications for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

drop policy if exists "audit_read_self_or_admin" on public.audit_logs;
create policy "audit_read_self_or_admin"
on public.audit_logs for select
to authenticated
using (
  actor_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

drop policy if exists "notification_settings_owner" on public.notification_settings;
create policy "notification_settings_owner"
on public.notification_settings for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());
