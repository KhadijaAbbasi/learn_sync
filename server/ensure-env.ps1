# Ensures server/.env exists without wiping real secrets.
# - If .env is missing: copies from .env.example
# - If .env exists: keeps all existing values; only appends missing KEY= lines from .env.example
# Never prints secret values.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$examplePath = Join-Path $root ".env.example"
$envPath = Join-Path $root ".env"

if (-not (Test-Path $examplePath)) {
  Write-Error ".env.example not found in $root"
  exit 1
}

function Get-EnvEntries {
  param([string]$Path)
  $map = [ordered]@{}
  $fileLines = Get-Content -Path $Path -ErrorAction Stop
  foreach ($line in $fileLines) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
      $map[$matches[1]] = $matches[2]
    }
  }
  return $map
}

function Test-IsPlaceholder {
  param([string]$Key, [string]$Value)
  if ($null -eq $Value) { return $true }
  $v = $Value.Trim().Trim('"').Trim("'")
  if ([string]::IsNullOrWhiteSpace($v)) { return $true }
  switch -Regex ($Key) {
    'GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_SERVICE_ACCOUNT' {
      return ($v -match 'path/to/|your_|example|CHANGE_ME|placeholder|TODO')
    }
    'FIREBASE_API_KEY|GEMINI_API_KEY|API_KEY' {
      return ($v -match 'your_|example|CHANGE_ME|placeholder|TODO|xxx')
    }
    default { return $false }
  }
}

if (-not (Test-Path $envPath)) {
  Copy-Item -Path $examplePath -Destination $envPath
  Write-Host "Created .env from .env.example (edit once; do not copy again)."
  Write-Host "Fill GOOGLE_APPLICATION_CREDENTIALS and FIREBASE_API_KEY, then: npm start"
  exit 0
}

# Merge: append keys present in example but missing from .env (never overwrite existing keys)
$existing = Get-EnvEntries -Path $envPath
$exampleMap = Get-EnvEntries -Path $examplePath
$added = New-Object System.Collections.Generic.List[string]

foreach ($key in $exampleMap.Keys) {
  if (-not $existing.Contains($key)) {
    $line = "$key=$($exampleMap[$key])"
    Add-Content -Path $envPath -Value ""
    Add-Content -Path $envPath -Value "# added by ensure-env.ps1"
    Add-Content -Path $envPath -Value $line
    [void]$added.Add($key)
  }
}

if ($added.Count -gt 0) {
  Write-Host ("Merged missing keys into existing .env (placeholder values only): " + ($added -join ", "))
  Write-Host "Existing keys were left unchanged."
} else {
  Write-Host ".env already present - left unchanged (no overwrite)."
}

$cred = ""
$api = ""
$alias = ""
if ($existing.Contains("GOOGLE_APPLICATION_CREDENTIALS")) { $cred = $existing["GOOGLE_APPLICATION_CREDENTIALS"] }
if ($existing.Contains("FIREBASE_API_KEY")) { $api = $existing["FIREBASE_API_KEY"] }
if ($existing.Contains("FIREBASE_SERVICE_ACCOUNT")) { $alias = $existing["FIREBASE_SERVICE_ACCOUNT"] }

$credOk = (-not (Test-IsPlaceholder "GOOGLE_APPLICATION_CREDENTIALS" $cred)) -or (-not (Test-IsPlaceholder "FIREBASE_SERVICE_ACCOUNT" $alias))
$apiOk = -not (Test-IsPlaceholder "FIREBASE_API_KEY" $api)

if (-not $credOk) {
  Write-Warning "GOOGLE_APPLICATION_CREDENTIALS (or FIREBASE_SERVICE_ACCOUNT) looks empty/placeholder. Edit server/.env once - do NOT run: copy .env.example .env"
}
if (-not $apiOk) {
  Write-Warning "FIREBASE_API_KEY looks empty/placeholder. Edit server/.env once - do NOT run: copy .env.example .env"
}
if ($credOk -and $apiOk) {
  Write-Host "Required keys look set (values not shown)."
}

Write-Host "Tip: use .\ensure-env.ps1 instead of copying .env.example over .env."
