# GitHub Actions + Firebase App Distribution

This project now includes two workflows:

- `.github/workflows/ios-pr-check.yml`
  - Trigger: Pull Request to `main`
  - Purpose: validate shared scheme and project settings
- `.github/workflows/firebase-distribution.yml`
  - Trigger: push to `main` (including PR merge), or manual dispatch
  - Purpose: archive app, export IPA, distribute to Firebase tester group

## Required GitHub Secrets

Set these repository secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON` (raw JSON content, not base64)
- `IOS_DIST_CERT_P12_BASE64` (base64-encoded `.p12` distribution cert)
- `IOS_DIST_CERT_PASSWORD` (password for `.p12`)
- `IOS_PROVISIONING_PROFILE_BASE64` (base64-encoded iOS provisioning profile)

Optional secrets:

- `WATCH_PROVISIONING_PROFILE_BASE64` (if watch target signing requires explicit profile)
- `IOS_KEYCHAIN_PASSWORD` (if omitted, workflow generates one)

## Optional GitHub Variables

If you do not set these, workflow defaults are used.

- `FIREBASE_APP_ID` (default: `1:326179558500:ios:c8404bae2adc65046dbb71`)
- `FIREBASE_TESTER_GROUPS` (default: `tester`)
- `IOS_DEVELOPMENT_TEAM` (default: `7Y3Y9M4N4F`)
- `IOS_BUNDLE_ID` (default: `com.th.dogArea`)
- `WATCH_BUNDLE_ID` (default: `com.th.dogArea.watchkitapp`)

## CLI setup examples

Set Firebase service account from local file:

```bash
gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < dogarea-fd81c-firebase-adminsdk-t4wg1-cc8270fb05.json
```

Set certificate/profile secrets (example with macOS `base64`):

```bash
base64 -i path/to/dist.p12 | gh secret set IOS_DIST_CERT_P12_BASE64
printf '%s' 'YOUR_P12_PASSWORD' | gh secret set IOS_DIST_CERT_PASSWORD
base64 -i path/to/dogArea.mobileprovision | gh secret set IOS_PROVISIONING_PROFILE_BASE64
# Optional watch profile
base64 -i path/to/dogAreaWatch.mobileprovision | gh secret set WATCH_PROVISIONING_PROFILE_BASE64
```

Set optional variables:

```bash
gh variable set FIREBASE_APP_ID --body '1:326179558500:ios:c8404bae2adc65046dbb71'
gh variable set FIREBASE_TESTER_GROUPS --body 'tester'
```

## Notes

- Firebase distribution uses service-account auth through `GOOGLE_APPLICATION_CREDENTIALS`.
- The workflow uploads the generated IPA as a GitHub Actions artifact.
- If signing fails on watchOS target, set `WATCH_PROVISIONING_PROFILE_BASE64` and `WATCH_BUNDLE_ID`.
