-- Temporary users, recipes, ingredients and role assignments are rolled back.
begin;
do $$
declare a uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); rid text;
  payload jsonb; n integer; blocked boolean;
begin
  insert into auth.users(id,raw_user_meta_data) values
    (a,'{"first_name":"Test","last_name":"Admin"}'),
    (u,'{"first_name":"Test","last_name":"User"}');
  insert into public.recipe_admins(user_id) values(a);
  insert into public.user_week_plans(user_id,week_start) values(u,'2026-11-16');
  payload:=jsonb_build_object('name','Admin test draft','minutes',15,'servings',2,'steps',jsonb_build_array('Garen.'),
    'is_published',false,'ingredients',jsonb_build_array(jsonb_build_object('name','SQL test ingredient','quantity',150,'unit','g')));
  perform set_config('request.jwt.claim.sub',u::text,true);
  execute 'set local role authenticated';
  if public.is_recipe_admin() then raise exception 'Normal user became admin'; end if;
  begin
    insert into public.recipe_admins(user_id) values(u);
    raise exception 'Self promotion allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform public.admin_save_recipe(payload);
    raise exception 'Normal user can save recipes';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.recipes(id,name,prep_minutes,servings,steps) values('unauthorized','No',1,1,array['No']);
    raise exception 'Direct recipe writes allowed';
  exception when insufficient_privilege then null; end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  if not public.is_recipe_admin() then raise exception 'Admin check failed'; end if;
  rid:=public.admin_save_recipe(payload);
  select count(*) into n from public.recipe_ingredients where recipe_id=rid;
  if n<>1 then raise exception 'Draft ingredients missing'; end if;
  select count(*) into n from public.user_week_plans where user_id=u;
  if n<>0 then raise exception 'Recipe admin can see private plans'; end if;
  execute 'reset role'; execute 'set local role anon';
  select count(*) into n from public.recipes where id=rid;
  if n<>0 then raise exception 'Anonymous user sees draft'; end if;
  begin
    perform public.admin_save_recipe(payload);
    raise exception 'Anonymous user can save';
  exception when insufficient_privilege then null; end;
  execute 'reset role'; execute 'set local role authenticated';
  payload:=payload||jsonb_build_object('id',rid,'name','Published test recipe','is_published',true);
  perform public.admin_save_recipe(payload);
  if exists(select 1 from public.recipes where id=rid and verified_allergens is not null) then raise exception 'Unreviewed became reviewed'; end if;
  payload:=payload||jsonb_build_object('verified_allergens',jsonb_build_array('Soja'),'verified_diets',jsonb_build_array('Vegan','Vegetarisch'));
  perform public.admin_save_recipe(payload);
  if not exists(select 1 from public.recipes where id=rid and verified_allergens=array['Soja'] and verified_diets=array['Vegan','Vegetarisch']) then raise exception 'Metadata missing'; end if;
  blocked:=false;
  begin
    perform public.admin_save_recipe(payload||jsonb_build_object('verified_allergens',jsonb_build_array('Unknown')));
  exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Unknown allergen accepted'; end if;
  blocked:=false;
  begin
    perform public.admin_save_recipe(payload||jsonb_build_object('verified_diets',jsonb_build_array('Vegan')));
  exception when check_violation then blocked:=true; end;
  if not blocked then raise exception 'Contradictory diets accepted'; end if;
  perform public.admin_save_recipe(payload||jsonb_build_object('verified_allergens','[]'::jsonb));
  if not exists(select 1 from public.recipes where id=rid and verified_allergens=array[]::text[]) then raise exception 'Empty review lost'; end if;
  blocked:=false;
  begin
    perform public.admin_save_recipe(payload||jsonb_build_object('name','Must rollback','ingredients',jsonb_build_array(jsonb_build_object('name','SQL test ingredient','quantity',0,'unit','g'))));
  exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Invalid quantity accepted'; end if;
  select count(*) into n from public.recipes where id=rid and name='Published test recipe';
  if n<>1 then raise exception 'Failed save partially changed recipe'; end if;
  select count(*) into n from public.recipe_ingredients where recipe_id=rid and quantity=150;
  if n<>1 then raise exception 'Failed save lost ingredients'; end if;
  payload:=payload||jsonb_build_object('image_url','https://example.com/rice.jpg','steps',jsonb_build_array('Koche {{ingredient:rice_link}} 15 Minuten.'),'ingredients',jsonb_build_array(jsonb_build_object('name','SQL test ingredient','quantity',150,'unit','g','step_key','rice_link')));
  perform public.admin_save_recipe(payload);
  if not exists(select 1 from public.recipes where id=rid and image_url='https://example.com/rice.jpg' and steps[1]='Koche {{ingredient:rice_link}} 15 Minuten.') then raise exception 'Image or step link lost'; end if;
  blocked:=false;
  begin
    perform public.admin_save_recipe(payload||jsonb_build_object('steps',jsonb_build_array('{{ingredient:missing}}')));
  exception when raise_exception then blocked:=true; end;
  if not blocked then raise exception 'Missing ingredient link accepted'; end if;
  execute 'reset role'; execute 'set local role anon';
  select count(*) into n from public.recipes where id=rid;
  if n<>1 then raise exception 'Published recipe invisible'; end if;
  execute 'reset role'; execute 'set local role authenticated';
  perform public.admin_set_recipe_deleted(rid,true);
  execute 'reset role'; execute 'set local role anon';
  select count(*) into n from public.recipes where id=rid;
  if n<>0 then raise exception 'Deleted recipe visible'; end if;
  execute 'reset role'; execute 'set local role authenticated';
  perform public.admin_set_recipe_deleted(rid,false);
  execute 'reset role'; execute 'set local role anon';
  select count(*) into n from public.recipes where id=rid;
  if n<>1 then raise exception 'Restored recipe invisible'; end if;
  execute 'reset role';
end $$;
rollback;
select 'PASS: admin CRUD, atomic save, restore, private plans, no self-promotion; test data rolled back' as admin_security_test;
