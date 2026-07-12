# FridgeWise Flutter app

## Prerequisites

- Flutter SDK 3.16+ (installed locally at `D:\DBS - Sem 2\RC\flutter` — also on user PATH)
- FridgeWise API running: `python scripts/run_api.py`

## Quick setup (Windows)

```powershell
.\scripts\setup_flutter_app.ps1
```

```bash
cd app
flutter pub get
flutter run
```

### Android emulator API URL

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Physical device on same Wi‑Fi

Use your PC LAN IP, e.g. `--dart-define=API_BASE_URL=http://192.168.1.10:8000`

## Screens

- Onboarding (diet / allergies)
- Recommendations (hybrid top-10)
- Recipe detail (why recommended)
- Fridge inventory + barcode lookup

## Package ID

Default: `fridgewise_ai` — change in `pubspec.yaml` / platform configs when publishing.
