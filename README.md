# UIT Portal Mobile

Native Flutter Android app for `https://portal.uit.edu.vn`.

The app now uses Flutter-native screens for the portal shell/modules and
AppAuth/Custom Tabs for UIT SSO. No `webview_flutter` dependency remains in the
runtime app. Dynamic portal data is intentionally pending until each endpoint is
verified and documented in `docs/portal_api_inventory.md`.

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

Or run the project script:

```powershell
.\scripts\verify_android.ps1 -BuildApk
```

The debug APK is written to:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Native Auth Configuration

The default OIDC issuer is:

```text
https://sso.uit.edu.vn/realms/UIT
```

The app uses this redirect URI:

```text
com.personal.uitportal:/oauthredirect
```

Use a UIT-approved mobile client id when available:

```powershell
flutter run --dart-define=UIT_OIDC_CLIENT_ID=<client-id>
```

The legacy portal web client id may reject the mobile redirect URI until UIT
allows a mobile OAuth client/redirect.

## Security

Do not commit UIT passwords, cookies, tokens, raw HAR exports, or screenshots
containing personal student data. API discovery notes must be sanitized before
being saved in `docs/portal_api_inventory.md`.
