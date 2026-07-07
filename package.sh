#!/usr/bin/env bash
#
# Packages Notific into a CurseForge-ready zip under output/.
#
#   - reads the version from Notific.toc
#   - regenerates CHANGELOG.md from git commit history
#   - bundles the addon files under a top-level Notific/ folder
#
# CurseForge expects the zip to contain a single top-level folder matching the
# addon name, so the archive is built as output/Notific/<files> then zipped.
set -euo pipefail

cd "$(dirname "$0")"

ADDON="Notific"
TOC="$ADDON.toc"

# Files shipped inside the addon folder.
FILES=("$ADDON.lua" "$TOC" "LICENSE" "README.md" "CHANGELOG.md")

# --- Version from the TOC ---------------------------------------------------
VERSION=$(grep -m1 '^## Version:' "$TOC" | sed -E 's/^## Version:[[:space:]]*//' | tr -d '[:space:]' || true)
if [ -z "$VERSION" ]; then
  echo "error: could not read '## Version:' from $TOC" >&2
  exit 1
fi

# --- Changelog from git -----------------------------------------------------
# Prints a "## [label] - date" section listing commit subjects in a git range,
# or nothing when the range has no commits.
emit_section() {
  local body
  body=$(git log --no-merges --pretty=format:'- %s (%h)' $3 2>/dev/null || true)
  [ -z "$body" ] && return 0
  printf '## [%s] - %s\n\n%s\n\n' "$1" "$2" "$body"
}

generate_changelog() {
  local tags=()
  while IFS= read -r t; do
    [ -n "$t" ] && tags+=("$t")
  done < <(git tag --sort=creatordate)
  local n=${#tags[@]}

  {
    printf '# Changelog\n\n'
    printf 'All notable changes to %s, generated from git commit history.\n\n' "$ADDON"

    # Current toc version: commits since the most recent tag (or all commits
    # when the repo has no tags yet).
    local cur_range="HEAD"
    if [ "$n" -gt 0 ]; then
      cur_range="${tags[$((n - 1))]}..HEAD"
    fi
    emit_section "$VERSION" "$(date +%F)" "$cur_range"

    # One section per tag, newest first, each covering commits since the
    # previous tag.
    local i=$((n - 1))
    while [ "$i" -ge 0 ]; do
      local tag="${tags[$i]}" range label tdate
      if [ "$i" -gt 0 ]; then
        range="${tags[$((i - 1))]}..$tag"
      else
        range="$tag"
      fi
      label=$(printf '%s' "$tag" | sed 's/^v//')
      tdate=$(git log -1 --format=%ad --date=short "$tag")
      emit_section "$label" "$tdate" "$range"
      i=$((i - 1))
    done
  } >CHANGELOG.md
}

generate_changelog
echo "Updated CHANGELOG.md"

# --- Package ----------------------------------------------------------------
OUT="output"
BUILD="$OUT/$ADDON"
ZIP="$ADDON-$VERSION.zip"

rm -rf "$BUILD"
mkdir -p "$BUILD"

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    cp "$f" "$BUILD/"
  else
    echo "warning: skipping missing file '$f'" >&2
  fi
done

rm -f "$OUT/$ZIP"
(cd "$OUT" && zip -r -q "$ZIP" "$ADDON")
rm -rf "$BUILD"

echo "Created $OUT/$ZIP"
