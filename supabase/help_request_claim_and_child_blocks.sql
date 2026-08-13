-- Fix claim_help_request for multi-village membership
-- and add child-specific schedule blocks to help requests.

alter table if exists public.help_requests
  add column if not exists child_schedule_blocks jsonb not null default '[]'::jsonb;

create or replace function public.claim_help_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.help_requests;
  active_village uuid;
begin
  select * into r from public.help_requests where id = p_request_id;
  if r.id is null then
    raise exception 'Request not found';
  end if;

  if r.status <> 'open' then
    raise exception 'Request is no longer open';
  end if;

  active_village := public.current_village_id();
  if active_village is null or active_village <> r.village_id then
    raise exception 'You can only claim requests in your active village';
  end if;

  if not exists (
    select 1
    from public.user_villages uv
    where uv.user_id = auth.uid()
      and uv.village_id = r.village_id
      and coalesce(uv.status, 'active') = 'active'
  ) then
    raise exception 'You are not an active member of this village';
  end if;

  if r.creator_id = auth.uid() then
    raise exception 'You cannot claim your own request';
  end if;

  update public.help_requests
  set helper_id = auth.uid(),
      status = 'claimed',
      claimed_at = now(),
      updated_at = now()
  where id = r.id;
end;
$$;

grant execute on function public.claim_help_request(uuid) to authenticated;
