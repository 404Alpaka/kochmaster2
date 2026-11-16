begin;
create table public.recipe_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.recipe_admins enable row level security;
revoke all on public.recipe_admins from public, anon, authenticated;

create function public.is_recipe_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.recipe_admins a where a.user_id = (select auth.uid()));
$$;
revoke all on function public.is_recipe_admin() from public, anon;
grant execute on function public.is_recipe_admin() to authenticated;

alter table public.recipes add column deleted_at timestamptz;
drop policy published_recipes on public.recipes;
create policy published_recipes on public.recipes for select to anon, authenticated
  using (is_published and deleted_at is null);
create policy admin_recipe_read on public.recipes for select to authenticated using ((select public.is_recipe_admin()));
create policy admin_ingredient_read on public.ingredients for select to authenticated using ((select public.is_recipe_admin()));
create policy admin_recipe_ingredient_read on public.recipe_ingredients for select to authenticated using ((select public.is_recipe_admin()));

-- Snapshot existing plans before recipes can be edited or moved to the bin.
-- This private helper has no Data API execute permission.
create function public.recipe_plan_snapshot(p_id text) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id',r.id,'name',r.name,'minutes',r.prep_minutes,
    'servings',r.servings,'steps',to_jsonb(r.steps),'ingredients',
    coalesce((select jsonb_agg(jsonb_build_object('ingredient_id',ri.ingredient_id,
      'name',i.name,'quantity',ri.quantity,'unit',ri.unit) order by ri.ingredient_id)
      from public.recipe_ingredients ri join public.ingredients i on i.id=ri.ingredient_id
      where ri.recipe_id=r.id),'[]'::jsonb))
  from public.recipes r where r.id=p_id;
$$;
revoke all on function public.recipe_plan_snapshot(text) from public, anon, authenticated;
update public.user_week_plans wp set meals = (
  select coalesce(jsonb_agg(case when m.entry ? 'recipe' then m.entry
    when public.recipe_plan_snapshot(m.entry->>'recipe_id') is null then m.entry
    else m.entry || jsonb_build_object('recipe',public.recipe_plan_snapshot(m.entry->>'recipe_id')) end
    order by m.position),'[]'::jsonb)
  from jsonb_array_elements(wp.meals) with ordinality as m(entry,position)
);

create function public.admin_save_recipe(p_recipe jsonb) returns text
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
    insert into public.recipe_ingredients(recipe_id,ingredient_id,quantity,unit)
      values(rid,iid,amount,unit_name);
  end loop;
  return rid;
end $$;
revoke all on function public.admin_save_recipe(jsonb) from public, anon;
grant execute on function public.admin_save_recipe(jsonb) to authenticated;

create function public.admin_set_recipe_deleted(p_recipe_id text,p_deleted boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_recipe_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
  if p_deleted is null then raise exception 'Deleted state required'; end if;
  update public.recipes set deleted_at=case when p_deleted then now() else null end where id=p_recipe_id;
  if not found then raise exception 'Recipe not found'; end if;
end $$;
revoke all on function public.admin_set_recipe_deleted(text,boolean) from public, anon;
grant execute on function public.admin_set_recipe_deleted(text,boolean) to authenticated;
commit;
