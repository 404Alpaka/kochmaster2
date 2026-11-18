// npm install --prefix build/sql-validation --no-package-lock @electric-sql/pglite
// node tool/test_account_households.mjs
import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;`);
  await db.exec(await readFile('supabase/migrations/202611170003_account_data_and_households.sql','utf8'));
  const result = await db.exec(await readFile('supabase/tests/account_households.sql','utf8'));
  console.log(result.at(-1).rows);
} finally { await db.close(); }
