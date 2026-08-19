# Builds the MaJo e-School Bridge Flutter web app ONLY.
# Do NOT use this script from the separate marketing website project.
param(
    [switch]$Deploy
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Building MaJo e-School Bridge web app from $root"

flutter pub get
dart run flutter_launcher_icons
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run

$required = @(
    'build\web\main.dart.js',
    'build\web\flutter_bootstrap.js',
    'build\web\assets\fonts\MaterialIcons-Regular.otf',
    'build\web\manifest.json'
)

# Copy static web assets if the build step skipped any of them.
$staticCopies = @(
    @{ From = 'web\favicon.png'; To = 'build\web\favicon.png' },
    @{ From = 'web\icons'; To = 'build\web\icons' },
    @{ From = 'web\splash'; To = 'build\web\splash' }
)

foreach ($copy in $staticCopies) {
    if (Test-Path $copy.From) {
        if ((Test-Path $copy.To) -and ((Get-Item $copy.To) -is [System.IO.DirectoryInfo])) {
            continue
        }
        if (-not (Test-Path $copy.To)) {
            if ((Get-Item $copy.From) -is [System.IO.DirectoryInfo]) {
                Copy-Item -Path $copy.From -Destination $copy.To -Recurse -Force
            } else {
                $parent = Split-Path $copy.To -Parent
                if ($parent -and -not (Test-Path $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Copy-Item -Path $copy.From -Destination $copy.To -Force
            }
            Write-Host "Copied $($copy.From) -> $($copy.To)"
        }
    }
}

$missing = @()
foreach ($path in $required) {
    if (-not (Test-Path $path)) {
        $missing += $path
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Web build is incomplete. Missing:`n$($missing -join "`n")"
}

Write-Host "Web build OK: build\web"

if ($Deploy) {
    $project = (Get-Content '.firebaserc' -Raw | ConvertFrom-Json).projects.default
    if ($project -ne 'majo-e-school-bridge') {
        Write-Error "Refusing to deploy: expected project majo-e-school-bridge, got $project"
    }
    Write-Host "Deploying ONLY hosting for MaJo e-School Bridge app..."
    firebase deploy --only hosting:majo-e-school-bridge
}
