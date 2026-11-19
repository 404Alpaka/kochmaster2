param([string]$ProjectUrl,[string]$PublishableKey)
$ErrorActionPreference='Stop'
$values=[regex]::Matches((Get-Content -LiteralPath (Join-Path $PSScriptRoot '../lib/core/config/app_config.dart') -Raw),"defaultValue: '([^']+)'")
if(-not $ProjectUrl) { $ProjectUrl=$values[0].Groups[1].Value }
if(-not $PublishableKey) { $PublishableKey=$values[1].Groups[1].Value }
if($PublishableKey.StartsWith('sb_secret_')) { throw 'Nur öffentlichen App-Key verwenden.' }
$rows=Invoke-RestMethod -Uri ($ProjectUrl.TrimEnd('/')+'/rest/v1/recipes?select=id,name,primary_side,dish_type,main_ingredient,active_minutes,preparation_method,flavors,cost_class,verified_allergens,verified_diets&is_published=eq.true&deleted_at=is.null&order=name') -Headers @{apikey=$PublishableKey} -TimeoutSec 20
[pscustomobject]@{VeroeffentlichteRezepte=$rows.Count;MitHauptbeilage=@($rows|Where-Object {$_.primary_side}).Count;MitGerichtsart=@($rows|Where-Object {$_.dish_type}).Count;MitHauptzutat=@($rows|Where-Object {$_.main_ingredient}).Count;MitAktiverZeit=@($rows|Where-Object {$null -ne $_.active_minutes}).Count;MitKostenklasse=@($rows|Where-Object {$_.cost_class}).Count;MitGeprueftenAllergenen=@($rows|Where-Object {$null -ne $_.verified_allergens}).Count;MitGepruefterErnaehrungsweise=@($rows|Where-Object {$null -ne $_.verified_diets}).Count}
