begin;

create table public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  customer_number bigint generated always as identity (start with 100000) unique not null,
  first_name text check (first_name is null or length(btrim(first_name)) between 1 and 100),
  last_name text check (last_name is null or length(btrim(last_name)) between 1 and 100),
  created_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;
revoke all on public.customer_profiles from public, anon, authenticated;
revoke all on sequence public.customer_profiles_customer_number_seq from public, anon, authenticated;
grant select on public.customer_profiles to authenticated;
create policy own_customer_profile on public.customer_profiles for select
  to authenticated using (user_id = (select auth.uid()));

-- Existing accounts keep working; unknown names remain NULL rather than invented.
insert into public.customer_profiles(user_id, first_name, last_name)
select id,
  case when jsonb_typeof(raw_user_meta_data->'first_name') = 'string'
    and length(btrim(raw_user_meta_data->>'first_name')) between 1 and 100
    then btrim(raw_user_meta_data->>'first_name') end,
  case when jsonb_typeof(raw_user_meta_data->'last_name') = 'string'
    and length(btrim(raw_user_meta_data->>'last_name')) between 1 and 100
    then btrim(raw_user_meta_data->>'last_name') end
from auth.users order by created_at, id;

create function public.create_customer_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare given_name text := btrim(new.raw_user_meta_data->>'first_name');
        family_name text := btrim(new.raw_user_meta_data->>'last_name');
begin
  if jsonb_typeof(new.raw_user_meta_data->'first_name') is distinct from 'string'
    or jsonb_typeof(new.raw_user_meta_data->'last_name') is distinct from 'string'
    or given_name is null or family_name is null
    or given_name !~ '[^[:space:]]' or family_name !~ '[^[:space:]]'
    or length(given_name) not between 1 and 100
    or length(family_name) not between 1 and 100 then
    raise exception 'First and last name required (1-100 characters)' using errcode = '23514';
  end if;
  insert into public.customer_profiles(user_id, first_name, last_name)
    values(new.id, given_name, family_name);
  return new;
end $$;
revoke all on function public.create_customer_profile() from public, anon, authenticated;
create trigger create_customer_profile_after_signup
  after insert on auth.users for each row execute function public.create_customer_profile();

commit;
