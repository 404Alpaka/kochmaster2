begin;
-- Replace only the allowed-values check; retain the dietary conflict check.
do $$
declare rule record;
begin
  for rule in select conname from pg_constraint
    where conrelid = 'public.recipes'::regclass and contype = 'c'
      and position('categories <@' in pg_get_constraintdef(oid)) > 0
  loop
    execute format('alter table public.recipes drop constraint %I', rule.conname);
  end loop;
end $$;
alter table public.recipes add constraint recipes_categories_allowed_check
check (categories <@ array[
  'meat','fish','vegetarian','vegan','starter','main','soup','salad','dessert','breakfast','snack',
  'stew','casserole','baking','pasta','rice','potato','bread','cake','grilling','sauce'
]::text[]);
notify pgrst, 'reload schema';
commit;
