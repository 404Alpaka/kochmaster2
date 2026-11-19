import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;
    insert into auth.users(id,email) values('11111111-1111-4111-8111-111111111111','legacy@example.com');`);
  await db.exec(await readFile('supabase/migrations/202611180002_customer_profiles.sql', 'utf8'));
  const legacy = await db.query('select customer_number,first_name,last_name from public.customer_profiles');
  if (legacy.rows.length !== 1 || legacy.rows[0].first_name !== null || legacy.rows[0].last_name !== null) throw new Error('Legacy backfill failed');
  await db.exec(await readFile('supabase/tests/customer_profiles.sql', 'utf8'));
  console.log('Customer profiles: backfill, signup, uniqueness and permissions passed.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally { await db.close(); }
