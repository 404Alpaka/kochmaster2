-- Apply after 202611250001. Test accounts and all changes are rolled back.
begin;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  shared_id uuid; solo_id uuid; exported jsonb; n bigint; blocked boolean;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (a,'data-a-'||a||'@example.com','{"first_name":"Test","last_name":"A"}'),
    (b,'data-b-'||b||'@example.com','{"first_name":"Test","last_name":"B"}');
  perform set_config('request.jwt.claim.sub', a::text, true);
  execute 'set local role authenticated';
  n := public.save_user_preferences('{"favoriteRecipes":["private-a"]}',0,a);
  n := public.save_user_week_plan(a,'2026-11-16','[{"recipe":"private-a"}]','["checked-a"]',0);
  n := public.save_user_week_plan(a,'2026-11-23','[{"recipe":"next-a"}]','[]',0);
  shared_id := public.create_household('Shared preserved');
  solo_id := public.create_household('Solo removed');
  n := public.save_household_state(shared_id,'{"pantry":[{"name":"shared"}]}',0);
  n := public.save_household_week(shared_id,'2026-11-16','[{"recipe":"shared"}]','[]',0);
  execute 'reset role';
  insert into public.household_members values(shared_id,b,'editor');
  perform set_config('request.jwt.claim.sub', b::text, true);
  execute 'set local role authenticated';
  n := public.save_user_preferences('{"personalRecipes":["private-b"]}',0,b);
  n := public.save_user_week_plan(b,'2026-11-16','[{"recipe":"private-b"}]','[]',0);
  perform set_config('request.jwt.claim.sub', a::text, true);

  exported := public.export_my_account_data();
  if exported->'profile'->>'user_id' <> a::text or jsonb_array_length(exported->'week_plans') <> 2 then
    raise exception 'Export omitted profile or another private week';
  end if;
  if exported->'preferences'->'favoriteRecipes' <> '["private-a"]'::jsonb then
    raise exception 'Export missing personal preferences';
  end if;
  if exported::text like '%private-b%' or exported::text like '%"pantry"%' then
    raise exception 'Export exposed foreign or shared content';
  end if;
  blocked := false;
  begin perform public.reset_my_account_data(0);
  exception when serialization_failure then blocked := true; end;
  if not blocked then raise exception 'Stale reset accepted'; end if;
  if (select data->'favoriteRecipes' from public.user_preferences where user_id=a) is null then
    raise exception 'Failed reset modified preferences';
  end if;
  n := public.reset_my_account_data(1);
  if n <> 2 then raise exception 'Reset did not advance revision'; end if;
  if exists(select 1 from public.user_week_plans where user_id=a and (meals <> '[]'::jsonb or checked <> '[]'::jsonb or revision <> 2)) then
    raise exception 'Reset did not clear all private weeks with revision tombstones';
  end if;
  blocked := false;
  begin perform public.save_user_week_plan(a,'2026-11-16','[{"recipe":"resurrected"}]','[]',1);
  exception when serialization_failure then blocked := true; end;
  if not blocked then raise exception 'Old device resurrected reset week'; end if;
  blocked := false;
  begin perform public.save_user_preferences('{"resurrected":true}',1,a);
  exception when serialization_failure then blocked := true; end;
  if not blocked then raise exception 'Old device resurrected reset preferences'; end if;
  if (select data->'pantry' from public.household_state where household_id=shared_id) <> '[{"name":"shared"}]'::jsonb then
    raise exception 'Personal reset changed household state';
  end if;
  if (select meals from public.household_week_plans where household_id=shared_id) <> '[{"recipe":"shared"}]'::jsonb then
    raise exception 'Personal reset changed shared week';
  end if;
  perform set_config('request.jwt.claim.sub', b::text, true);
  if (select data->'personalRecipes' from public.user_preferences where user_id=b) <> '["private-b"]'::jsonb then
    raise exception 'Reset changed another account';
  end if;
  perform set_config('request.jwt.claim.sub', a::text, true);
  blocked := false;
  begin perform public.delete_my_account();
  exception when raise_exception then
    if sqlerrm <> 'Transfer household administration first' then raise; end if;
    blocked := true;
  end;
  if not blocked then raise exception 'Last shared admin deleted'; end if;
  execute 'reset role';
  if not exists(select 1 from auth.users where id=a) or not exists(select 1 from public.households where id=solo_id) then
    raise exception 'Refused deletion had side effects';
  end if;
  execute 'set local role authenticated';
  perform public.change_household_role(shared_id,b,'admin');
  execute 'reset role';
  -- Only the isolated harness creates storage metadata fixtures. A real
  -- Supabase project must never create/delete Storage rows directly.
  if not exists(select 1 from information_schema.columns
      where table_schema='storage' and table_name='objects' and column_name='bucket_id') then
    insert into storage.objects(owner,owner_id) values(a,a::text);
    execute 'set local role authenticated';
    blocked := false;
    begin perform public.delete_my_account();
    exception when raise_exception then
      if sqlerrm <> 'Account owns storage objects' then raise; end if;
      blocked := true;
    end;
    if not blocked then raise exception 'Storage owner deletion accepted'; end if;
    execute 'reset role';
    delete from storage.objects where owner_id=a::text;
  end if;
  execute 'set local role authenticated';
  perform public.delete_my_account();
  execute 'reset role';
  if exists(select 1 from auth.users where id=a)
    or exists(select 1 from public.customer_profiles where user_id=a)
    or exists(select 1 from public.user_preferences where user_id=a)
    or exists(select 1 from public.user_week_plans where user_id=a)
    or exists(select 1 from public.household_members where user_id=a)
    or exists(select 1 from public.households where id=solo_id) then
    raise exception 'Deletion left personal data or a one-person household';
  end if;
  if not exists(select 1 from auth.users where id=b)
    or not exists(select 1 from public.households where id=shared_id)
    or not exists(select 1 from public.household_week_plans where household_id=shared_id) then
    raise exception 'Deletion removed another account or shared content';
  end if;
  -- An old JWT cannot recreate a deleted account through these functions.
  execute 'set local role authenticated';
  blocked := false;
  begin perform public.export_my_account_data();
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Deleted user exported data'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  blocked := false;
  begin perform public.delete_my_account();
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Missing auth allowed deletion'; end if;
  execute 'reset role';
  execute 'set local role anon';
  blocked := false;
  begin perform public.reset_my_account_data(0);
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Anonymous reset allowed'; end if;
  blocked := false;
  begin perform public.export_my_account_data();
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Anonymous export allowed'; end if;
  blocked := false;
  begin perform public.delete_my_account();
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Anonymous deletion allowed'; end if;
  execute 'reset role';
end $$;
select 'PASS: Export, Reset, Konflikte, Isolation und geschützte Kontolöschung' as result;
rollback;
