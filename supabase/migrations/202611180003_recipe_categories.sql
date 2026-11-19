begin;
alter table public.recipes add column categories text[] not null default '{}'
  check (categories <@ array['meat','fish','vegetarian','vegan','starter','main','soup','salad','dessert','breakfast','snack']::text[])
  check (not (categories && array['meat','fish']::text[] and categories && array['vegetarian','vegan']::text[]));

alter function public.admin_save_recipe(jsonb) rename to admin_save_recipe_without_categories;
revoke all on function public.admin_save_recipe_without_categories(jsonb) from public, anon, authenticated;
create function public.admin_save_recipe(p_recipe jsonb) returns text
language plpgsql security definer set search_path='' as $$
declare rid text; tags text[];
begin
  if not public.is_recipe_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  if p_recipe ? 'categories' then
    if jsonb_typeof(p_recipe->'categories') is distinct from 'array' then raise exception 'Invalid categories'; end if;
    if exists(select 1 from jsonb_array_elements(p_recipe->'categories') v where jsonb_typeof(v)<>'string') then raise exception 'Invalid categories'; end if;
    tags := array(select distinct jsonb_array_elements_text(p_recipe->'categories'));
  end if;
  rid := public.admin_save_recipe_without_categories(p_recipe);
  if tags is not null then update public.recipes set categories=tags where id=rid; end if;
  return rid;
end $$;
revoke all on function public.admin_save_recipe(jsonb) from public, anon;
grant execute on function public.admin_save_recipe(jsonb) to authenticated;

-- Only aggregate counts of public recipes, never account IDs or private lists.
create function public.recipe_popularity() returns table(recipe_id text, favorite_count bigint)
language sql stable security definer set search_path='' as $$
  select r.id, count(p.user_id) from public.recipes r
  left join public.user_preferences p on (p.data->'favoriteRecipes') ? r.id
  where r.is_published and r.deleted_at is null
  group by r.id;
$$;
revoke all on function public.recipe_popularity() from public;
grant execute on function public.recipe_popularity() to anon, authenticated;
notify pgrst, 'reload schema';
commit;
