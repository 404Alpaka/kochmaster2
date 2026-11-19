import { readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const data=JSON.parse(await readFile('supabase/data/planning_metadata_curation_20261119.json','utf8'));
const sql=await readFile('supabase/migrations/202611190007_curate_planning_metadata.sql','utf8');
const db=new PGlite();
try {
  await db.exec(`create table public.ingredients(id text primary key,name text not null);
    create table public.recipes(id text primary key,name text,prep_minutes integer,servings integer,steps text[],is_published boolean default true,deleted_at timestamptz,
      primary_side text,dish_type text,main_ingredient text,preparation_method text,flavors text[] default '{}',active_minutes integer,cost_class text,verified_allergens text[],verified_diets text[]);
    create table public.recipe_ingredients(recipe_id text,ingredient_id text,quantity numeric,unit text);`);
  for(const r of data.reviewed) {
    await db.query('insert into public.recipes(id,name,prep_minutes,servings,steps) values($1,$2,$3,$4,$5)',[r.id,r.expected_name,r.expected_minutes,r.expected_servings,r.expected_steps]);
    for(const i of r.expected_ingredients) {
      await db.query('insert into public.ingredients values($1,$2) on conflict do nothing',[i.id,i.name]);
      await db.query('insert into public.recipe_ingredients values($1,$2,$3,$4)',[r.id,i.id,i.quantity,i.unit]);
    }
  }
  await db.query("update public.recipes set primary_side='custom-side',flavors='{custom-flavor}',verified_allergens='{Milch}',verified_diets='{Vegetarisch}',active_minutes=10,cost_class='high' where id='example-01'");
  const untouched=(await db.query('select id,name,prep_minutes,servings,steps,verified_allergens,verified_diets,active_minutes,cost_class from public.recipes order by id')).rows;
  const result=await db.exec(sql);
  assert.equal(result.flatMap(r=>r.rows).length,20);
  const updated=(await db.query('select * from public.recipes order by id')).rows;
  assert.equal(updated.filter(r=>r.primary_side && r.dish_type && r.preparation_method).length,20);
  assert.equal(updated.filter(r=>r.main_ingredient).length,18);
  assert.equal(updated[0].primary_side,'custom-side');
  assert.deepEqual(updated[0].flavors,['custom-flavor']);
  assert.deepEqual((await db.query('select id,name,prep_minutes,servings,steps,verified_allergens,verified_diets,active_minutes,cost_class from public.recipes order by id')).rows,untouched);
  assert.equal((await db.exec(sql)).flatMap(r=>r.rows).length,0,'Repeated execution must not rewrite rows');
  await db.query("update public.recipes set primary_side=null,name='Changed name' where id='example-02'");
  await db.query("update public.recipes set primary_side=null,steps='{Changed step}' where id='example-03'");
  await db.query("update public.recipes set primary_side=null where id in ('example-04','example-05','example-06','example-07','example-08')");
  await db.query("update public.recipe_ingredients set quantity=quantity+1 where recipe_id='example-04'");
  await db.query("update public.ingredients set name='Changed ingredient' where id='chickpeas'");
  await db.query("update public.recipes set is_published=false where id='example-06'");
  await db.query("update public.recipes set deleted_at=now() where id='example-07'");
  await db.query("update public.recipes set servings=servings+1 where id='example-08'");
  assert.equal((await db.exec(sql)).flatMap(r=>r.rows).length,0,'Changed or unpublished recipes must be skipped');
  console.log('PASS: 20 recipe classifications, 18 grounded main ingredients, preservation of existing values, no safety certifications, repeatability and stale-source guards.');
} catch(error) { console.error(error.message);process.exitCode=1; }
finally {await db.close();}
