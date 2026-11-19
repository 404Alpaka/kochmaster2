-- Editorial classification of the public catalog reviewed on 2026-11-19.
-- Only untouched names/ingredient sets are updated. Existing categories and
-- explicitly selected images are preserved. Planning verification is unchanged.
begin;
with curated(id,expected_name,expected_ingredients,categories,image_url) as (
values
('614d1ae0-abf3-4c47-8845-9167a9e7d1b1','Thunfischsalat',array['Fisch']::text[],array['fish','salad','main']::text[],null),
('example-01','Tomaten-Spinat-Pasta',array['Knoblauchzehe','Olivenöl','Nudeln','Spinat','Tomaten']::text[],array['vegetarian','main']::text[],'assets/images/pasta.jpg'),
('example-02','Brokkoli-Reis-Pfanne',array['Brokkoli','Olivenöl','Zwiebel','Reis','Tomaten']::text[],array['vegetarian','vegan','main']::text[],'assets/images/rice.jpg'),
('example-03','Rote-Linsen-Suppe',array['Karotten','Rote Linsen','Olivenöl','Zwiebel','Gemüsebrühe']::text[],array['vegetarian','vegan','soup','starter','main']::text[],null),
('example-04','Kartoffel-Spinat-Frittata',array['Ei','Milch','Olivenöl','Kartoffeln','Spinat']::text[],array['vegetarian','main']::text[],null),
('example-05','Kichererbsen-Curry',array['Kichererbsen, gekocht und abgetropft','Kokosmilch','Currypulver','Olivenöl','Reis','Tomaten']::text[],array['vegetarian','vegan','main']::text[],null),
('example-06','Couscous-Feta-Salat',array['Couscous','Gurke','Feta','Zitronensaft','Gemüsebrühe','Tomaten']::text[],array['vegetarian','salad','main']::text[],null),
('example-07','Bananen-Porridge',array['Banane','Zimt','Milch','Haferflocken']::text[],array['vegetarian','breakfast']::text[],null),
('example-08','Apfel-Joghurt-Müsli',array['Apfel','Honig','Haferflocken','Naturjoghurt']::text[],array['vegetarian','breakfast']::text[],null),
('example-09','Chili sin Carne',array['Kidneybohnen, gekocht und abgetropft','Mais, abgetropft','Currypulver','Olivenöl','Zwiebel','Passierte Tomaten','Paprika']::text[],array['vegetarian','vegan','main']::text[],null),
('example-10','Champignon-Rahm-Pasta',array['Sahne','Champignons','Olivenöl','Zwiebel','Nudeln']::text[],array['vegetarian','main']::text[],null),
('example-11','Ofenkartoffeln mit Knoblauchquark',array['Knoblauchzehe','Zitronensaft','Olivenöl','Kartoffeln','Magerquark','Naturjoghurt']::text[],array['vegetarian','main']::text[],null),
('example-12','Zucchini-Tomaten-Reis',array['Olivenöl','Zwiebel','Passierte Tomaten','Reis','Gemüsebrühe','Zucchini']::text[],array['vegetarian','vegan','main']::text[],null),
('example-13','Avocado-Ei-Brot',array['Avocado','Vollkornbrot','Ei','Zitronensaft']::text[],array['vegetarian','breakfast','snack']::text[],null),
('example-14','Tomaten-Mozzarella-Salat',array['Vollkornbrot','Zitronensaft','Mozzarella','Olivenöl','Tomaten']::text[],array['vegetarian','salad','starter']::text[],null),
('example-15','Tofu-Gemüse-Pfanne',array['Brokkoli','Karotten','Olivenöl','Reis','Sojasauce','Naturtofu']::text[],array['vegetarian','vegan','main']::text[],null),
('example-16','Erbsen-Risotto',array['Geriebener Gouda','Olivenöl','Zwiebel','Erbsen, tiefgekühlt','Reis','Gemüsebrühe']::text[],array['vegetarian','main']::text[],null),
('example-17','Gemüse-Bulgur',array['Bulgur','Olivenöl','Paprika','Gemüsebrühe','Tomaten','Zucchini']::text[],array['vegetarian','vegan','main']::text[],null),
('example-18','Herzhafte Gemüsepfannkuchen',array['Karotten','Ei','Weizenmehl','Milch','Olivenöl','Zucchini']::text[],array['vegetarian','main']::text[],null),
('example-19','Brokkoli-Kartoffel-Auflauf',array['Brokkoli','Geriebener Gouda','Sahne','Milch','Kartoffeln']::text[],array['vegetarian','main']::text[],null),
('example-20','Linsen-Bolognese',array['Karotten','Rote Linsen','Olivenöl','Zwiebel','Passierte Tomaten','Nudeln','Gemüsebrühe']::text[],array['vegetarian','main']::text[],null)
)
update public.recipes r set
  categories=case when cardinality(r.categories)=0 then c.categories else r.categories end,
  image_url=coalesce(r.image_url,c.image_url)
from curated c
where r.id=c.id and r.name=c.expected_name
  and array(select i.name from public.recipe_ingredients ri join public.ingredients i on i.id=ri.ingredient_id
    where ri.recipe_id=r.id order by i.name collate "C")
    = array(select value from unnest(c.expected_ingredients) e(value) order by value collate "C")
  and (cardinality(r.categories)=0 or (r.image_url is null and c.image_url is not null))
returning r.id,r.name,r.categories,r.image_url;
select count(*) filter(where cardinality(categories)>0) as kategorisierte_rezepte,
       count(*) filter(where image_url is not null) as rezepte_mit_bild,
       count(*) filter(where image_url is null) as rezepte_ohne_bild
from public.recipes where is_published and deleted_at is null;
commit;
