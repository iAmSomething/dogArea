#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/auth_smtp_evidence_bundle.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/archive_manual_evidence_pack.sh widget <bundle-dir> [--output <zip-path>] [--staging-dir <dir>]
  bash scripts/archive_manual_evidence_pack.sh auth-smtp <bundle-dir> [--output <zip-path>] [--staging-dir <dir>]
USAGE
}

die() {
  printf 'archive_manual_evidence_pack.sh: %s\n' "$*" >&2
  exit 1
}

surface_default_archive_path() {
  case "$1" in
    widget) printf '.codex_tmp/widget-real-device-evidence-export.zip' ;;
    auth-smtp) printf '.codex_tmp/auth-smtp-evidence-export.zip' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_primary_issue() {
  case "$1" in
    widget) printf '#731' ;;
    auth-smtp) printf '#482' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_related_issues() {
  case "$1" in
    widget) printf '#617, #692' ;;
    auth-smtp) printf 'none' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_bundle_label() {
  case "$1" in
    widget) printf 'widget real-device evidence bundle' ;;
    auth-smtp) printf 'auth smtp rollout evidence bundle' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_closure_output_name() {
  case "$1" in
    widget) printf 'widget-closure-comment.md' ;;
    auth-smtp) printf 'auth-smtp-closure-comment.md' ;;
    *) die "unsupported surface: $1" ;;
  esac
}

surface_manifest_name() {
  printf 'MANIFEST.md'
}

surface_checksum_name() {
  printf 'SHA256SUMS'
}

write_export_readme() {
  local surface="$1"
  local bundle_path="$2"
  local archive_path="$3"
  local export_root="$4"
  local closure_name="$5"

  cat > "$export_root/README.md" <<EOF
# Manual Evidence Export Bundle

- Surface: $surface
- Bundle Label: $(surface_bundle_label "$surface")
- Primary Issue: $(surface_primary_issue "$surface")
- Related Issues: $(surface_related_issues "$surface")
- Source Bundle: $bundle_path
- Closure Preview: $closure_name
- Archive Path: $archive_path

## Contents
- README.md
- $closure_name
- bundle/
EOF
}

write_manifest() {
  local surface="$1"
  local bundle_path="$2"
  local export_root="$3"
  local closure_name="$4"
  local manifest_path="$export_root/$(surface_manifest_name)"
  local file_count asset_count

  file_count="$(find "$export_root/bundle" -type f | wc -l | tr -d ' ')"
  asset_count="$(find "$export_root/bundle/assets" -type f 2>/dev/null | wc -l | tr -d ' ')"

  {
    printf '# Manual Evidence Export Manifest\n\n'
    printf -- '- Surface: %s\n' "$surface"
    printf -- '- Bundle Label: %s\n' "$(surface_bundle_label "$surface")"
    printf -- '- Primary Issue: %s\n' "$(surface_primary_issue "$surface")"
    printf -- '- Related Issues: %s\n' "$(surface_related_issues "$surface")"
    printf -- '- Source Bundle: %s\n' "$bundle_path"
    printf -- '- Closure Preview: %s\n' "$closure_name"
    printf -- '- Bundle File Count: %s\n' "$file_count"
    printf -- '- Bundle Asset Count: %s\n\n' "$asset_count"
    printf '## Export Files\n'
    printf -- '- README.md\n'
    printf -- '- %s\n' "$closure_name"
    printf -- '- %s\n\n' "$(surface_manifest_name)"
    printf '## Bundle Files\n'
    (
      cd "$export_root/bundle"
      find . -type f | sort | sed 's#^\./#- #'
    )
  } > "$manifest_path"
}

write_checksums() {
  local export_root="$1"
  local closure_name="$2"
  local checksum_path="$export_root/$(surface_checksum_name)"

  (
    cd "$export_root"
    shasum -a 256 "README.md"
    shasum -a 256 "$closure_name"
    shasum -a 256 "$(surface_manifest_name)"
    find bundle -type f | sort | while IFS= read -r file; do
      shasum -a 256 "$file"
    done
  ) > "$checksum_path"
}

surface="${1:-}"
bundle_dir="${2:-}"
shift $(( $# >= 2 ? 2 : $# ))

[[ -n "$surface" && -n "$bundle_dir" ]] || {
  usage
  exit 1
}

archive_path=""
staging_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      [[ $# -ge 2 ]] || die "--output requires a path"
      archive_path="$2"
      shift 2
      ;;
    --staging-dir)
      [[ $# -ge 2 ]] || die "--staging-dir requires a path"
      staging_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$surface" in
  widget|auth-smtp) ;;
  *) usage; exit 1 ;;
esac

[[ -d "$bundle_dir" ]] || die "bundle dir does not exist: $bundle_dir"

archive_path="${archive_path:-$(surface_default_archive_path "$surface")}"
mkdir -p "$(dirname "$archive_path")"
archive_abs="$(cd "$(dirname "$archive_path")" && pwd)/$(basename "$archive_path")"

bash scripts/validate_manual_evidence_pack.sh "$surface" "$bundle_dir" >/dev/null

cleanup() {
  if [[ -n "${temp_staging_dir:-}" && -d "${temp_staging_dir:-}" ]]; then
    rm -rf "$temp_staging_dir"
  fi
}

if [[ -n "$staging_dir" ]]; then
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"
  export_root="$staging_dir"
else
  temp_staging_dir="$(mktemp -d)"
  trap cleanup EXIT
  export_root="$temp_staging_dir"
fi

mkdir -p "$export_root/bundle"
cp -R "$bundle_dir"/. "$export_root/bundle/"

closure_name="$(surface_closure_output_name "$surface")"
bash scripts/render_closure_comment_from_evidence.sh "$surface" "$bundle_dir" --output "$export_root/$closure_name" >/dev/null
write_export_readme "$surface" "$bundle_dir" "$archive_abs" "$export_root" "$closure_name"
write_manifest "$surface" "$bundle_dir" "$export_root" "$closure_name"
write_checksums "$export_root" "$closure_name"

rm -f "$archive_abs"
(cd "$export_root" && zip -qr "$archive_abs" README.md "$closure_name" "$(surface_manifest_name)" "$(surface_checksum_name)" bundle)

printf 'WROTE %s\n' "$archive_abs"
