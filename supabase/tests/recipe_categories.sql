begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); rid text; hidden text; payload jsonb; blocked boolean; n bigint;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (a,'category-a-'||a||'@example.com','{"first_name":"Test","last_name":"Admin"}'),
    (b,'category-b-'||b||'@example.com','{"first_name":"Test","last_name":"User"}');
  insert into public.recipe_admins(user_id) values(a);
  payload := '{"name":"Category test","minutes":20,"servings":2,"steps":["Kochen"],"is_published":true,"categories":["vegetarian","main"],"ingredients":[{"name":"Testreis","quantity":100,"unit":"g"}]}';
  perform set_config('request.jwt.claim.sub',a::text,true);
  execute 'set local role authenticated';
  rid:=public.admin_save_recipe(payload);
  if not (select categories @> array['vegetarian','main'] from public.recipes where id=rid) then raise exception 'Categories not saved'; end if;
  payload:=payload||jsonb_build_object('id',rid,'categories',jsonb_build_array('fish','main'));
  perform public.admin_save_recipe(payload);
  if not (select categories @> array['fish','main'] from public.recipes where id=rid) then raise exception 'Categories not edited'; end if;
  blocked:=false;
  begin perform public.admin_save_recipe(payload||'{"name":"Should roll back","categories":["invalid"]}');
  exception when check_violation then blocked:=true; end;
  if not blocked or (select name from public.recipes where id=rid)<>'Category test' then raise exception 'Invalid categories not atomic'; end if;
  blocked:=false;
  begin perform public.admin_save_recipe(payload||'{"categories":["fish","vegan"]}');
  exception when check_violation then blocked:=true; end;
  if not blocked then raise exception 'Contradictory categories accepted'; end if;
  hidden:=public.admin_save_recipe(payload||jsonb_build_object('id',null,'is_published',false));
  perform public.save_user_preferences(jsonb_build_object('favoriteRecipes',jsonb_build_array(rid,hidden)),0,a);
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.save_user_preferences(jsonb_build_object('favoriteRecipes',jsonb_build_array(rid,hidden)),0,b);
  blocked:=false;
  begin perform public.admin_save_recipe(payload); exception when insufficient_privilege then blocked:=true; end;
  if not blocked then raise exception 'Non-admin saved categories'; end if;
  blocked:=false;
  begin perform public.admin_save_recipe_without_categories(payload); exception when insufficient_privilege then blocked:=true; end;
  if not blocked then raise exception 'Old function bypass'; end if;
  execute 'reset role'; execute 'set local role anon';
  select favorite_count into n from public.recipe_popularity() where recipe_id=rid;
  if n<>2 then raise exception 'Popularity count incorrect'; end if;
  if exists(select 1 from public.recipe_popularity() where recipe_id=hidden) then raise exception 'Draft exposed'; end if;
  execute 'reset role';
end $$;
rollback;
