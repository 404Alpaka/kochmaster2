begin;
-- Shared declarations are opt-in household data. Personal ratings, notes and
-- personal restrictions remain outside the accepted document keys.
create or replace function public.save_household_state(p_household uuid,p_data jsonb,p_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare next_revision bigint; old_data jsonb; preserved jsonb; row_value jsonb;
begin
  perform 1 from public.households where id=p_household for update;
  if coalesce(public.household_role(p_household),'') not in ('admin','editor') then raise exception 'Editing role required' using errcode='42501'; end if;
  if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Invalid state'; end if;
  if exists(select 1 from jsonb_object_keys(p_data) as k where k not in (
    'pantry','preparedMeals','planBudget','planBudgetInitialized','budget','servings','preferences','survey',
    'weeklyExpenses','weeklyReviews','nextWeekHints','cookingHistory','cookedEntries',
    'householdDinerRules','recipeCostEstimates','budgetCostClass','usePlanningStock'
  )) then raise exception 'Private data cannot be shared'; end if;
  if p_data ? 'householdDinerRules' then
    if jsonb_typeof(p_data->'householdDinerRules') is distinct from 'object' then raise exception 'Invalid diner declarations'; end if;
    for row_value in select value from jsonb_each(p_data->'householdDinerRules') loop
      if jsonb_typeof(row_value) is distinct from 'object'
        or jsonb_typeof(row_value->'name') is distinct from 'string'
        or jsonb_typeof(row_value->'participates') is distinct from 'boolean'
        or jsonb_typeof(row_value->'confirmed') is distinct from 'boolean'
        or coalesce(row_value->>'diet','') not in ('Ohne Einschränkung','Vegetarisch','Vegan')
        or jsonb_typeof(row_value->'exclusions') is distinct from 'array'
      then raise exception 'Invalid diner declarations'; end if;
      if exists(select 1 from jsonb_array_elements(row_value->'exclusions') v where jsonb_typeof(v)<>'string') then raise exception 'Invalid diner exclusions'; end if;
    end loop;
  end if;
  if p_data ? 'recipeCostEstimates' then
    if jsonb_typeof(p_data->'recipeCostEstimates') is distinct from 'object' then raise exception 'Invalid cost estimates'; end if;
    for row_value in select value from jsonb_each(p_data->'recipeCostEstimates') loop
      if jsonb_typeof(row_value) is distinct from 'number' then raise exception 'Invalid cost estimates'; end if;
      if (row_value#>>'{}')::numeric < 0 then raise exception 'Invalid cost estimates'; end if;
    end loop;
  end if;
  if p_data ? 'budgetCostClass' and p_data->'budgetCostClass'<>'null'::jsonb and coalesce(p_data->>'budgetCostClass','') not in ('low','medium','high') then raise exception 'Invalid budget cost class'; end if;
  if p_data ? 'usePlanningStock' and jsonb_typeof(p_data->'usePlanningStock') is distinct from 'boolean' then raise exception 'Invalid stock preference'; end if;
  select data into old_data from public.household_state where household_id=p_household and revision=p_revision;
  if not found then raise exception 'Household changed on another device' using errcode='40001'; end if;
  -- Older clients must not erase declarations they cannot display yet.
  select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into preserved from jsonb_each(old_data)
    where key in ('householdDinerRules','recipeCostEstimates','budgetCostClass','usePlanningStock');
  update public.household_state set data=preserved || p_data,revision=revision+1,updated_at=now()
    where household_id=p_household and revision=p_revision returning revision into next_revision;
  if not found then raise exception 'Household changed on another device' using errcode='40001'; end if;
  return next_revision;
end $$;
revoke all on function public.save_household_state(uuid,jsonb,bigint) from public,anon;
grant execute on function public.save_household_state(uuid,jsonb,bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
