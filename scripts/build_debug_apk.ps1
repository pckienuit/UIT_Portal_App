$ErrorActionPreference = 'Stop'

$env:Path = 'C:\tools\flutter\bin;C:\AndroidSDK\platform-tools;C:\AndroidSDK\cmdline-tools\latest\bin;' + $env:Path

flutter build apk --debug

Get-Item 'build\app\outputs\flutter-apk\app-debug.apk' |
  Select-Object FullName, Length, LastWriteTime
