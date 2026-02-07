#!/bin/bash
# validate-domain-configs.sh
# Story 3.2: Domain Configuration Engine
#
# Validates that iOS Bundle domain configs are identical to canonical source.
# Exits non-zero on mismatch — suitable for CI/CD pipelines.
#
# Usage:
#   ./scripts/validate-domain-configs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$PROJECT_ROOT/CoachMe/Supabase/supabase/functions/_shared/domain-configs"
TARGET_DIR="$PROJECT_ROOT/CoachMe/CoachMe/Resources/DomainConfigs"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "FAIL: Canonical source directory not found: $SOURCE_DIR"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "FAIL: iOS config directory not found: $TARGET_DIR"
  exit 1
fi

ERRORS=0

# Check all canonical configs exist in iOS
for src_file in "$SOURCE_DIR"/*.json; do
  filename=$(basename "$src_file")
  target_file="$TARGET_DIR/$filename"

  if [ ! -f "$target_file" ]; then
    echo "FAIL: Missing in iOS Bundle: $filename"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  if ! cmp -s "$src_file" "$target_file"; then
    echo "FAIL: Content mismatch: $filename"
    diff "$src_file" "$target_file" || true
    ERRORS=$((ERRORS + 1))
  fi
done

# Check no extra configs in iOS that don't exist in canonical
for target_file in "$TARGET_DIR"/*.json; do
  filename=$(basename "$target_file")
  if [ ! -f "$SOURCE_DIR/$filename" ]; then
    echo "FAIL: Extra file in iOS Bundle (not in canonical source): $filename"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$ERRORS" -eq 0 ]; then
  echo "PASS: All domain configs are in sync."
  exit 0
else
  echo "FAIL: $ERRORS validation error(s) found."
  echo "Run ./scripts/sync-domain-configs.sh to fix."
  exit 1
fi
