#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/specai-specs.sh resolve YYYYMMDD-slug
  bash scripts/specai-specs.sh validate YYYYMMDD-slug [repo-root]
EOF
}

die() {
  echo "specai-specs: $*" >&2
  exit 1
}

validate_feature_id() {
  local feature_id="$1"
  [[ "$feature_id" =~ ^[0-9]{8}-[a-z0-9]+([a-z0-9-]*[a-z0-9])?$ ]] || \
    die "invalid Feature ID: $feature_id"

  local year="${feature_id:0:4}"
  local month="${feature_id:4:2}"
  local day="${feature_id:6:2}"
  local max_day
  case "$month" in
    01|03|05|07|08|10|12) max_day=31 ;;
    04|06|09|11) max_day=30 ;;
    02)
      if (( (10#$year % 400 == 0) || (10#$year % 4 == 0 && 10#$year % 100 != 0) )); then
        max_day=29
      else
        max_day=28
      fi
      ;;
    *) die "invalid month in Feature ID: $feature_id" ;;
  esac
  (( 10#$day >= 1 && 10#$day <= max_day )) || die "invalid day in Feature ID: $feature_id"
}

print_paths() {
  local feature_id="$1"
  local active_dir="docs/specai/$feature_id"
  local archive_dir="docs/specai/feature/$feature_id"

  printf 'feature_id=%s\n' "$feature_id"
  printf 'active_dir=%s\n' "$active_dir"
  printf 'archive_dir=%s\n' "$archive_dir"
  printf 'prd=%s/%s-prd.md\n' "$active_dir" "$feature_id"
  printf 'spec=%s/%s-spec.md\n' "$active_dir" "$feature_id"
  printf 'designs=%s/%s-designs.md\n' "$active_dir" "$feature_id"
  printf 'plan=%s/%s-plan.md\n' "$active_dir" "$feature_id"
  printf 'tasks=%s/%s-tasks.md\n' "$active_dir" "$feature_id"
  printf 'verify=%s/%s-verify.md\n' "$active_dir" "$feature_id"
}

validate_artifacts() {
  local feature_id="$1"
  local repo_root="$2"
  local active_dir="$repo_root/docs/specai/$feature_id"
  local archive_dir="$repo_root/docs/specai/feature/$feature_id"
  local feature_dir

  local active_exists=false
  local archive_exists=false
  [[ -e "$active_dir" || -L "$active_dir" ]] && active_exists=true
  [[ -e "$archive_dir" || -L "$archive_dir" ]] && archive_exists=true

  if [[ "$active_exists" == true && "$archive_exists" == true ]]; then
    die "active and archive destinations both exist for $feature_id"
  elif [[ "$active_exists" == true && ! -d "$active_dir" ]]; then
    die "active destination is not a directory for $feature_id"
  elif [[ "$archive_exists" == true && ! -d "$archive_dir" ]]; then
    die "archive destination is not a directory for $feature_id"
  elif [[ -d "$active_dir" ]]; then
    feature_dir="$active_dir"
  elif [[ -d "$archive_dir" ]]; then
    feature_dir="$archive_dir"
  else
    die "feature directory not found for $feature_id"
  fi

  local suffix
  for suffix in prd spec designs plan tasks verify; do
    [[ -f "$feature_dir/$feature_id-$suffix.md" ]] || \
      die "missing artifact: $feature_dir/$feature_id-$suffix.md"
  done

  local file
  while IFS= read -r file; do
    case "$(basename "$file")" in
      "$feature_id-prd.md"|"$feature_id-spec.md"|"$feature_id-designs.md"|\
      "$feature_id-plan.md"|"$feature_id-tasks.md"|"$feature_id-verify.md") ;;
      *) die "artifact does not use Feature ID prefix: $file" ;;
    esac
  done < <(find "$feature_dir" -maxdepth 1 -type f -name '*.md' -print)

  printf 'feature artifacts valid: %s\n' "$feature_id"
}

command_name="${1:-}"
feature_id="${2:-}"

case "$command_name" in
  resolve)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    validate_feature_id "$feature_id"
    print_paths "$feature_id"
    ;;
  validate)
    [[ $# -le 3 && $# -ge 2 ]] || { usage; exit 2; }
    validate_feature_id "$feature_id"
    validate_artifacts "$feature_id" "${3:-.}"
    ;;
  *)
    usage
    exit 2
    ;;
esac
