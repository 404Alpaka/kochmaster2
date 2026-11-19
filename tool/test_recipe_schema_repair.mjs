import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';

for (const withImages of [false, true]) {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated; create schema auth;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb,created_at timestamptz default now());
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema public,auth to anon,authenticated;
      grant execute on function auth.uid() to anon,authenticated;`);
    const files = ['202611160001_recipe_catalog.sql','202611160002_user_week_plans.sql',
      '202611160003_recipe_admin.sql','202611170001_recipe_planning_metadata.sql',
      ...(withImages ? ['202611170002_recipe_images_and_step_links.sql'] : []),
      '202611170003_account_data_and_households.sql','202611180003_recipe_categories.sql'];
    for (const file of files) await db.exec(await readFile(`supabase/migrations/${file}`, 'utf8'));
    const repair = await readFile('supabase/migrations/202611190001_repair_recipe_images.sql', 'utf8');
    await db.exec(repair);
    await db.exec(repair);
    for (const file of ['recipe_categories.sql', 'recipe_admin.sql']) {
      await db.exec(await readFile(`supabase/tests/${file}`, 'utf8'));
    }
    const columns = await db.query(`select table_name,column_name from information_schema.columns
      where table_schema='public' and (table_name='recipes' and column_name in ('image_url','categories')
      or table_name='recipe_ingredients' and column_name='step_key')`);
    if (columns.rows.length !== 3) throw new Error('Repaired schema incomplete');
    await db.exec(await readFile('supabase/seed.sql', 'utf8'));
    const seed = await db.query("select count(*)::int as count from public.recipes where id in ('pasta','rice') and image_url is not null and cardinality(categories)>0");
    if (seed.rows[0].count !== 2) throw new Error('Seed categories/images missing');
    console.log(`Recipe schema repair: existing images=${withImages}; repeated migration, categories and admin rights passed.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
  finally { await db.close(); }
}
