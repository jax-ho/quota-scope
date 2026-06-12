# QuotaScope Release Guide

QuotaScope is distributed outside the Mac App Store through GitHub Releases.
By default, releases are unsigned DMGs containing an ad-hoc signed app, so the
project can ship without a paid Apple Developer Program membership while still
letting macOS validate the app bundle and WidgetKit extension structure. A
future Developer ID signed and notarized release path is still available when
Apple credentials are configured.

## Prerequisites

- Full Xcode selected with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- GitHub repository write access for publishing releases

The default bundle identifiers are:

- Host app: `com.jax.quotascope`
- Widget extension: `com.jax.quotascope.widget`

If you want to ship under a different namespace, change the defaults in
`scripts/release-config.sh` and the `QUOTASCOPE_*_BUNDLE_ID` defaults in the
Xcode project before your first public release.

## Local Unsigned Release

Create a free local release DMG for smoke testing or small-scale GitHub
distribution:

```sh
scripts/package-release.sh \
  --version 1.0.0 \
  --build-number 100 \
  --export-unsigned \
  --skip-notarization
```

Unsigned releases are ad-hoc signed but not Developer ID signed or notarized.
Users who download them from the internet may need to Control-click the app and
choose Open, or approve the app in macOS Privacy & Security settings.

## Developer ID Release

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

Artifacts are written to `dist/release/`:

- `QuotaScope-<version>.dmg`
- `SHA256SUMS`
- `RELEASE_NOTES.md`

## GitHub Releases

The `.github/workflows/release.yml` workflow publishes a GitHub Release when a
tag matching `v*` is pushed. Tag releases use the free unsigned distribution
mode by default. The workflow can also be run manually from the Actions tab,
where `distribution` can be set to `unsigned` or `signed`.

No repository secrets are required for unsigned releases.

Signed Developer ID releases require these repository secrets:

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

In unsigned mode, the workflow builds the Release app, ad-hoc signs the
WidgetKit extension and host app, skips notarization, creates the DMG, writes
`SHA256SUMS`, and uploads both files to GitHub Releases. In signed mode, it uses
Developer ID signing, submits the DMG with `xcrun notarytool`, and staples the
notarization ticket before upload.

## AI Release Runbook

Use this checklist when asking an AI agent to publish the next unsigned GitHub
Release.

1. Confirm the checkout is on `main` and clean:

```sh
git switch main
git pull --ff-only origin main
git status --short --branch
```

2. Choose the next version tag. Use semantic versions like `v1.0.1`; do not
   reuse an existing tag:

```sh
git tag --list 'v*'
```

3. Run the local release checks:

```sh
scripts/test-release-channel.sh
swift test
scripts/package-release.sh \
  --dry-run \
  --version 1.0.1 \
  --build-number 101 \
  --export-unsigned \
  --skip-notarization
```

4. Push the tag to trigger the GitHub Release workflow:

```sh
git tag v1.0.1
git push origin v1.0.1
```

5. Watch the `Release` workflow on GitHub. A normal unsigned run skips
   `Import Developer ID certificate`, then completes `Package release` and
   `Publish GitHub Release`.

6. Verify the created release page contains:

- `QuotaScope-<version>.dmg`
- `SHA256SUMS`
- release notes saying `Distribution: unsigned DMG with an ad-hoc signed app`

7. If the release workflow fails, inspect the failed GitHub Actions job logs,
   fix the branch on `main`, delete the failed tag locally and remotely, then
   recreate the tag at the fixed commit:

```sh
git tag -d v1.0.1
git push origin :refs/tags/v1.0.1
git tag v1.0.1
git push origin v1.0.1
```

## Verification

Before publishing, run:

```sh
scripts/test-release-channel.sh
```

On a machine with full Xcode, also run:

```sh
swift test
scripts/package-release.sh --dry-run --version 1.0.0 --build-number 100
```

For signed Developer ID releases, also run:

```sh
scripts/verify-release-environment.sh
```

After downloading a release:

```sh
shasum -a 256 -c SHA256SUMS
```

Then mount the DMG, copy `QuotaScope.app` to Applications, open it once, and
confirm the QuotaScope widget appears in macOS Edit Widgets. For signed
Developer ID releases, also check Gatekeeper:

```sh
spctl -a -vv -t open --context context:primary-signature QuotaScope-1.0.0.dmg
```

## Troubleshooting

If `xcodebuild` says the active developer directory is Command Line Tools,
select full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

If an unsigned GitHub Release is blocked by macOS on another machine, use
Control-click -> Open, or approve the app in Privacy & Security settings. If a
signed release notarization fails, run the packaging script again with the same
version and `--skip-notarization` to confirm signing and DMG creation are
healthy, then fix the Apple credentials or entitlement issue reported by
`xcrun notarytool`.
