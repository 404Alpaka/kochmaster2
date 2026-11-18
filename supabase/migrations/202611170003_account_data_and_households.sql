begin;
create table public.user_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 data jsonb not null default '{}'::jsonb check(jsonb_typeof(data)='object'),
 revision bigint not null default 0,
 updated_at timestamptz not null default now()
);
create table public.households (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 1 and 80),
 created_at timestamptz not null default now()
);
create table public.household_members (
 household_id uuid not null references public.households(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in ('admin','editor','viewer')),
 primary key(household_id,user_id)
);
create index household_members_user on public.household_members(user_id);
create table public.household_invitations (
 id uuid primary key default gen_random_uuid(),
 household_id uuid not null references public.households(id) on delete cascade,
 email text not null check(length(email) between 3 and 320),
 role text not null check(role in ('editor','viewer')),
 token_hash text not null unique,
 expires_at timestamptz not null default now()+interval '7 days',
 accepted_at timestamptz,
 revoked_at timestamptz
);
create table public.household_state (
 household_id uuid primary key references public.households(id) on delete cascade,
 data jsonb not null default '{}'::jsonb check(jsonb_typeof(data)='object'),
 revision bigint not null default 0,
 updated_at timestamptz not null default now()
);
create table public.household_week_plans (
 household_id uuid not null references public.households(id) on delete cascade,
 week_start date not null check(extract(isodow from week_start)=1),
 meals jsonb not null default '[]'::jsonb check(jsonb_typeof(meals)='array'),
 checked jsonb not null default '[]'::jsonb check(jsonb_typeof(checked)='array'),
 revision bigint not null default 0,
 primary key(household_id,week_start)
);

create function public.household_role(p_household uuid) returns text
language sql stable security definer set search_path='' as $$
 select role from public.household_members where household_id=p_household and user_id=(select auth.uid());
$$;
revoke all on function public.household_role(uuid) from public,anon;
grant execute on function public.household_role(uuid) to authenticated;

alter table public.user_preferences enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invitations enable row level security;
alter table public.household_state enable row level security;
alter table public.household_week_plans enable row level security;
revoke all on public.user_preferences,public.households,public.household_members,public.household_invitations,public.household_state,public.household_week_plans from public,anon,authenticated;
grant select on public.user_preferences,public.households,public.household_members,public.household_invitations,public.household_state,public.household_week_plans to authenticated;
create policy own_preferences on public.user_preferences for select to authenticated using(user_id=(select auth.uid()));
create policy member_households on public.households for select to authenticated using(public.household_role(id) is not null);
create policy member_members on public.household_members for select to authenticated using(public.household_role(household_id) is not null);
create policy admin_invitations on public.household_invitations for select to authenticated using(public.household_role(household_id)='admin');
create policy member_state on public.household_state for select to authenticated using(public.household_role(household_id) is not null);
create policy member_weeks on public.household_week_plans for select to authenticated using(public.household_role(household_id) is not null);

create function public.save_user_preferences(p_data jsonb,p_revision bigint,p_user uuid) returns bigint
language plpgsql security definer set search_path='' as $$
declare next_revision bigint;
begin
 if auth.uid() is null or p_user is distinct from auth.uid() then raise exception 'Matching account required' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Invalid preferences'; end if;
 insert into public.user_preferences(user_id) values(auth.uid()) on conflict do nothing;
 update public.user_preferences set data=p_data,revision=revision+1,updated_at=now()
 where user_id=auth.uid() and revision=p_revision returning revision into next_revision;
 if not found then raise exception 'Preferences changed on another device' using errcode='40001'; end if;
 return next_revision;
end $$;

create function public.create_household(p_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare hid uuid;
begin
 if auth.uid() is null then raise exception 'Login required' using errcode='42501'; end if;
 insert into public.households(name) values(btrim(p_name)) returning id into hid;
 insert into public.household_members values(hid,auth.uid(),'admin');
 insert into public.household_state(household_id) values(hid);
 return hid;
end $$;

create function public.household_dashboard() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'role',mine.role,
 'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'email',u.email,'role',m.role) order by u.email),'[]'::jsonb)
 from public.household_members m join auth.users u on u.id=m.user_id where m.household_id=h.id),
 'invitations',case when mine.role='admin' then (select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'role',i.role,'expires_at',i.expires_at)),'[]'::jsonb)
 from public.household_invitations i where i.household_id=h.id and i.accepted_at is null and i.revoked_at is null and i.expires_at>now()) else '[]'::jsonb end) order by h.created_at),'[]'::jsonb)
 from public.households h join public.household_members mine on mine.household_id=h.id and mine.user_id=(select auth.uid());
$$;

create function public.invite_household(p_household uuid,p_email text,p_role text) returns text
language plpgsql security definer set search_path='' as $$
declare secret text := replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''); email_value text:=lower(btrim(p_email));
begin
 perform 1 from public.households where id=p_household for update;
 if public.household_role(p_household) is distinct from 'admin' then raise exception 'Admin required' using errcode='42501'; end if;
 if p_role is null or p_role not in ('editor','viewer') or email_value is null or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid invitation'; end if;
 update public.household_invitations set revoked_at=now() where household_id=p_household and email=email_value and accepted_at is null and revoked_at is null;
 insert into public.household_invitations(household_id,email,role,token_hash) values(p_household,email_value,p_role,encode(sha256(convert_to(secret,'UTF8')),'hex'));
 return secret;
