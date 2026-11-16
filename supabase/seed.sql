-- Development examples, not production recipe content.
begin;
insert into public.ingredients (id,name) values
 ('pasta','Nudeln'),('tomato','Tomaten'),('spinach','Spinat'),('rice','Reis'),('broccoli','Brokkoli')
on conflict (id) do nothing;
insert into public.recipes (id,name,prep_minutes,servings,steps,is_published) values
 ('pasta','Tomaten-Spinat-Pasta',20,2,array['Nudeln nach Packungsangabe kochen.','Tomaten klein schneiden und in einer Pfanne erhitzen.','Spinat zugeben und mit den Nudeln mischen.'],true),
 ('rice','Brokkoli-Reis-Pfanne',25,2,array['Reis nach Packungsangabe garen.','Brokkoli in Röschen teilen und garen.','Tomaten würfeln, erhitzen und mit Reis und Brokkoli vermengen.'],true)
on conflict (id) do nothing;
insert into public.recipe_ingredients (recipe_id,ingredient_id,quantity,unit) values
 ('pasta','pasta',200,'g'),('pasta','tomato',300,'g'),('pasta','spinach',150,'g'),
 ('rice','rice',150,'g'),('rice','broccoli',300,'g'),('rice','tomato',200,'g')
on conflict do nothing;
commit;
