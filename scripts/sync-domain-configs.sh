#!/bin/bash
# sync-domain-configs.sh
# Story 3.2: Domain Configuration Engine
#
# Copies all JSON domain config files from the canonical source
# (_shared/domain-configs/) to the iOS Bundle (Resources/DomainConfigs/).
#
# Usage:
#   ./scripts/sync-domain-configs.sh
#   Or as an Xcode "Run Script" build phase.
#
# The canonical source is:
#   CoachMe/Supabase/supabase/functions/_shared/domain-configs/
#
# The iOS copy is:
#   CoachMe/CoachMe/Resources/DomainConfigs/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$PROJECT_ROOT/CoachMe/Supabase/supabase/functions/_shared/domain-configs"
TARGET_DIR="$PROJECT_ROOT/CoachMe/CoachMe/Resources/DomainConfigs"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source directory not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Track changes
CHANGED=0

# Enable nullglob so globs with no matches expand to nothing
shopt -s nullglob

for src_file in "$SOURCE_DIR"/*.json; do
  filename=$(basename "$src_file")
  target_file="$TARGET_DIR/$filename"

  if [ -f "$target_file" ]; then
    if ! diff -q "$src_file" "$target_file" > /dev/null 2>&1; then
      echo "UPDATED: $filename"
      diff "$src_file" "$target_file" || true
      CHANGED=$((CHANGED + 1))
    fi
  else
    echo "NEW: $filename"
    CHANGED=$((CHANGED + 1))
  fi

  cp "$src_file" "$target_file"
done

# Remove any iOS configs that no longer exist in canonical source
for target_file in "$TARGET_DIR"/*.json; do
  filename=$(basename "$target_file")
  if [ ! -f "$SOURCE_DIR/$filename" ]; then
    echo "REMOVED: $filename (no longer in canonical source)"
    rm "$target_file"
    CHANGED=$((CHANGED + 1))
  fi
done

shopt -u nullglob

if [ "$CHANGED" -eq 0 ]; then
  echo "Domain configs in sync — no changes needed."
else
  echo "Synced $CHANGED domain config file(s)."
fi

# Touch stamp file for Xcode dependency tracking
if [ -n "${DERIVED_FILE_DIR:-}" ]; then
  touch "${DERIVED_FILE_DIR}/sync-domain-configs.stamp"
fi
