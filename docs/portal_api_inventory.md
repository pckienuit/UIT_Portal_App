# Portal API Inventory

This file is intentionally empty in phase 1.

When authenticated API discovery starts, record only sanitized endpoint details:
method, path, request shape, response shape, and the screen/module that uses it.
Never store cookies, tokens, passwords, raw HAR exports, or personal student data.

## Template

```text
Module:
Screen:
Endpoint:
Method:
Auth source: WebView session cookie, redacted
Request shape:
Response shape:
Native status: planned | implemented | blocked
Notes:
```

## Discovery Rules

- Capture only endpoints required by the app module being native-ized.
- Replace all IDs, names, emails, class codes, tokens, cookies, and timestamps
  with placeholders before saving notes here.
- If an endpoint cannot be verified safely, keep the module on WebView fallback.
