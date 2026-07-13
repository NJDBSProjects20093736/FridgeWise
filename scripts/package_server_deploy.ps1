# Package ThriftyChef for Linux server Docker deployment.
# Creates deploy/thriftychef-server/ and deploy/thriftychef-server.zip

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$DeployDir = Join-Path $Root "deploy\thriftychef-server"
$ZipPath = Join-Path $Root "deploy\thriftychef-server.zip"

function Test-DeployPrereqs {
    $missing = @()
    foreach ($path in @(
        "data\clean\clean_recipes.csv",
        "src\models\artifacts\hybrid.pkl",
        "requirements-api.txt",
        "docker-compose.yml",
        "docker\api\Dockerfile",
        "docker\web\Dockerfile",
        "docker\nginx\default.conf"
    )) {
        if (-not (Test-Path (Join-Path $Root $path))) {
            $missing += $path
        }
    }
    if ($missing.Count -gt 0) {
        throw "Missing required files:`n  $($missing -join "`n  ")"
    }
}

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExtraExcludeDirs = @()
    )
    if (-not (Test-Path $Source)) {
        throw "Source not found: $Source"
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $exclude = @(".git", ".dart_tool", "build", ".kotlin", "Pods", ".gradle", "__pycache__", ".pytest_cache") + $ExtraExcludeDirs
    $args = @($Source, $Destination, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS", "/NP", "/XF", "*.pyc", "*.log")
    foreach ($d in $exclude) { $args += "/XD"; $args += $d }
    & robocopy @args | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed for $Source (exit $LASTEXITCODE)"
    }
}

Write-Host "ThriftyChef server package builder" -ForegroundColor Cyan
Write-Host "Root: $Root"

Test-DeployPrereqs

if (Test-Path $DeployDir) {
    Write-Host "Removing old deploy folder..."
    Remove-Item -Recurse -Force $DeployDir
}
New-Item -ItemType Directory -Force -Path $DeployDir | Out-Null

Write-Host "Copying Docker stack..."
Copy-Tree (Join-Path $Root "docker") (Join-Path $DeployDir "docker")
Copy-Item (Join-Path $Root "docker-compose.yml") (Join-Path $DeployDir "docker-compose.yml") -Force
Copy-Item (Join-Path $Root "requirements-api.txt") (Join-Path $DeployDir "requirements-api.txt") -Force
Copy-Item (Join-Path $Root ".env.example") (Join-Path $DeployDir ".env.example") -Force

Write-Host "Copying API and recommender..."
Copy-Tree (Join-Path $Root "api") (Join-Path $DeployDir "api")
Copy-Tree (Join-Path $Root "src") (Join-Path $DeployDir "src")
Copy-Tree (Join-Path $Root "assets") (Join-Path $DeployDir "assets")

Write-Host "Copying Flutter app source..."
Copy-Tree (Join-Path $Root "app") (Join-Path $DeployDir "app")

Write-Host "Copying datasets and model artifacts..."
Copy-Tree (Join-Path $Root "data\clean") (Join-Path $DeployDir "data\clean")
Copy-Tree (Join-Path $Root "src\models\artifacts") (Join-Path $DeployDir "src\models\artifacts")

Write-Host "Copying scripts..."
New-Item -ItemType Directory -Force -Path (Join-Path $DeployDir "scripts") | Out-Null
Copy-Item (Join-Path $Root "scripts\run_api.py") (Join-Path $DeployDir "scripts\run_api.py") -Force
Copy-Item (Join-Path $Root "scripts\docker-up.sh") (Join-Path $DeployDir "scripts\docker-up.sh") -Force

Write-Host "Copying documentation..."
Copy-Item (Join-Path $Root "deploy\SERVER_DEPLOY.md") (Join-Path $DeployDir "SERVER_DEPLOY.md") -Force
if (Test-Path (Join-Path $Root "deploy\ThriftyChef_Web_App_User_Guide.md")) {
    Copy-Item (Join-Path $Root "deploy\ThriftyChef_Web_App_User_Guide.md") (Join-Path $DeployDir "ThriftyChef_Web_App_User_Guide.md") -Force
}

$readme = @"
# ThriftyChef Server Package

Quick start on Linux:

````bash
cp .env.example .env    # fill Supabase credentials
chmod +x scripts/docker-up.sh
./scripts/docker-up.sh
````

| Service | URL |
|---------|-----|
| Web app | http://YOUR_SERVER:8004 |
| API health | http://YOUR_SERVER:8004/api/health |
| API docs | http://YOUR_SERVER:8005/docs |

Full guide: SERVER_DEPLOY.md
"@
Set-Content -Path (Join-Path $DeployDir "README.md") -Value $readme -Encoding UTF8

if (Test-Path $ZipPath) {
    Remove-Item -Force $ZipPath
}

Write-Host "Creating zip (this may take a minute)..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($DeployDir, $ZipPath)

$folderSize = (Get-ChildItem $DeployDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
$zipSize = (Get-Item $ZipPath).Length

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Folder: $DeployDir"
Write-Host "  Zip:    $ZipPath"
Write-Host ("  Folder size: {0:N1} MB" -f ($folderSize / 1MB))
Write-Host ("  Zip size:    {0:N1} MB" -f ($zipSize / 1MB))
Write-Host ""
Write-Host "Upload to server:" -ForegroundColor Yellow
Write-Host "  scp deploy/thriftychef-server.zip user@SERVER:/home/user/"
Write-Host "  unzip thriftychef-server.zip && cd thriftychef-server"
Write-Host "  cp .env.example .env && nano .env"
Write-Host "  ./scripts/docker-up.sh"
