#!/usr/bin/env bash
# Builds and publishes a personal test build of local/ebird-widget-ntfy to
# dk1/birdnet-live-app as a GitHub Release, for sharing with family while
# PR #170 (eBird life list) is pending upstream review.
#
# Usage: tools/personal_release.sh
# Run from the repo root on branch local/ebird-widget-ntfy with a clean tree.

set -euo pipefail

BRANCH="local/ebird-widget-ntfy"
REPO="dk1/birdnet-live-app"

current_branch=$(git branch --show-current)
if [[ "$current_branch" != "$BRANCH" ]]; then
  echo "error: must be on $BRANCH (currently on $current_branch)" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree not clean — commit or stash first" >&2
  exit 1
fi

echo "==> fetching upstream/main"
git fetch upstream main

echo "==> merging upstream/main"
git merge upstream/main --no-edit

echo "==> regenerating localizations"
flutter gen-l10n

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "==> building debug apk"
flutter build apk --debug

version=$(grep '^version:' pubspec.yaml | sed 's/version: //')
tag="v${version}"

echo "==> tagging $tag"
git push origin HEAD:refs/tags/"$tag"

echo "==> creating GitHub release"
gh release create "$tag" \
  build/app/outputs/flutter-apk/app-debug.apk \
  --repo "$REPO" \
  --title "Personal build $tag" \
  --notes "Debug build of $BRANCH (eBird life list + lifer alerts, Quick Listen widget, ntfy push), rebased on upstream main as of this build. Not a public release — for personal/family testing while PR #170 is pending review."

echo "==> done: https://github.com/$REPO/releases/tag/$tag"
