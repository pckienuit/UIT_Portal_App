param(
    [string]$OidcClientId
)

$ErrorActionPreference = 'Stop'

# Prepend the necessary paths to $env:Path
$env:Path = 'C:\tools\flutter\bin;C:\AndroidSDK\platform-tools;C:\AndroidSDK\cmdline-tools\latest\bin;' + $env:Path

if ([string]::IsNullOrWhiteSpace($OidcClientId)) {
    Write-Host "Running Flutter without OIDC Client ID..."
    flutter run
} else {
    Write-Host "Running Flutter with OIDC Client ID: $OidcClientId"
    flutter run "--dart-define=UIT_OIDC_CLIENT_ID=$OidcClientId"
}
