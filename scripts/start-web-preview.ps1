param(
  [int] $Port = 3009
)

$projectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Building My Village Pro for web..." -ForegroundColor Cyan
& "$PSScriptRoot/flutter-with-env.ps1" -Command build -BuildTarget web
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$buildDir = Join-Path $projectRoot "build\web"
if (-not (Test-Path $buildDir)) {
  Write-Error "Expected build output at $buildDir but it was not found."
  exit 1
}

Write-Host "Serving build\\web at http://localhost:$Port" -ForegroundColor Green
Push-Location $buildDir
try {
  python -m http.server $Port
} finally {
  Pop-Location
}
