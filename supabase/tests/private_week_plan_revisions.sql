-- Run after 202611180001. Test data is rolled back.
begin;
do $$
declare a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); n bigint; blocked boolean;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (a,'week-a-'||a||'@example.com','{"first_name":"Test","last_name":"A"}'),
    (b,'week-b-'||b||'@example.com','{"first_name":"Test","last_name":"B"}');
  perform set_config('request.jwt.claim.sub', a::text, true);
  execute 'set local role authenticated';
  n := public.save_user_week_plan(a,'2026-11-16','[]','[{"ingredient_id":"tomato","unit":"g"}]',0);
  if n <> 1 then raise exception 'Initial revision missing'; end if;
  blocked := false;
  begin perform public.save_user_week_plan(a,'2026-11-16','[]','[]',0);
  exception when serialization_failure then blocked := true; end;
  if not blocked then raise exception 'Stale first write accepted'; end if;
  if (select jsonb_array_length(checked) from public.user_week_plans where user_id=a) <> 1 then
    raise exception 'Conflict overwrote shopping state'; end if;
  n := public.save_user_week_plan(a,'2026-11-16','[]','[]',1);
  if n <> 2 then raise exception 'Revision did not advance'; end if;
  blocked := false;
  begin perform public.save_user_week_plan(a,'2026-11-16','[]','[]',1);
  exception when serialization_failure then blocked := true; end;
  if not blocked then raise exception 'Stale update accepted'; end if;
  blocked := false;
  begin update public.user_week_plans set checked='[]' where user_id=a;
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Direct update bypass'; end if;
  blocked := false;
  begin insert into public.user_week_plans(user_id,week_start) values(a,'2026-11-23');
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Direct insert bypass'; end if;
  perform set_config('request.jwt.claim.sub', b::text, true);
  if (select count(*) from public.user_week_plans where user_id=a) <> 0 then raise exception 'Foreign read'; end if;
  blocked := false;
  begin perform public.save_user_week_plan(a,'2026-11-16','[]','[]',2);
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Foreign write'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  blocked := false;
  begin perform public.save_user_week_plan(b,'2026-11-23','[]','[]',0);
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Unauthenticated write'; end if;
  execute 'reset role';
  execute 'set local role anon';
  blocked := false;
  begin perform public.save_user_week_plan(b,'2026-11-23','[]','[]',0);
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Anonymous execution'; end if;
  execute 'reset role';
end $$;
select 'PASS: Speichern, Neuladen, Versionskonflikte und private Zugriffsrechte' as result;
rollback;
