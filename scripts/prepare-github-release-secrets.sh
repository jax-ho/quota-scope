#!/usr/bin/env bash
set -euo pipefail

COPY_TO_CLIPBOARD=0
DRY_RUN=0
OUTPUT_PATH=""
CERTIFICATE_PATH=""

usage() {
  cat <<'USAGE'
Usage: scripts/prepare-github-release-secrets.sh [options] DeveloperIDApplication.p12

Encode a Developer ID Application .p12 for the GitHub Actions
APPLE_CERTIFICATE_BASE64 secret without printing the secret by default.

Options:
  --copy             Copy the encoded certificate to the macOS clipboard with pbcopy.
  --output PATH      Write the encoded certificate to PATH with owner-only permissions.
  --dry-run          Validate inputs and describe what would happen.
  --help             Show this help.

Examples:
  scripts/prepare-github-release-secrets.sh --copy DeveloperIDApplication.p12
  scripts/prepare-github-release-secrets.sh --output /tmp/quotascope-cert.base64 DeveloperIDApplication.p12

After encoding, create these GitHub repository secrets:
  APPLE_CERTIFICATE_BASE64
  APPLE_CERTIFICATE_PASSWORD
  APPLE_TEAM_ID
  APPLE_ID
  APPLE_APP_SPECIFIC_PASSWORD
USAGE
}

die() {
  printf 'prepare-github-release-secrets: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      COPY_TO_CLIPBOARD=1
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || die "--output requires a path"
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$CERTIFICATE_PATH" ]] || die "only one certificate path is allowed"
      CERTIFICATE_PATH="$1"
      shift
      ;;
  esac
done

[[ -n "$CERTIFICATE_PATH" ]] || die "path to Developer ID Application .p12 is required"
[[ -f "$CERTIFICATE_PATH" ]] || die "certificate file does not exist: $CERTIFICATE_PATH"

if [[ "$DRY_RUN" -eq 1 ]]; then
  destination="no output selected"
  if [[ "$COPY_TO_CLIPBOARD" -eq 1 ]]; then
    destination="macOS clipboard"
  elif [[ -n "$OUTPUT_PATH" ]]; then
    destination="file: $OUTPUT_PATH"
  fi
  printf 'would encode %s for APPLE_CERTIFICATE_BASE64 and write to %s\n' "$CERTIFICATE_PATH" "$destination"
  exit 0
fi

if [[ "$COPY_TO_CLIPBOARD" -eq 0 && -z "$OUTPUT_PATH" ]]; then
  die "choose --copy or --output PATH so the encoded certificate is not printed to the terminal"
fi

if [[ "$COPY_TO_CLIPBOARD" -eq 1 ]]; then
  command -v pbcopy >/dev/null 2>&1 || die "pbcopy is required for --copy"
  base64 -i "$CERTIFICATE_PATH" | tr -d '\n' | pbcopy
  printf 'encoded certificate copied to clipboard for APPLE_CERTIFICATE_BASE64\n'
  exit 0
fi

umask 077
mkdir -p "$(dirname "$OUTPUT_PATH")"
base64 -i "$CERTIFICATE_PATH" | tr -d '\n' > "$OUTPUT_PATH"
printf 'encoded certificate written to %s for APPLE_CERTIFICATE_BASE64\n' "$OUTPUT_PATH"