end $$;

create function public.accept_household_invitation(p_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare invitation public.household_invitations; hid uuid; account_email text;
begin
 if auth.uid() is null then raise exception 'Login required' using errcode='42501'; end if;
 select email into account_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 select household_id into hid from public.household_invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
 perform 1 from public.households where id=hid for update;
 select * into invitation from public.household_invitations where household_id=hid and token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
 if not found or invitation.accepted_at is not null or invitation.revoked_at is not null or invitation.expires_at<=now() or account_email is null or lower(account_email)<>invitation.email then raise exception 'Invitation invalid, expired or addressed to another account' using errcode='42501'; end if;
 insert into public.household_members values(invitation.household_id,auth.uid(),invitation.role) on conflict do nothing;
 update public.household_invitations set accepted_at=now() where id=invitation.id;
 return invitation.household_id;
end $$;

create function public.revoke_household_invitation(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare hid uuid;
begin
 select household_id into hid from public.household_invitations where id=p_id;
 perform 1 from public.households where id=hid for update;
 if public.household_role(hid) is distinct from 'admin' then raise exception 'Admin required' using errcode='42501'; end if;
 update public.household_invitations set revoked_at=now() where id=p_id;
end $$;

create function public.change_household_role(p_household uuid,p_user uuid,p_role text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for update;
 if public.household_role(p_household) is distinct from 'admin' then raise exception 'Admin required' using errcode='42501'; end if;
 if p_role is null or p_role not in ('admin','editor','viewer') then raise exception 'Invalid role'; end if;
 if exists(select 1 from public.household_members where household_id=p_household and user_id=p_user and role='admin')
 and p_role<>'admin' and (select count(*) from public.household_members where household_id=p_household and role='admin')<=1 then raise exception 'Last admin cannot be demoted'; end if;
 update public.household_members set role=p_role where household_id=p_household and user_id=p_user;
 if not found then raise exception 'Member not found'; end if;
end $$;

create function public.leave_household(p_household uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for update;
 if public.household_role(p_household) is null then raise exception 'Member required' using errcode='42501'; end if;
 if public.household_role(p_household)='admin' and (select count(*) from public.household_members where household_id=p_household and role='admin')<=1 then raise exception 'Transfer administration first'; end if;
 delete from public.household_members where household_id=p_household and user_id=auth.uid();
end $$;

create function public.save_household_state(p_household uuid,p_data jsonb,p_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare next_revision bigint;
begin
 perform 1 from public.households where id=p_household for update;
 if coalesce(public.household_role(p_household),'') not in ('admin','editor') then raise exception 'Editing role required' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Invalid state'; end if;
 if exists(select 1 from jsonb_object_keys(p_data) as k where k not in ('pantry','preparedMeals','planBudget','planBudgetInitialized','budget','servings','preferences','survey','weeklyExpenses','weeklyReviews','nextWeekHints','cookingHistory','cookedEntries')) then raise exception 'Private data cannot be shared'; end if;
 update public.household_state set data=p_data,revision=revision+1,updated_at=now() where household_id=p_household and revision=p_revision returning revision into next_revision;
 if not found then raise exception 'Household changed on another device' using errcode='40001'; end if;
 return next_revision;
end $$;

create function public.save_household_week(p_household uuid,p_week date,p_meals jsonb,p_checked jsonb,p_revision bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare next_revision bigint;
begin
 perform 1 from public.households where id=p_household for update;
 if coalesce(public.household_role(p_household),'') not in ('admin','editor') then raise exception 'Editing role required' using errcode='42501'; end if;
 insert into public.household_week_plans(household_id,week_start) values(p_household,p_week) on conflict do nothing;
 update public.household_week_plans set meals=p_meals,checked=p_checked,revision=revision+1 where household_id=p_household and week_start=p_week and revision=p_revision returning revision into next_revision;
 if not found then raise exception 'Week changed on another device' using errcode='40001'; end if;
 return next_revision;
end $$;

revoke all on function public.save_user_preferences(jsonb,bigint,uuid),public.create_household(text),public.household_dashboard(),public.invite_household(uuid,text,text),public.accept_household_invitation(text),public.revoke_household_invitation(uuid),public.change_household_role(uuid,uuid,text),public.leave_household(uuid),public.save_household_state(uuid,jsonb,bigint),public.save_household_week(uuid,date,jsonb,jsonb,bigint) from public,anon;
grant execute on function public.save_user_preferences(jsonb,bigint,uuid),public.create_household(text),public.household_dashboard(),public.invite_household(uuid,text,text),public.accept_household_invitation(text),public.revoke_household_invitation(uuid),public.change_household_role(uuid,uuid,text),public.leave_household(uuid),public.save_household_state(uuid,jsonb,bigint),public.save_household_week(uuid,date,jsonb,jsonb,bigint) to authenticated;
commit;
