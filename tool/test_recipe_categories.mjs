import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb,created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;`);
  for (const file of ['202611160001_recipe_catalog.sql','202611160002_user_week_plans.sql','202611160003_recipe_admin.sql',
    '202611170001_recipe_planning_metadata.sql','202611170002_recipe_images_and_step_links.sql','202611170003_account_data_and_households.sql',
    '202611180003_recipe_categories.sql']) {
    await db.exec(await readFile(`supabase/migrations/${file}`, 'utf8'));
  }
  await db.exec(await readFile('supabase/tests/recipe_categories.sql', 'utf8'));
  console.log('Recipe categories: create/edit, rollback, permissions and aggregate popularity passed.');
} catch (error) { console.error(error.message); process.exitCode=1; }
finally { await db.close(); }
