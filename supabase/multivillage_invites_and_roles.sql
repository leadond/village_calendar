-- Multi-village role switching + helper-friendly invite requests
-- Applied after the May 30, 2026 multi-village foundation.
--
-- Goals:
-- 1. Let a member switch their own role inside the ACTIVE village.
-- 2. Let join requests declare the requested role (helper or parent).
-- 3. Approve requests into user_villages instead of mutating the legacy
--    single-village profile relationship.

alter table if exists public.village_join_requests
  add column if not exists requested_role public.user_role not null default 'helper';

update public.village_join_requests
set requested_role = 'helper'
where requested_role is null;

create or replace function public.request_to_join_village(
  p_code text,
  p_requested_role text default 'helper'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.villages;
  desired_role public.user_role;
begin
  select * into v
  from public.villages
  where invite_code = upper(trim(p_code))
  limit 1;

  if v.id is null then
    return jsonb_build_object('status', 'not_found');
  end if;

  desired_role := case lower(coalesce(trim(p_requested_role), 'helper'))
    when 'parent' then 'parent'::public.user_role
    else 'helper'::public.user_role
  end;

  if exists (
    select 1
    from public.user_villages uv
    where uv.user_id = auth.uid()
      and uv.village_id = v.id
      and coalesce(uv.status, 'active') = 'active'
  ) then
    return jsonb_build_object(
      'status', 'already_member',
      'village_name', v.name,
      'requested_role', desired_role::text
    );
  end if;

  insert into public.village_join_requests (
    village_id,
    requester_id,
    status,
    requested_role
  )
  values (v.id, auth.uid(), 'pending', desired_role)
  on conflict (village_id, requester_id)
  where status = 'pending'
  do update set requested_role = excluded.requested_role;

  return jsonb_build_object(
    'status', 'pending',
    'village_id', v.id,
    'village_name', v.name,
    'requested_role', desired_role::text
  );
end;
$$;

drop function if exists public.pending_join_requests();

create or replace function public.pending_join_requests()
returns table(
  request_id uuid,
  requester_id uuid,
  display_name text,
  email text,
  created_at timestamptz,
  requested_role text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  active_village uuid;
begin
  active_village := public.current_village_id();

  if active_village is null or not exists (
    select 1
    from public.user_villages uv
    where uv.user_id = auth.uid()
      and uv.village_id = active_village
      and uv.role = 'admin'
      and coalesce(uv.status, 'active') = 'active'
  ) then
    return;
  end if;

  return query
  select
    jr.id,
    jr.requester_id,
    p.display_name,
    p.email,
    jr.created_at,
    jr.requested_role::text
  from public.village_join_requests jr
  join public.profiles p on p.id = jr.requester_id
  where jr.village_id = active_village
    and jr.status = 'pending'
  order by jr.created_at asc;
end;
$$;

create or replace function public.approve_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  jr public.village_join_requests;
  active_village uuid;
begin
  active_village := public.current_village_id();
  select * into jr
  from public.village_join_requests
  where id = p_request_id;

  if jr.id is null then
    raise exception 'Request not found';
  end if;

  if active_village is null
     or active_village <> jr.village_id
     or not exists (
       select 1
       from public.user_villages uv
       where uv.user_id = auth.uid()
         and uv.village_id = jr.village_id
         and uv.role = 'admin'
         and coalesce(uv.status, 'active') = 'active'
     ) then
    raise exception 'Not authorized to approve this request';
  end if;

  insert into public.user_villages (user_id, village_id, role, status)
  values (
    jr.requester_id,
    jr.village_id,
    coalesce(jr.requested_role, 'helper'::public.user_role),
    'active'
  )
  on conflict (user_id, village_id)
  do update set
    role = excluded.role,
    status = 'active';

  update public.profiles
  set current_village_id = coalesce(current_village_id, jr.village_id)
  where id = jr.requester_id;

  update public.village_join_requests
  set status = 'approved',
      decided_by = auth.uid(),
      decided_at = now()
  where id = jr.id;
end;
$$;

create or replace function public.reject_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  jr public.village_join_requests;
  active_village uuid;
begin
  active_village := public.current_village_id();
  select * into jr
  from public.village_join_requests
  where id = p_request_id;

  if jr.id is null then
    raise exception 'Request not found';
  end if;

  if active_village is null
     or active_village <> jr.village_id
     or not exists (
       select 1
       from public.user_villages uv
       where uv.user_id = auth.uid()
         and uv.village_id = jr.village_id
         and uv.role = 'admin'
         and coalesce(uv.status, 'active') = 'active'
     ) then
    raise exception 'Not authorized to reject this request';
  end if;

  update public.village_join_requests
  set status = 'rejected',
      decided_by = auth.uid(),
      decided_at = now()
  where id = jr.id;
end;
$$;

create or replace function public.set_my_active_village_role(p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  active_village uuid;
  next_role public.user_role;
begin
  active_village := public.current_village_id();
  if active_village is null then
    raise exception 'No active village selected';
  end if;

  next_role := case lower(coalesce(trim(p_role), 'helper'))
    when 'parent' then 'parent'::public.user_role
    when 'helper' then 'helper'::public.user_role
    when 'admin' then 'admin'::public.user_role
    else null
  end;

  if next_role is null then
    raise exception 'Unsupported role';
  end if;

  update public.user_villages
  set role = next_role
  where user_id = auth.uid()
    and village_id = active_village
    and coalesce(status, 'active') = 'active';

  if not found then
    raise exception 'Membership not found in active village';
  end if;
end;
$$;

grant execute on function public.request_to_join_village(text, text) to authenticated;
grant execute on function public.pending_join_requests() to authenticated;
grant execute on function public.approve_join_request(uuid) to authenticated;
grant execute on function public.reject_join_request(uuid) to authenticated;
grant execute on function public.set_my_active_village_role(text) to authenticated;
