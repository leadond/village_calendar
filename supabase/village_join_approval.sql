-- Admin-approved village joins (applied 2026-05-30)
-- Replaces direct join-by-code. A request creates a pending row; a village
-- admin approves/rejects. All access goes through SECURITY DEFINER RPCs because
-- the requester can't read the target village (RLS) before joining, and the
-- admin can't read the requester's profile (no shared village yet).

create table if not exists public.village_join_requests (
  id uuid primary key default gen_random_uuid(),
  village_id uuid not null references public.villages(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled')),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists uniq_pending_join_request
  on public.village_join_requests(village_id, requester_id)
  where status = 'pending';

alter table public.village_join_requests enable row level security;

drop policy if exists "join_req_requester_read" on public.village_join_requests;
create policy "join_req_requester_read"
on public.village_join_requests for select to authenticated
using (requester_id = auth.uid());

drop policy if exists "join_req_admin_read" on public.village_join_requests;
create policy "join_req_admin_read"
on public.village_join_requests for select to authenticated
using (exists (
  select 1 from public.profiles p
  where p.id = auth.uid() and p.role = 'admin'
    and p.village_id = village_join_requests.village_id
));

drop policy if exists "join_req_requester_cancel" on public.village_join_requests;
create policy "join_req_requester_cancel"
on public.village_join_requests for delete to authenticated
using (requester_id = auth.uid());

grant select, insert, update, delete on public.village_join_requests to authenticated;

-- RPCs ------------------------------------------------------------------------
create or replace function public.request_to_join_village(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.villages; me public.profiles;
begin
  select * into v from public.villages where invite_code = upper(trim(p_code)) limit 1;
  if v.id is null then return jsonb_build_object('status','not_found'); end if;
  select * into me from public.profiles where id = auth.uid();
  if me.village_id = v.id then
    return jsonb_build_object('status','already_member','village_name',v.name);
  end if;
  insert into public.village_join_requests (village_id, requester_id, status)
  values (v.id, auth.uid(), 'pending') on conflict do nothing;
  return jsonb_build_object('status','pending','village_id',v.id,'village_name',v.name);
end; $$;

create or replace function public.my_pending_join_request()
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select jr.id, jr.status, v.id as village_id, v.name as village_name into r
  from public.village_join_requests jr
  join public.villages v on v.id = jr.village_id
  where jr.requester_id = auth.uid() and jr.status = 'pending'
  order by jr.created_at desc limit 1;
  if r.id is null then return null; end if;
  return jsonb_build_object('request_id',r.id,'status',r.status,
    'village_id',r.village_id,'village_name',r.village_name);
end; $$;

create or replace function public.pending_join_requests()
returns table(request_id uuid, requester_id uuid, display_name text, email text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare me public.profiles;
begin
  select * into me from public.profiles where id = auth.uid();
  if me.role <> 'admin' or me.village_id is null then return; end if;
  return query
  select jr.id, jr.requester_id, p.display_name, p.email, jr.created_at
  from public.village_join_requests jr
  join public.profiles p on p.id = jr.requester_id
  where jr.village_id = me.village_id and jr.status = 'pending'
  order by jr.created_at asc;
end; $$;

create or replace function public.approve_join_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare jr public.village_join_requests; me public.profiles;
begin
  select * into jr from public.village_join_requests where id = p_request_id;
  if jr.id is null then raise exception 'Request not found'; end if;
  select * into me from public.profiles where id = auth.uid();
  if me.role <> 'admin' or me.village_id <> jr.village_id then
    raise exception 'Not authorized to approve this request';
  end if;
  update public.profiles set village_id = jr.village_id, current_village_id = jr.village_id
    where id = jr.requester_id;
  update public.village_join_requests
    set status='approved', decided_by=auth.uid(), decided_at=now() where id = jr.id;
end; $$;

create or replace function public.reject_join_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare jr public.village_join_requests; me public.profiles;
begin
  select * into jr from public.village_join_requests where id = p_request_id;
  if jr.id is null then raise exception 'Request not found'; end if;
  select * into me from public.profiles where id = auth.uid();
  if me.role <> 'admin' or me.village_id <> jr.village_id then
    raise exception 'Not authorized to reject this request';
  end if;
  update public.village_join_requests
    set status='rejected', decided_by=auth.uid(), decided_at=now() where id = jr.id;
end; $$;

grant execute on function public.request_to_join_village(text) to authenticated;
grant execute on function public.my_pending_join_request() to authenticated;
grant execute on function public.pending_join_requests() to authenticated;
grant execute on function public.approve_join_request(uuid) to authenticated;
grant execute on function public.reject_join_request(uuid) to authenticated;
