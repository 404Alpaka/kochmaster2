import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb,created_at timestamptz default now());
    create table storage.objects(id uuid primary key default gen_random_uuid(), owner uuid, owner_id text);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
    $$;
    grant usage on schema public,auth to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;
  `);
  for (const migration of [
    '202611160002_user_week_plans.sql',
    '202611170003_account_data_and_households.sql',
    '202611180001_private_week_plan_revisions.sql',
    '202611180002_customer_profiles.sql',
    '202611250001_account_data_management.sql',
  ]) {
    await db.exec(await readFile(`supabase/migrations/${migration}`, 'utf8'));
  }
  const result = await db.exec(await readFile('supabase/tests/account_data_management.sql', 'utf8'));
  console.log(result.find(r => r.rows?.[0]?.result)?.rows);
} catch (error) {
  console.error(error.message, error.code, error.where ?? '');
  process.exitCode = 1;
} finally {
  await db.close();
}
