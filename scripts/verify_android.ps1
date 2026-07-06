param(
  [switch]$BuildApk
)

$ErrorActionPreference = 'Stop'

$env:Path = 'C:\tools\flutter\bin;C:\AndroidSDK\platform-tools;C:\AndroidSDK\cmdline-tools\latest\bin;' + $env:Path

flutter doctor -v
flutter analyze
flutter test

if ($BuildApk) {
  flutter build apk --debug
  Get-Item 'build\app\outputs\flutter-apk\app-debug.apk' |
    Select-Object FullName, Length, LastWriteTime
}
