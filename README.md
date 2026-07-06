# UIT Portal Mobile

Native-first Flutter Android app for `https://portal.uit.edu.vn`.

The app starts with a Flutter shell, UIT SSO login, and WebView fallback for
portal modules that do not have a documented native API yet. Native screens can
replace fallback modules as sanitized API contracts are discovered.

## Local Setup

This machine currently uses:

- Flutter `3.44.4` at `C:\tools\flutter`
- Android SDK at `C:\AndroidSDK`
- Java from Android Studio JBR

For this PowerShell session:

```powershell
$env:Path='C:\tools\flutter\bin;C:\AndroidSDK\platform-tools;C:\AndroidSDK\cmdline-tools\latest\bin;' + $env:Path
```

## Verify

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Security

Do not commit UIT passwords, cookies, tokens, raw HAR exports, or screenshots
containing personal student data. API discovery notes must be sanitized before
being saved in `docs/portal_api_inventory.md`.
