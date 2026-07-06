# Native Migration Status

## Current State

- UIT SSO login uses AppAuth/Custom Tabs, not WebView.
- Portal modules route to Flutter native screens.
- `webview_flutter` has been removed from `pubspec.yaml`.
- Dashboard is native implemented with local/session state.
- Profile, Services, and Notifications are native pending API contracts.

## External Blockers

- UIT/Keycloak must allow the mobile redirect URI
  `com.personal.uitportal:/oauthredirect` for the configured OIDC client.
- Real portal data requires sanitized endpoint inventory after authenticated
  discovery.

## Completion Criteria

- Every module has a native repository and model backed by documented endpoints.
- `rg "webview_flutter|WebViewWidget|WebViewController|PortalWebFallbackScreen" lib pubspec.yaml`
  returns no matches.
- `.\scripts\verify_android.ps1 -BuildApk` passes.
