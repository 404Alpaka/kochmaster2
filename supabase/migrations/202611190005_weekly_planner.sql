begin;
alter table public.recipes
  add column if not exists primary_side text,
  add column if not exists dish_type text,
  add column if not exists main_ingredient text,
  add column if not exists active_minutes integer check (active_minutes >= 0),
  add column if not exists preparation_method text,
  add column if not exists flavors text[] not null default '{}',
  add column if not exists cost_class text;
comment on column public.recipes.primary_side is 'Primary side for weekly variety; none has no cap. Unknown stays null.';

alter function public.admin_save_recipe(jsonb) rename to admin_save_recipe_without_planner;
revoke all on function public.admin_save_recipe_without_planner(jsonb) from public, anon, authenticated;
create function public.admin_save_recipe(p_recipe jsonb) returns text
language plpgsql security definer set search_path='' as $$
declare rid text;
begin
  if not public.is_recipe_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  rid := public.admin_save_recipe_without_planner(p_recipe);
  update public.recipes set
    primary_side = case when p_recipe ? 'primary_side' then p_recipe->>'primary_side' else primary_side end,
    dish_type = case when p_recipe ? 'dish_type' then p_recipe->>'dish_type' else dish_type end,
    main_ingredient = case when p_recipe ? 'main_ingredient' then p_recipe->>'main_ingredient' else main_ingredient end,
    active_minutes = case when p_recipe ? 'active_minutes' then (p_recipe->>'active_minutes')::integer else active_minutes end,
    preparation_method = case when p_recipe ? 'preparation_method' then p_recipe->>'preparation_method' else preparation_method end,
    flavors = case when p_recipe ? 'flavors' then array(select jsonb_array_elements_text(p_recipe->'flavors')) else flavors end,
    cost_class = case when p_recipe ? 'cost_class' then p_recipe->>'cost_class' else cost_class end
  where id=rid;
  return rid;
end $$;
revoke all on function public.admin_save_recipe(jsonb) from public, anon;
grant execute on function public.admin_save_recipe(jsonb) to authenticated;
notify pgrst, 'reload schema';

commit;
