# Android Release Guide

## Prerequisites

- Flutter `3.44.4`, Dart `3.12.2`
- JDK 17
- Android SDK and build tools
- Native Node runtime under `android/app/libnode/` for `arm64-v8a` and `x86_64`
- Clean or understood Git worktree

## Create signing key

Never commit the keystore or `key.properties`.

```bash
keytool -genkeypair -v \
  -keystore android/app/uit-portal-release.jks \
  -alias uit-portal \
  -keyalg RSA -keysize 4096 -validity 10000
```

Create `android/key.properties`:

```properties
storePassword=replace-with-keystore-password
keyPassword=replace-with-key-password
keyAlias=uit-portal
storeFile=uit-portal-release.jks
```

The release build fails signing if this local configuration is absent or invalid. It must never fall back to debug signing.

## Validate

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew.bat :app:testDebugUnitTest
```

## Build and verify

```bash
flutter build apk --release
/c/AndroidSDK/build-tools/36.1.0/apksigner.bat verify --verbose build/app/outputs/flutter-apk/app-release.apk
/c/AndroidSDK/build-tools/36.1.0/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Then install the exact artifact on a physical device or emulator, verify launch, light/dark theme, font scale and absence of Flutter/Kotlin crashes.

## Publish checklist

1. Confirm `git diff --check` and intended files only.
2. Rotate/revoke any credential ever exposed in history before publicizing a release.
3. Commit release changes.
4. Create annotated tag: `git tag -a v1.0.0 -m "UIT Portal Mobile v1.0.0"`.
5. Push commit and tag.
6. Create GitHub release from tag, attach APK and paste SHA-256 plus certificate fingerprint.
7. Never overwrite an existing release APK. Cut a new version and tag.
