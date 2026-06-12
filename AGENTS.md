# Agent Notes

## Release Workflow

QuotaScope publishes unsigned GitHub Releases by default. The app inside the
free unsigned DMG must still be ad-hoc signed so macOS can validate the host app
and WidgetKit extension bundles. Before changing or running the release flow,
read `docs/release.md`, especially the `AI Release Runbook` section.

For release-related edits, keep these checks green:

```sh
scripts/test-release-channel.sh
swift test
```

Use tag pushes like `v1.0.1` to trigger the unsigned GitHub Release workflow.
Do not require Apple Developer Program credentials unless the user explicitly
asks for the optional signed Developer ID release path.

If the user asks to package, update, ship, publish, release, or verify GitHub
Release availability after a fix, do not stop at merging to `main`. After the
fix is on `main`, choose the next unused semantic `v*` tag, run the release
checks and unsigned dry run from `docs/release.md`, push the tag, watch the
GitHub `Release` workflow to completion, and verify the release page contains
the DMG and `SHA256SUMS`. If the user only asks to merge and release intent is
ambiguous, ask once whether to cut a GitHub Release now.
