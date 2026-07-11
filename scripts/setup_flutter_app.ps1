# Generate Flutter platform folders using local Flutter SDK
$FlutterBin = "D:\DBS - Sem 2\RC\flutter\bin"
if (-not (Test-Path "$FlutterBin\flutter.bat")) {
    Write-Host "Flutter not found at $FlutterBin"
    Write-Host "Install: git clone https://github.com/flutter/flutter.git -b stable D:\DBS - Sem 2\RC\flutter"
    exit 1
}
$env:Path = "$FlutterBin;" + $env:Path

Set-Location $PSScriptRoot\..\app
flutter pub get
Write-Host ""
Write-Host "Flutter ready. Start API then run:"
Write-Host "  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000"
