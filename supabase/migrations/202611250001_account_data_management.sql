begin;

-- Complete personal export in one database snapshot. Shared household contents
-- and authentication secrets are intentionally outside this export's scope.
create function public.export_my_account_data() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare account_id uuid := auth.uid(); result jsonb;
begin
  if account_id is null or not exists(select 1 from auth.users where id = account_id) then
    raise exception 'Account required' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'format', 'mise-account-export',
    'version', 1,
    'exported_at', now(),
    'scope', 'personal',
    'profile', jsonb_build_object(
      'user_id', u.id, 'email', u.email,
      'first_name', coalesce(u.raw_user_meta_data->>'first_name', c.first_name),
      'last_name', coalesce(u.raw_user_meta_data->>'last_name', c.last_name),
      'customer_number', c.customer_number
    ),
    'preferences', coalesce((select p.data from public.user_preferences p where p.user_id = account_id), '{}'::jsonb),
    'week_plans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'week_start', w.week_start, 'meals', w.meals,
        'checked', w.checked, 'revision', w.revision
      ) order by w.week_start)
      from public.user_week_plans w where w.user_id = account_id
    ), '[]'::jsonb),
    'household_memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'household_id', h.id, 'name', h.name, 'role', m.role
      ) order by h.id)
      from public.household_members m join public.households h on h.id = m.household_id
      where m.user_id = account_id
    ), '[]'::jsonb)
  ) into result
  from auth.users u left join public.customer_profiles c on c.user_id = u.id
  where u.id = account_id;
  return result;
end $$;

create function public.reset_my_account_data(p_revision bigint) returns bigint
language plpgsql security definer set search_path = '' as $$
declare account_id uuid := auth.uid(); next_revision bigint;
begin
  if account_id is null or not exists(select 1 from auth.users where id = account_id) then
    raise exception 'Account required' using errcode = '42501';
  end if;
  if p_revision is null or p_revision < 0 then
    raise exception 'Invalid revision' using errcode = '22023';
  end if;
  -- Keep revision tombstones so an old device cannot resurrect cleared data.
  insert into public.user_preferences(user_id) values(account_id) on conflict do nothing;
  update public.user_preferences set data = '{}'::jsonb,
    revision = revision + 1, updated_at = now()
    where user_id = account_id and revision = p_revision
    returning revision into next_revision;
  if not found then
    raise exception 'Preferences changed on another device' using errcode = '40001';
  end if;
  update public.user_week_plans set meals = '[]'::jsonb,
    checked = '[]'::jsonb, revision = revision + 1
    where user_id = account_id;
  return next_revision;
end $$;

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare account_id uuid := auth.uid(); account_email text;
begin
  select email into account_email from auth.users where id = account_id for update;
  if account_id is null or not found then
    raise exception 'Account required' using errcode = '42501';
  end if;
  -- Use the same household locks as membership/role changes. A shared household
  -- must retain an admin; a one-person household can be removed with its owner.
  perform 1 from public.households h
    join public.household_members m on m.household_id = h.id
    where m.user_id = account_id order by h.id for update of h;
  if exists(
    select 1 from public.household_members mine
    where mine.user_id = account_id and mine.role = 'admin'
      and exists(select 1 from public.household_members other
        where other.household_id = mine.household_id and other.user_id <> account_id)
      and not exists(select 1 from public.household_members other
        where other.household_id = mine.household_id and other.user_id <> account_id and other.role = 'admin')
  ) then
    raise exception 'Transfer household administration first' using errcode = 'P0001';
  end if;
  -- Supabase Storage objects must be transferred or removed through supported
  -- storage management before deleting their owner. Never delete storage rows.
  if exists(select 1 from storage.objects where owner_id = account_id::text or owner = account_id) then
    raise exception 'Account owns storage objects' using errcode = 'P0001';
  end if;
  delete from public.households h
    where exists(select 1 from public.household_members m where m.household_id = h.id and m.user_id = account_id)
      and not exists(select 1 from public.household_members m where m.household_id = h.id and m.user_id <> account_id);
  delete from public.household_invitations where lower(email) = lower(account_email);
  -- FK cascades remove preferences, every private week, customer profile,
  -- recipe-admin membership, and household memberships in the same transaction.
  delete from auth.users where id = account_id;
end $$;

revoke all on function public.export_my_account_data(), public.reset_my_account_data(bigint), public.delete_my_account()
  from public, anon;
grant execute on function public.export_my_account_data(), public.reset_my_account_data(bigint), public.delete_my_account()
  to authenticated;

commit;
