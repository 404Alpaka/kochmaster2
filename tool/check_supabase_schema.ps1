param(
  [string]$ProjectUrl,
  [string]$PublishableKey
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectUrl -or -not $PublishableKey) {
  $configPath = Join-Path $PSScriptRoot '../lib/core/config/app_config.dart'
  $values = [regex]::Matches((Get-Content -LiteralPath $configPath -Raw), "defaultValue: '([^']+)'")
  if (-not $ProjectUrl) { $ProjectUrl = $values[0].Groups[1].Value }
  if (-not $PublishableKey) { $PublishableKey = $values[1].Groups[1].Value }
}
if ($PublishableKey.StartsWith('sb_secret_')) { throw 'Nur einen öffentlichen Publishable-Key verwenden.' }
$checks = @(
  @{ Name = 'Rezeptkatalog'; Path = 'recipes?select=image_url,categories,verified_allergens,verified_diets,deleted_at&limit=0'; Expected = 200 },
  @{ Name = 'Planermerkmale'; Path = 'recipes?select=primary_side,dish_type,main_ingredient,active_minutes,preparation_method,flavors,cost_class&limit=0'; Expected = 200 },
  @{ Name = 'Zutatenverknüpfungen'; Path = 'recipe_ingredients?select=step_key&limit=0'; Expected = 200 },
  @{ Name = 'Private Wochenpläne'; Path = 'user_week_plans?select=meals,checked,revision&limit=0'; Expected = 401 },
  @{ Name = 'Kontodaten'; Path = 'user_preferences?select=data,revision&limit=0'; Expected = 401 },
  @{ Name = 'Kundenprofile'; Path = 'customer_profiles?select=customer_number,first_name,last_name&limit=0'; Expected = 401 },
  @{ Name = 'Haushaltspläne'; Path = 'household_week_plans?select=meals,checked,revision&limit=0'; Expected = 401 },
  @{ Name = 'Favoritenzahlen'; Path = 'rpc/recipe_popularity'; Expected = 200 },
  @{ Name = 'Anonyme Haushaltsregeln gesperrt'; Path = 'rpc/save_household_state'; Expected = 401;
     Body = '{"p_household":null,"p_data":{},"p_revision":0}' },
  @{ Name = 'Anonyme Planspeicherung gesperrt'; Path = 'rpc/save_user_week_plan'; Expected = 401;
     Body = '{"p_user":null,"p_week":"2026-11-16","p_meals":[],"p_checked":[],"p_revision":0}' }
)
$failed = $false
foreach ($check in $checks) {
  $request = @{
    Uri = $ProjectUrl.TrimEnd('/') + '/rest/v1/' + $check.Path
    Headers = @{ apikey = $PublishableKey }
    SkipHttpErrorCheck = $true
    TimeoutSec = 20
  }
  if ($check.Body) { $request.Method = 'Post'; $request.ContentType = 'application/json'; $request.Body = $check.Body }
  $response = Invoke-WebRequest @request
  $code = $null
  if ([int]$response.StatusCode -ge 400) { $code = ($response.Content | ConvertFrom-Json).code }
  $ok = [int]$response.StatusCode -eq $check.Expected -and ($check.Expected -eq 200 -or $code -eq '42501')
  if (-not $ok) { $failed = $true }
  [pscustomobject]@{ Pruefung = $check.Name; Ergebnis = $(if ($ok) { 'PASS' } else { 'FAIL' }); HTTP = [int]$response.StatusCode; Code = $code }
}
if ($failed) { exit 1 }
