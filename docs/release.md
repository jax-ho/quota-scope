# QuotaScope Release Guide

QuotaScope is distributed outside the Mac App Store through GitHub Releases.
The release artifact is a Developer ID signed, notarized DMG containing
`QuotaScope.app` and an `/Applications` shortcut.

## Prerequisites

- Full Xcode selected with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- An Apple Developer Program membership
- A `Developer ID Application` certificate installed locally or imported by CI
- An app-specific password for `xcrun notarytool`, or a stored notarytool keychain profile
- GitHub repository write access for publishing releases

The default bundle identifiers are:

- Host app: `com.jax.quotascope`
- Widget extension: `com.jax.quotascope.widget`

If you want to ship under a different namespace, change the defaults in
`scripts/release-config.sh` and the `QUOTASCOPE_*_BUNDLE_ID` defaults in the
Xcode project before your first public release.

## Local Signed Release

Create a signed and notarized release:

```sh
APPLE_TEAM_ID=ABCDE12345 \
APPLE_ID=you@example.com \
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx \
scripts/package-release.sh --version 1.0.0 --build-number 100
```

To use a notarytool profile instead of passing Apple ID credentials each time:

```sh
xcrun notarytool store-credentials quotascope-notary \
  --apple-id you@example.com \
  --team-id ABCDE12345 \
  --password xxxx-xxxx-xxxx-xxxx

NOTARY_KEYCHAIN_PROFILE=quotascope-notary \
scripts/package-release.sh --version 1.0.0 --build-number 100
```

For a local smoke-test DMG that is not suitable for distribution:

```sh
scripts/package-release.sh \
  --version 1.0.0 \
  --build-number 100 \
  --export-unsigned \
  --skip-notarization
```

Artifacts are written to `dist/release/`:

- `QuotaScope-<version>.dmg`
- `SHA256SUMS`
- `RELEASE_NOTES.md`

## GitHub Releases

The `.github/workflows/release.yml` workflow publishes a GitHub Release when a
tag matching `v*` is pushed. It can also be run manually from the Actions tab.

Required repository secrets:

- `APPLE_CERTIFICATE_BASE64`: base64-encoded `.p12` Developer ID Application certificate
- `APPLE_CERTIFICATE_PASSWORD`: password for that `.p12`
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_ID`: Apple ID used by `xcrun notarytool`
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization

Optional repository secret:

- `APPLE_SIGNING_IDENTITY`: exact codesign identity name. If omitted, the
  packaging script uses `Developer ID Application`.

Create `APPLE_CERTIFICATE_BASE64` from an exported `.p12` without printing the
certificate material to the terminal:

```sh
scripts/prepare-github-release-secrets.sh --copy DeveloperIDApplication.p12
```

Then paste the clipboard value into the GitHub secret. If you prefer writing a
temporary file, use:

```sh
scripts/prepare-github-release-secrets.sh \
  --output /tmp/quotascope-cert.base64 \
  DeveloperIDApplication.p12
```

Delete that temporary file after creating the secret.

Create a release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds the Release app, signs the WidgetKit extension and host app,
creates the DMG, submits it with `xcrun notarytool`, staples the notarization
ticket, writes `SHA256SUMS`, and uploads both files to GitHub Releases.

## Verification

Before publishing, run:

```sh
scripts/test-release-channel.sh
scripts/verify-release-environment.sh
```

On a machine with full Xcode, also run:

```sh
swift test
scripts/package-release.sh --dry-run --version 1.0.0 --build-number 100
```

After downloading a release:

```sh
shasum -a 256 -c SHA256SUMS
spctl -a -vv -t open --context context:primary-signature QuotaScope-1.0.0.dmg
```

Then mount the DMG, copy `QuotaScope.app` to Applications, open it once, and
confirm the QuotaScope widget appears in macOS Edit Widgets.

## Troubleshooting

If `xcodebuild` says the active developer directory is Command Line Tools,
select full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

If notarization fails, run the packaging script again with the same version and
`--skip-notarization` to confirm signing and DMG creation are healthy, then fix
the Apple credentials or entitlement issue reported by `xcrun notarytool`.
