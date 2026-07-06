# Native API Contracts

Native screens must not call undocumented portal endpoints directly in UI code.

Before implementing a native repository for a portal module:

1. Add a sanitized entry to `docs/portal_api_inventory.md`.
2. Add request/response models under the module feature.
3. Add repository tests using redacted fixtures.
4. Keep tokens, cookies, student IDs, names, emails, class codes, and raw HAR
   exports out of the repository.

`PortalApiClient` can attach an OIDC bearer token when `AuthController` has a
native session. If a portal endpoint requires a different server-side session
cookie, document that as a blocker instead of storing credentials in the app.
