#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.tsv"
TOP="${ANDROID_BUILD_TOP:-$PWD}"
MODE="apply"
CATEGORIES=()

usage() {
  cat <<'EOF'
Usage: ./ofox_patches/apply.sh [option]

Default: apply every patch in manifest order.

Options:
  --check              Check repositories and patch applicability
  --list               List patches
  --category NAME      Apply/check one category; may be repeated
  --top PATH           Android source root
  -h, --help           Show help

Categories: build, recovery-layout, adb-sideload, hardware, ui, compat, ota
EOF
}

while (($#)); do
  case "$1" in
    --check) MODE="check" ;;
    --list) MODE="list" ;;
    --category)
      [[ $# -ge 2 ]] || { echo "ERROR: --category requires a name"; exit 2; }
      CATEGORIES+=("$2"); shift ;;
    --top)
      [[ $# -ge 2 ]] || { echo "ERROR: --top requires a path"; exit 2; }
      TOP="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

selected() {
  local category="$1"
  ((${#CATEGORIES[@]} == 0)) && return 0
  local c
  for c in "${CATEGORIES[@]}"; do
    [[ "$c" == "$category" ]] && return 0
  done
  return 1
}

if [[ "$MODE" == "list" ]]; then
  printf '%-5s %-16s %-28s %s\n' 'No.' 'Category' 'Repository' 'Patch'
  while IFS=$'\t' read -r order category repo patch sha description; do
    [[ -z "$order" || "$order" == \#* ]] && continue
    selected "$category" || continue
    printf '%-5s %-16s %-28s %s\n' "$order" "$category" "$repo" "$(basename "$patch")"
  done < "$MANIFEST"
  exit 0
fi

TOP="$(cd -- "$TOP" 2>/dev/null && pwd)" || { echo "ERROR: source root not found"; exit 1; }
[[ -d "$TOP/.repo" ]] || { echo "ERROR: $TOP does not look like an Android source root"; exit 1; }

declare -A CHECKED=()
while IFS=$'\t' read -r order category repo patch_rel sha description; do
  [[ -z "$order" || "$order" == \#* ]] && continue
  selected "$category" || continue

  patch="$SCRIPT_DIR/$patch_rel"
  [[ -f "$patch" ]] || { echo "ERROR: missing patch: $patch_rel"; exit 1; }
  actual_sha="$(sha256sum "$patch" | awk '{print $1}')"
  [[ "$actual_sha" == "$sha" ]] || { echo "ERROR: checksum mismatch: $patch_rel"; exit 1; }

  if [[ -z "${CHECKED[$repo]:-}" ]]; then
    [[ -d "$TOP/$repo/.git" || -f "$TOP/$repo/.git" ]] || { echo "ERROR: missing Git repository: $repo"; exit 1; }
    CHECKED[$repo]=1
  fi

  if git -C "$TOP/$repo" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "SKIP already applied: [$category] $repo/$(basename "$patch")"
    continue
  fi

  if ! git -C "$TOP/$repo" apply --check "$patch" >/dev/null 2>&1; then
    echo "ERROR: patch does not apply cleanly: [$category] $repo/$(basename "$patch")"
    exit 1
  fi

  if [[ "$MODE" == "check" ]]; then
    echo "READY: [$category] $repo/$(basename "$patch")"
  else
    echo "APPLY: [$category] $repo/$(basename "$patch")"
    git -C "$TOP/$repo" apply "$patch"
  fi
done < "$MANIFEST"

if [[ "$MODE" == "check" ]]; then
  echo "Check complete."
else
  echo "All selected patches applied. Review changes with: repo status"
fi
