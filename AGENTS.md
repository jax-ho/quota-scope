# Agent Notes

## Release Workflow

QuotaScope publishes unsigned GitHub Releases by default. Before changing or
running the release flow, read `docs/release.md`, especially the
`AI Release Runbook` section.

For release-related edits, keep these checks green:

```sh
scripts/test-release-channel.sh
swift test
```

Use tag pushes like `v1.0.1` to trigger the unsigned GitHub Release workflow.
Do not require Apple Developer Program credentials unless the user explicitly
asks for the optional signed Developer ID release path.
