# Dot-source this to load ./.env into a hashtable:  $env = & "$PSScriptRoot/load-env.ps1"
param([string] $Path = (Join-Path (Split-Path -Parent $PSScriptRoot) ".env"))

$result = @{}
if (Test-Path $Path) {
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $k = $line.Substring(0, $idx).Trim()
    $v = $line.Substring($idx + 1).Trim().Trim('"')
    $result[$k] = $v
  }
}
return $result
