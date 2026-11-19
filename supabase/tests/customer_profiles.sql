begin;
do $$
declare a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); bad uuid := gen_random_uuid(); n bigint; blocked boolean;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (a,'customer-a-'||a||'@example.com','{"first_name":"  Élodie  ","last_name":"O’Connor","customer_number":1}'),
    (b,'customer-b-'||b||'@example.com','{"first_name":"李","last_name":"Müller"}');
  select customer_number into n from public.customer_profiles where user_id=a;
  if n < 100000 or n = (select customer_number from public.customer_profiles where user_id=b) then
    raise exception 'Customer number not generated uniquely'; end if;
  if (select first_name from public.customer_profiles where user_id=a) <> 'Élodie' then raise exception 'Name not trimmed'; end if;
  blocked := false;
  begin insert into auth.users(id,email,raw_user_meta_data) values(bad,'bad-'||bad||'@example.com','{"first_name":" ","last_name":"Test"}');
  exception when check_violation then blocked := true; end;
  if not blocked or exists(select 1 from auth.users where id=bad) then raise exception 'Invalid signup not rolled back'; end if;
  update auth.users set raw_user_meta_data=raw_user_meta_data||'{"customer_number":2}' where id=a;
  if (select customer_number from public.customer_profiles where user_id=a) <> n then raise exception 'Customer number mutable via metadata'; end if;
  perform set_config('request.jwt.claim.sub', a::text, true);
  execute 'set local role authenticated';
  if (select count(*) from public.customer_profiles) <> 1 then raise exception 'Foreign profile visible'; end if;
  blocked := false;
  begin update public.customer_profiles set customer_number=default where user_id=a;
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Customer profile writable'; end if;
  blocked := false;
  begin insert into public.customer_profiles(user_id) values(gen_random_uuid());
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Customer profile insertable'; end if;
  execute 'reset role';
  execute 'set local role anon';
  blocked := false;
  begin perform * from public.customer_profiles;
  exception when insufficient_privilege then blocked := true; end;
  if not blocked then raise exception 'Anonymous profiles readable'; end if;
  execute 'reset role';
end $$;
select 'PASS: Pflichtnamen, Kundennummern, Profilanlage und private Zugriffsrechte' as result;
rollback;
