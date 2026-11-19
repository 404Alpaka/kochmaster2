-- Repairs the older image migration after categories have already been installed.
-- Keeps the public category wrapper intact; can be safely repeated.
begin;
alter table public.recipes add column if not exists image_url text
  check (image_url is null or (length(image_url) <= 2048 and (image_url ~ '^https://[^[:space:]]+$' or image_url in ('assets/images/pasta.jpg','assets/images/rice.jpg'))));
alter table public.recipe_ingredients add column if not exists step_key text check (step_key is null or step_key ~ '^[a-zA-Z0-9_%.-]+$');
create unique index if not exists recipe_ingredient_step_key on public.recipe_ingredients(recipe_id,step_key) where step_key is not null;
create or replace function public.admin_save_recipe_without_categories(p_recipe jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare rid text; item jsonb; iid text; amount numeric; ingredient_name text; unit_name text; recipe_steps text[];
begin
  if not public.is_recipe_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  if jsonb_typeof(p_recipe) <> 'object' or length(btrim(coalesce(p_recipe->>'name',''))) not between 1 and 160
    or (p_recipe->>'minutes')::integer not between 1 and 1440
    or (p_recipe->>'servings')::integer not between 1 and 100
    or coalesce(jsonb_typeof(p_recipe->'steps'),'null') <> 'array'
    or coalesce(jsonb_typeof(p_recipe->'ingredients'),'null') <> 'array'
    then raise exception 'Invalid recipe'; end if;
  if jsonb_array_length(p_recipe->'ingredients') not between 1 and 100
    or jsonb_array_length(p_recipe->'steps') not between 1 and 100
    then raise exception 'Ingredients and steps required'; end if;
  if exists(select 1 from jsonb_array_elements(p_recipe->'steps') s
    where jsonb_typeof(s) <> 'string' or length(btrim(s#>>'{}')) not between 1 and 5000)
    then raise exception 'Invalid instructions'; end if;
  select array_agg(value order by ord) into recipe_steps
    from jsonb_array_elements_text(p_recipe->'steps') with ordinality as s(value,ord);
  if p_recipe ? 'verified_allergens' and p_recipe->'verified_allergens' <> 'null'::jsonb then
    if jsonb_typeof(p_recipe->'verified_allergens') <> 'array' then raise exception 'Invalid verified_allergens'; end if;
    if exists(select 1 from jsonb_array_elements(p_recipe->'verified_allergens') v
      where jsonb_typeof(v) <> 'string' or v#>>'{}' not in ('Milch','Eier','Erdnüsse','Schalenfrüchte','Gluten','Soja'))
      then raise exception 'Invalid verified_allergens'; end if;
  end if;
  if p_recipe ? 'verified_diets' and p_recipe->'verified_diets' <> 'null'::jsonb then
    if jsonb_typeof(p_recipe->'verified_diets') <> 'array' then raise exception 'Invalid verified_diets'; end if;
    if exists(select 1 from jsonb_array_elements(p_recipe->'verified_diets') v
      where jsonb_typeof(v) <> 'string' or v#>>'{}' not in ('Vegetarisch','Vegan'))
      then raise exception 'Invalid verified_diets'; end if;
  end if;
  rid := nullif(p_recipe->>'id','');
  if rid is null then
    rid := gen_random_uuid()::text;
    insert into public.recipes(id,name,prep_minutes,servings,steps,is_published)
      values(rid,btrim(p_recipe->>'name'),(p_recipe->>'minutes')::integer,
        (p_recipe->>'servings')::integer,recipe_steps,coalesce((p_recipe->>'is_published')::boolean,false));
  else
    perform 1 from public.recipes where id=rid and deleted_at is null for update;
    if not found then raise exception 'Recipe not found or deleted'; end if;
    update public.recipes set name=btrim(p_recipe->>'name'),prep_minutes=(p_recipe->>'minutes')::integer,
      servings=(p_recipe->>'servings')::integer,steps=recipe_steps,
      is_published=coalesce((p_recipe->>'is_published')::boolean,false) where id=rid;
    delete from public.recipe_ingredients where recipe_id=rid;
  end if;
  for item in select value from jsonb_array_elements(p_recipe->'ingredients') loop
    amount := (item->>'quantity')::numeric;
    unit_name := item->>'unit';
    if amount is null or amount <= 0 or amount > 1000000 or amount::text in ('NaN','Infinity','-Infinity')
      or unit_name is null or unit_name not in ('g','ml','Stück') then raise exception 'Invalid quantity or unit'; end if;
    iid := nullif(item->>'ingredient_id','');
    if iid is null then
      ingredient_name := btrim(coalesce(item->>'name',''));
      if length(ingredient_name) not between 1 and 120 then raise exception 'Ingredient name required'; end if;
      perform pg_advisory_xact_lock(hashtext(lower(ingredient_name)));
      select id into iid from public.ingredients where lower(btrim(name))=lower(ingredient_name) order by id limit 1;
      if iid is null then
        iid := gen_random_uuid()::text;
        insert into public.ingredients(id,name) values(iid,ingredient_name);
      end if;
    elsif not exists(select 1 from public.ingredients where id=iid) then
      raise exception 'Unknown ingredient';
    end if;
    insert into public.recipe_ingredients(recipe_id,ingredient_id,quantity,unit,step_key)
      values(rid,iid,amount,unit_name,nullif(item->>'step_key',''));
  end loop;
  update public.recipes set
    verified_allergens = case when jsonb_typeof(p_recipe->'verified_allergens') = 'array'
      then array(select jsonb_array_elements_text(p_recipe->'verified_allergens')) else null end,
    verified_diets = case when jsonb_typeof(p_recipe->'verified_diets') = 'array'
      then array(select jsonb_array_elements_text(p_recipe->'verified_diets')) else null end
    where id=rid;
  if exists (
    select 1 from regexp_matches(array_to_string(recipe_steps,E'\n'), '\{\{ingredient:([^}]+)\}\}', 'g') as token
    where not exists(select 1 from public.recipe_ingredients ri where ri.recipe_id=rid and ri.step_key=token[1])
  ) then raise exception 'Unknown ingredient link'; end if;
  update public.recipes set image_url=nullif(p_recipe->>'image_url','') where id=rid;
  return rid;
end $$;
revoke all on function public.admin_save_recipe_without_categories(jsonb) from public, anon, authenticated;



notify pgrst, 'reload schema';
commit;
