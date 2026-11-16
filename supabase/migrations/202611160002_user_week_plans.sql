begin;
create table public.user_week_plans (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null check (extract(isodow from week_start) = 1),
  meals jsonb not null default '[]'::jsonb check(jsonb_typeof(meals) = 'array'),
  checked jsonb not null default '[]'::jsonb check(jsonb_typeof(checked) = 'array'),
  primary key(user_id,week_start)
);
alter table public.user_week_plans enable row level security;
revoke all on public.user_week_plans from anon, authenticated;
grant select, insert, update on public.user_week_plans to authenticated;
create policy own_week_select on public.user_week_plans for select to authenticated using ((select auth.uid()) = user_id);
create policy own_week_insert on public.user_week_plans for insert to authenticated with check ((select auth.uid()) = user_id);
create policy own_week_update on public.user_week_plans for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
commit;
