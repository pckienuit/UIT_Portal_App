# Phase 3: Networking and API Discovery Foundation

## Completed

- Added `PortalApiClient` on top of `dio` with portal base URL and conservative timeouts.
- Added typed `PortalApiException` for HTTP failures.
- Added provider wiring for future native modules.
- Added sanitized API inventory template and discovery rules.

## Boundaries

- No credential, cookie, token, or raw HAR content is stored in this repo.
- Native modules should use `PortalApiClient` only after their endpoint contract
  is recorded in `docs/portal_api_inventory.md`.
