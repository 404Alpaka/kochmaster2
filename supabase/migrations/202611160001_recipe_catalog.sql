begin;
create table public.ingredients (
  id text primary key,
  name text not null check (length(trim(name)) > 0)
);
create table public.recipes (
  id text primary key,
  name text not null check (length(trim(name)) > 0),
  prep_minutes integer not null check (prep_minutes > 0),
  servings integer not null check (servings > 0),
  steps text[] not null check (cardinality(steps) > 0),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.recipe_ingredients (
  recipe_id text not null references public.recipes(id) on delete cascade,
  ingredient_id text not null references public.ingredients(id),
  quantity numeric not null check (quantity > 0),
  unit text not null check (unit in ('g','ml','Stück')),
  primary key (recipe_id, ingredient_id, unit)
);
create index recipe_ingredients_ingredient_idx on public.recipe_ingredients(ingredient_id);
alter table public.recipes enable row level security;
alter table public.ingredients enable row level security;
alter table public.recipe_ingredients enable row level security;
revoke all on public.recipes, public.ingredients, public.recipe_ingredients from anon, authenticated;
grant select on public.recipes, public.ingredients, public.recipe_ingredients to anon, authenticated;
create policy published_recipes on public.recipes for select to anon, authenticated
  using (is_published);
create policy published_recipe_ingredients on public.recipe_ingredients for select to anon, authenticated
  using (exists (select 1 from public.recipes r where r.id = recipe_id and r.is_published));
create policy published_ingredients on public.ingredients for select to anon, authenticated
  using (exists (select 1 from public.recipe_ingredients ri where ri.ingredient_id = ingredients.id));
commit;
