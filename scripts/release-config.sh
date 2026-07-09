#!/usr/bin/env bash

# Shared release settings for local packaging and GitHub Actions.
# Override these in the environment when cutting a release for a different
# Apple Developer account or bundle namespace.

APP_NAME="${APP_NAME:-QuotaScope}"
PROJECT_PATH="${PROJECT_PATH:-CodexWatcher.xcodeproj}"
SCHEME_NAME="${SCHEME_NAME:-CodexWatcher}"
CONFIGURATION="${CONFIGURATION:-Release}"
MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-13.0}"

HOST_BUNDLE_ID="${HOST_BUNDLE_ID:-com.jax.quotascope}"
WIDGET_BUNDLE_ID="${WIDGET_BUNDLE_ID:-${HOST_BUNDLE_ID}.widget}"

RELEASE_ROOT="${RELEASE_ROOT:-dist/release}"
BUILD_ROOT="${BUILD_ROOT:-build/release}"
