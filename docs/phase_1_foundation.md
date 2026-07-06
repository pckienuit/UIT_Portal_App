# Phase 1: Flutter Android Foundation

Historical note: WebView fallback described below has been superseded by the
native module/AppAuth migration.

## Completed

- Installed Flutter stable in `C:\tools\flutter` for this machine.
- Fixed Android SDK command-line tools and accepted Android SDK licenses.
- Created a Flutter project targeting Android first.
- Added navigation, app shell, UIT SSO login WebView, and portal module WebView fallback using `webview_flutter`.
- Added the first widget test for the entry screen.
- Follow-up phase 2 adds auth state and cookie/storage cleanup around the SSO WebView.

## Security Notes

- Do not commit passwords, cookies, bearer tokens, session values, raw HAR files, or screenshots containing personal data.
- UIT SSO credentials must only be typed into the SSO screen during local testing.
- API discovery notes must be sanitized before they are saved in this repo.
