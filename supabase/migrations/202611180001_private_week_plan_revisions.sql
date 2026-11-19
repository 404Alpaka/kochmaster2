begin;

alter table public.user_week_plans
  add column revision bigint not null default 0 check (revision >= 0);

-- All app writes must compare the version that was loaded. Old clients must
-- fail rather than bypass the conflict check through a direct upsert.
revoke insert, update, delete on public.user_week_plans from public, anon, authenticated;

create function public.save_user_week_plan(
  p_user uuid, p_week date, p_meals jsonb, p_checked jsonb, p_revision bigint
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare next_revision bigint;
begin
  if auth.uid() is null or p_user is distinct from auth.uid() then
    raise exception 'Matching account required' using errcode = '42501';
  end if;
  if p_revision is null or p_revision < 0 then
    raise exception 'Invalid revision' using errcode = '22023';
  end if;

  insert into public.user_week_plans(user_id, week_start)
    values (auth.uid(), p_week) on conflict do nothing;
  update public.user_week_plans
    set meals = p_meals, checked = p_checked, revision = revision + 1
    where user_id = auth.uid() and week_start = p_week and revision = p_revision
    returning revision into next_revision;
  if not found then
    raise exception 'Week changed on another device' using errcode = '40001';
  end if;
  return next_revision;
end $$;

revoke all on function public.save_user_week_plan(uuid,date,jsonb,jsonb,bigint) from public, anon;
grant execute on function public.save_user_week_plan(uuid,date,jsonb,jsonb,bigint) to authenticated;
commit;
