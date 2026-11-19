import { readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create role authenticated; create role anon;
    create schema storage; create schema auth;
    create table public.recipe_admins(user_id uuid primary key);
    insert into public.recipe_admins values ('00000000-0000-0000-0000-000000000001');
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
    create function public.is_recipe_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.recipe_admins where user_id=auth.uid())$$;
    create function storage.foldername(text) returns text[] language sql immutable as $$select string_to_array($1,'/')$$;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant usage on schema storage,auth to authenticated,anon;
    grant insert on storage.objects to authenticated,anon;`);
  const sql = await readFile('supabase/migrations/202611190003_recipe_photo_uploads.sql','utf8');
  await db.exec(sql); await db.exec(sql);
  const { rows: [bucket] } = await db.query(`select * from storage.buckets where id='recipe-images'`);
  assert.equal(bucket.public,true);
  assert.equal(Number(bucket.file_size_limit),8388608);
  assert.deepEqual(bucket.allowed_mime_types,['image/jpeg','image/png','image/webp']);
  async function insert(role, uid, path, succeeds) {
    await db.exec(`set role ${role}`);
    await db.query(`select set_config('test.uid',$1,false)`, [uid]);
    try {
      await db.query(`insert into storage.objects values ('recipe-images',$1)`,[path]);
      assert.equal(succeeds,true, 'Unauthorized upload succeeded');
    } catch (error) {
      if (succeeds || error.code !== '42501') throw error;
    } finally { await db.exec('reset role'); }
  }
  const admin='00000000-0000-0000-0000-000000000001';
  const other='00000000-0000-0000-0000-000000000002';
  await insert('authenticated',admin,`${admin}/photo.jpg`,true);
  await insert('authenticated',admin,`${other}/photo.jpg`,false);
  await insert('authenticated',other,`${other}/photo.jpg`,false);
  await insert('anon','',`${admin}/photo.jpg`,false);
  console.log('PASS: repeatable bucket setup, admin upload, foreign folders and non-admin uploads blocked.');
} finally { await db.close(); }
