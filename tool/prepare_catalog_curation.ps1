$ErrorActionPreference = 'Stop'
$migration = Join-Path $PSScriptRoot '../supabase/migrations/202611190002_curate_recipe_catalog.sql'
if (Test-Path -LiteralPath $migration) { throw 'Die vorbereitete Migration existiert bereits. Nicht automatisch überschreiben.' }
$config = Get-Content (Join-Path $PSScriptRoot '../lib/core/config/app_config.dart') -Raw
$values = [regex]::Matches($config, "defaultValue: '([^']+)'")
$url = $values[0].Groups[1].Value
$key = $values[1].Groups[1].Value
$rows = Invoke-RestMethod -Uri ($url + '/rest/v1/recipes?select=id,name,categories,image_url,recipe_ingredients(ingredients(name))&is_published=eq.true&deleted_at=is.null&order=id') -Headers @{apikey=$key} -TimeoutSec 20

# Editorial discovery tags, not verified allergen or dietary declarations.
$tags = @{
  'example-01' = @('Tomaten-Spinat-Pasta', 'vegetarian,main', 'assets/images/pasta.jpg')
  'example-02' = @('Brokkoli-Reis-Pfanne', 'vegetarian,vegan,main', 'assets/images/rice.jpg')
  'example-03' = @('Rote-Linsen-Suppe', 'vegetarian,vegan,soup,starter,main')
  'example-04' = @('Kartoffel-Spinat-Frittata', 'vegetarian,main')
  'example-05' = @('Kichererbsen-Curry', 'vegetarian,vegan,main')
  'example-06' = @('Couscous-Feta-Salat', 'vegetarian,salad,main')
  'example-07' = @('Bananen-Porridge', 'vegetarian,breakfast')
  'example-08' = @('Apfel-Joghurt-Müsli', 'vegetarian,breakfast')
  'example-09' = @('Chili sin Carne', 'vegetarian,vegan,main')
  'example-10' = @('Champignon-Rahm-Pasta', 'vegetarian,main')
  'example-11' = @('Ofenkartoffeln mit Knoblauchquark', 'vegetarian,main')
  'example-12' = @('Zucchini-Tomaten-Reis', 'vegetarian,vegan,main')
  'example-13' = @('Avocado-Ei-Brot', 'vegetarian,breakfast,snack')
  'example-14' = @('Tomaten-Mozzarella-Salat', 'vegetarian,salad,starter')
  'example-15' = @('Tofu-Gemüse-Pfanne', 'vegetarian,vegan,main')
  'example-16' = @('Erbsen-Risotto', 'vegetarian,main')
  'example-17' = @('Gemüse-Bulgur', 'vegetarian,vegan,main')
  'example-18' = @('Herzhafte Gemüsepfannkuchen', 'vegetarian,main')
  'example-19' = @('Brokkoli-Kartoffel-Auflauf', 'vegetarian,main')
  'example-20' = @('Linsen-Bolognese', 'vegetarian,main')
  '614d1ae0-abf3-4c47-8845-9167a9e7d1b1' = @('Thunfischsalat', 'fish,salad,main')
}
function SqlString([string]$value) { return "'" + $value.Replace("'", "''") + "'" }
function SqlArray([object[]]$items) { return 'array[' + (($items | ForEach-Object { SqlString ([string]$_) }) -join ',') + ']::text[]' }
$catalog = @()
$sqlRows = @()
foreach ($row in $rows) {
  if (-not $tags.ContainsKey($row.id)) { continue }
  $entry = $tags[$row.id]
  if ($entry[0] -cne $row.name) { throw "Rezeptname wurde geändert: $($row.id). Bitte neu prüfen." }
  $ingredients = @($row.recipe_ingredients | ForEach-Object { $_.ingredients.name })
  $categories = $entry[1].Split(',')
  $image = if ($entry.Count -gt 2) { $entry[2] } else { $null }
  $catalog += [ordered]@{id=$row.id;name=$row.name;ingredients=$ingredients;categories=$categories;image_url=$image}
  $imageSql = if ($image) { SqlString $image } else { 'null' }
  $sqlRows += '(' + (SqlString $row.id) + ',' + (SqlString $row.name) + ',' + (SqlArray $ingredients) + ',' + (SqlArray $categories) + ',' + $imageSql + ')'
}
if ($catalog.Count -ne $tags.Count) { throw 'Nicht alle geprüften Rezepte vorhanden. Bitte Katalog neu prüfen.' }
$sql = @'
-- Editorial classification of the public catalog reviewed on 2026-11-19.
-- Only untouched names/ingredient sets are updated. Existing categories and
-- explicitly selected images are preserved. Planning verification is unchanged.
begin;
with curated(id,expected_name,expected_ingredients,categories,image_url) as (
values
'@
$sql += "`n" + ($sqlRows -join ",`n")
$sql += @'

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
'@
$dataDir = Join-Path $PSScriptRoot '../supabase/data'
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
$catalog | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $dataDir 'catalog_curation_20261119.json') -Encoding utf8
Set-Content -LiteralPath $migration -Value $sql -Encoding utf8
Write-Output "$($catalog.Count) geprüfte Rezeptzuordnungen vorbereitet. Noch keine Datenbankänderung ausgeführt."
