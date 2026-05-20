#!/usr/bin/env pwsh
# Candy Crunch deploy script
# - Bumps service-worker.js VERSION constant to force a cache refresh
# - Commits and pushes to GitHub Pages
# Usage:
#   .\deploy.ps1                       # auto-generated commit message
#   .\deploy.ps1 -Message "new level"  # custom message
param(
  [string]$Message
)
$ErrorActionPreference = 'Stop'
$env:Path = "C:\Program Files\GitHub CLI;$env:Path"

$repoDir = Split-Path -Parent $PSCommandPath
Set-Location $repoDir

# 1. Bump service worker VERSION
$ts = (Get-Date).ToString('yyyy-MM-dd-HHmmss')
$swPath = Join-Path $repoDir 'service-worker.js'
if (-not (Test-Path $swPath)) {
  Write-Error "service-worker.js not found at $swPath"
  exit 1
}
$sw = Get-Content $swPath -Raw
$pattern = "const VERSION = '[^']*';"
if ($sw -notmatch $pattern) {
  Write-Error "Could not find VERSION constant in service-worker.js"
  exit 1
}
$swNew = [regex]::Replace($sw, $pattern, "const VERSION = '$ts';")
Set-Content -Path $swPath -Value $swNew -NoNewline -Encoding UTF8
Write-Host "Bumped SW version: $ts" -ForegroundColor Cyan

# 2. Stage everything
git add -A | Out-Null
$staged = git diff --cached --name-only
if (-not $staged) {
  Write-Host "No changes to deploy." -ForegroundColor Yellow
  exit 0
}
Write-Host ""
Write-Host "Files in this push:" -ForegroundColor Gray
$staged | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# 3. Commit
if (-not $Message) { $Message = "Update $ts" }
Write-Host ""
Write-Host "Commit: $Message" -ForegroundColor Gray
git commit -m $Message | Out-Null

# 4. Push
Write-Host ""
Write-Host "Pushing..." -ForegroundColor Cyan
git push 2>&1 | Select-Object -Last 3

# 5. Print the live URL
$remote = git remote get-url origin
if ($remote -match 'github\.com[:/]([^/]+)/([^/.]+?)(\.git)?$') {
  $owner = $Matches[1]
  $repo  = $Matches[2]
  $url = "https://$owner.github.io/$repo/"
  Write-Host ""
  Write-Host "Deployed. Live in ~30s at:" -ForegroundColor Green
  Write-Host "  $url" -ForegroundColor White
}
