-- Join-by-invite RPC (applied 2026-05-30)
-- The villages SELECT RLS policy only exposes villages you already belong to or
-- admin. Joining by code needs to read a village you're NOT yet in, so we do the
-- lookup + membership update in one SECURITY DEFINER call that bypasses RLS.
create or replace function public.join_village_by_invite(p_code text)
returns public.villages
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.villages;
begin
  select * into v
  from public.villages
  where invite_code = upper(trim(p_code))
  limit 1;

  if v.id is null then
    return null;  -- no village for this code
  end if;

  update public.profiles
  set village_id = v.id,
      current_village_id = v.id
  where id = auth.uid();

  return v;
end;
$$;

grant execute on function public.join_village_by_invite(text) to authenticated;
