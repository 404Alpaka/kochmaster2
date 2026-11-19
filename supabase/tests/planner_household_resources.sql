-- Run after 202611190006. All fixture data is rolled back.
begin;
do $$
declare uid uuid:=gen_random_uuid(); hid uuid; revision bigint; blocked boolean; stored jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values(uid,'planner-'||uid||'@example.com',now(),'{"first_name":"Planner","last_name":"Test"}');
  perform set_config('request.jwt.claim.sub',uid::text,true);
  execute 'set local role authenticated';
  hid:=public.create_household('Planner test');
  revision:=public.save_household_state(hid,jsonb_build_object(
    'householdDinerRules',jsonb_build_object(uid::text,jsonb_build_object('name','Test','participates',true,'confirmed',true,'diet','Vegan','exclusions',jsonb_build_array('Milch'))),
    'recipeCostEstimates',jsonb_build_object('recipe-a',2.5),'budgetCostClass','low','usePlanningStock',true),0);
  if revision<>1 then raise exception 'Shared declarations not saved'; end if;
  revision:=public.save_household_state(hid,'{"pantry":[]}',revision);
  select data into stored from public.household_state where household_id=hid;
  if stored->'householdDinerRules'->uid::text->>'diet' <> 'Vegan' then raise exception 'Older client erased diner rules'; end if;
  if stored->'recipeCostEstimates'->>'recipe-a'<>'2.5' then raise exception 'Older client erased estimates'; end if;
  blocked:=false;
  begin perform public.save_household_state(hid,'{"recipeNotes":{"private":"note"}}',revision); exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Private notes accepted'; end if;
  blocked:=false;
  begin perform public.save_household_state(hid,'{"recipeCostEstimates":{"recipe-a":-1}}',revision); exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Negative cost accepted'; end if;
  blocked:=false;
  begin perform public.save_household_state(hid,'{"budgetCostClass":"unknown"}',revision); exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Invalid cost class accepted'; end if;
  blocked:=false;
  begin perform public.save_household_state(hid,'{"householdDinerRules":{"a":{"confirmed":true}}}',revision); exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Incomplete declaration accepted as complete'; end if;
  blocked:=false;
  begin perform public.save_household_state(hid,'{}',0); exception when serialization_failure then blocked:=true; end;
  if not blocked then raise exception 'Revision check bypassed'; end if;
  revision:=public.save_household_state(hid,'{"householdDinerRules":{},"recipeCostEstimates":{},"budgetCostClass":null,"usePlanningStock":false}',revision);
  select data into stored from public.household_state where household_id=hid;
  if stored->'householdDinerRules'<>'{}'::jsonb or stored->'budgetCostClass'<>'null'::jsonb then raise exception 'Explicit clearing ignored'; end if;
  execute 'reset role';
end $$;
rollback;
