import { readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite();
try {
  await db.exec(`create table public.recipes(id text primary key, categories text[] not null default '{}'
    check(categories <@ array['meat','fish','vegetarian','vegan','starter','main','soup','salad','dessert','breakfast','snack']::text[])
    check(not(categories && array['meat','fish']::text[] and categories && array['vegetarian','vegan']::text[])));
    insert into public.recipes values ('old','{salad,vegan}');`);
  const sql = await readFile('supabase/migrations/202611190004_more_recipe_categories.sql','utf8');
  await db.exec(sql); await db.exec(sql);
  for (const category of ['stew','casserole','baking','pasta','rice','potato','bread','cake','grilling','sauce']) {
    await db.query('insert into public.recipes values($1,$2)',[category,[category]]);
  }
  for (const tags of [['invalid'], ['meat','vegan'], ['fish','vegetarian']]) {
    await assert.rejects(db.query('insert into public.recipes values($1,$2)',['bad',tags]), e => e.code === '23514');
  }
  assert.deepEqual((await db.query("select categories from public.recipes where id='old'")).rows[0].categories,['salad','vegan']);
  console.log('PASS: 10 new categories, repeatability, existing categories and dietary conflict checks.');
} finally { await db.close(); }
