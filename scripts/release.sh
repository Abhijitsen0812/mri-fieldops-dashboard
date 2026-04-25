#!/usr/bin/env bash
# release.sh — snapshot a release into releases/v<version>/
#
# What it does (and only this — does NOT commit, tag, or push):
#   1. Validates the working tree is clean and on main
#   2. Validates VERSION matches the requested version
#   3. Validates CHANGELOG.md has a heading for the version
#   4. Validates index.html's window.APP_VERSION matches
#   5. Snapshots index.html to releases/v<version>/index.html
#   6. Writes releases/v<version>/MANIFEST.txt with size + sha256
#
# After this script succeeds, run the commit/tag/push steps from RELEASING.md.
#
# Usage:
#   ./scripts/release.sh 1.1.0

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>     (e.g. $0 1.1.0)" >&2
  exit 64
fi

VERSION="$1"
TAG="v${VERSION}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$*"; }

# 1. version format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  red "Version '$VERSION' is not semver (X.Y.Z)."; exit 65
fi

# 2. on main
# (Working tree may have uncommitted version-bump edits — release.sh
# is designed to run AFTER you bump VERSION/CHANGELOG/index.html and
# BEFORE you commit. The version-match guards below verify those
# bumps actually happened.)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  red "Must be on 'main' (currently on '$BRANCH')."; exit 1
fi

# 3. tag does not already exist
if git rev-parse "$TAG" >/dev/null 2>&1; then
  red "Tag $TAG already exists."; exit 1
fi

# 4. VERSION file matches
if [[ ! -f VERSION ]]; then
  red "VERSION file not found."; exit 1
fi
FILE_VERSION="$(tr -d '[:space:]' < VERSION)"
if [[ "$FILE_VERSION" != "$VERSION" ]]; then
  red "VERSION file is '$FILE_VERSION' but you asked to release '$VERSION'."
  red "Update VERSION first."; exit 1
fi

# 5. CHANGELOG entry exists
if ! grep -qE "^## \[${VERSION}\]" CHANGELOG.md; then
  red "CHANGELOG.md has no '## [${VERSION}]' entry. Add one before releasing."; exit 1
fi

# 6. window.APP_VERSION matches
if ! grep -qE "window\.APP_VERSION\s*=\s*'${VERSION}'" index.html; then
  red "index.html does not have window.APP_VERSION = '${VERSION}'. Update it."; exit 1
fi

# 7. snapshot
DEST="releases/${TAG}"
if [[ -e "$DEST" ]]; then
  red "$DEST already exists. Refusing to overwrite."; exit 1
fi
mkdir -p "$DEST"
cp index.html "$DEST/index.html"

# 8. manifest
SHA256="$(shasum -a 256 "$DEST/index.html" | awk '{print $1}')"
SIZE="$(wc -c < "$DEST/index.html" | tr -d ' ')"
DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HEAD_COMMIT="$(git rev-parse HEAD)"
HEAD_SHORT="$(git rev-parse --short HEAD)"

cat > "$DEST/MANIFEST.txt" <<EOF
release:    ${TAG}
date:       $(date -u +%Y-%m-%d)
file:       index.html
size_bytes: ${SIZE}
sha256:     ${SHA256}
snapshotted_at_utc: ${DATE_UTC}
parent_commit:       ${HEAD_COMMIT}
parent_commit_short: ${HEAD_SHORT}
prod_url:    https://3imedtech.github.io/mri-fieldops-dashboard/
staging_url: https://3imedtech.github.io/mri-fieldops-dashboard/staging/

# After "git push origin main ${TAG}", verify prod by:
#   curl -sI https://3imedtech.github.io/mri-fieldops-dashboard/index.html
# In the browser console:
#   window.APP_VERSION  // '${VERSION}'
EOF

green "Snapshot written to $DEST/"
echo
echo "Next steps (from RELEASING.md):"
echo "  git add VERSION CHANGELOG.md index.html $DEST"
echo "  git commit -m \"release: ${TAG}\""
echo "  git tag -a ${TAG} -m \"Release ${TAG}\""
echo "  git push origin main ${TAG}"
