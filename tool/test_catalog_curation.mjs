import { readFile } from 'node:fs/promises';
import { PGlite } from '../build/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';
const catalog = JSON.parse(await readFile('supabase/data/catalog_curation_20261119.json', 'utf8'));
const migration = await readFile('supabase/migrations/202611190002_curate_recipe_catalog.sql', 'utf8');
for (const protectedEdits of [false, true]) {
  const db = new PGlite();
  try {
    await db.exec(`create table public.ingredients(id text primary key,name text);
      create table public.recipes(id text primary key,name text,categories text[] not null default '{}',image_url text,
      verified_allergens text[],verified_diets text[],is_published boolean default true,deleted_at timestamptz);
      create table public.recipe_ingredients(recipe_id text,ingredient_id text);`);
    let ingredientIndex = 0;
    for (const recipe of catalog) {
      await db.query('insert into public.recipes(id,name) values($1,$2)', [recipe.id, recipe.name]);
      for (const name of recipe.ingredients) {
        const id = `ingredient-${ingredientIndex++}`;
        await db.query('insert into public.ingredients values($1,$2)', [id, name]);
        await db.query('insert into public.recipe_ingredients values($1,$2)', [recipe.id, id]);
      }
    }
    if (protectedEdits) {
      await db.exec(`update public.recipes set categories='{snack}',image_url='https://example.com/muesli.jpg' where id='example-08';
        update public.recipes set name='Changed potatoes' where id='example-11';
        insert into public.ingredients values('changed','Changed ingredient');
        insert into public.recipe_ingredients values('example-12','changed');`);
    }
    await db.exec(migration);
    await db.exec(migration);
    const rows = (await db.query('select * from public.recipes order by id')).rows;
    const count = rows.filter(r => r.categories.length).length;
    if (count !== (protectedEdits ? 19 : 21)) throw new Error(`Wrong category count ${count}`);
    if (rows.some(r => r.verified_allergens !== null || r.verified_diets !== null)) throw new Error('Planning verification changed');
    if (rows.find(r => r.id === 'example-11').image_url !== null) throw new Error('Potatoes received a wrong image');
    if (rows.find(r => r.id === 'example-01').image_url !== 'assets/images/pasta.jpg') throw new Error('Pasta image missing');
    if (rows.find(r => r.id === 'example-02').image_url !== 'assets/images/rice.jpg') throw new Error('Rice image missing');
    if (protectedEdits) {
      const saved = rows.find(r => r.id === 'example-08');
      if (saved.categories.join() !== 'snack' || saved.image_url !== 'https://example.com/muesli.jpg') throw new Error('Manual choices overwritten');
    }
    console.log(`Catalog curation: ${count} categorized, protected edits=${protectedEdits}; repeatability and image checks passed.`);
  } catch (error) { console.error(error.message); process.exitCode = 1; }
  finally { await db.close(); }
}
