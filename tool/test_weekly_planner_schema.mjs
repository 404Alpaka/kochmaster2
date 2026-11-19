import { readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb,created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;`);
  for(const file of ['202611160001_recipe_catalog.sql','202611160002_user_week_plans.sql','202611160003_recipe_admin.sql','202611170001_recipe_planning_metadata.sql','202611170002_recipe_images_and_step_links.sql','202611170003_account_data_and_households.sql','202611180002_customer_profiles.sql','202611180003_recipe_categories.sql','202611190004_more_recipe_categories.sql','202611190005_weekly_planner.sql','202611190006_planner_household_resources.sql']) {
    await db.exec(await readFile(`supabase/migrations/${file}`,'utf8'));
  }
  await db.exec(await readFile('supabase/tests/planner_household_resources.sql','utf8'));
  await db.exec(await readFile('supabase/tests/account_households.sql','utf8'));
  const {rows}=await db.query(`select column_name from information_schema.columns where table_schema='public' and table_name='recipes' and column_name in ('primary_side','dish_type','main_ingredient','active_minutes','preparation_method','flavors','cost_class')`);
  assert.equal(rows.length,7);
  console.log('PASS: planner schema, shared declarations, legacy clients, validation, conflicts and household permissions.');
} catch(error) { console.error(error.message); process.exitCode=1; }
finally {await db.close();}
