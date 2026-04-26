#!/usr/bin/env bash
set -euo pipefail

ALIGN_DIR="${ALIGN_DIR:-/work/jyanglab/subhash/NEW/2.alignment}"
DRY_RUN=1

usage() {
  cat <<EOM
Usage: $0 [--execute]
  --execute    Perform deletions instead of listing actions (default is dry-run)

Targets: removes *.srt.bam, *.srt.bam.bai, *.flagstat.txt inside sample subdirectories of $ALIGN_DIR.
Logs directory is left untouched.
EOM
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)
      DRY_RUN=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$ALIGN_DIR" ]]; then
  echo "Alignment directory not found: $ALIGN_DIR" >&2
  exit 1
fi

shopt -s nullglob
TARGETS=()
for sample_dir in "$ALIGN_DIR"/*/; do
  [[ "$(basename "$sample_dir")" == logs ]] && continue
  TARGETS+=("${sample_dir}"*.srt.bam)
  TARGETS+=("${sample_dir}"*.srt.bam.bai)
  TARGETS+=("${sample_dir}"*.flagstat.txt)
done
shopt -u nullglob

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No alignment outputs found under $ALIGN_DIR"
  exit 0
fi

echo "Files to remove:${DRY_RUN:+ (dry run)}"
printf '  %s\n' "${TARGETS[@]}"

if [[ "$DRY_RUN" -eq 0 ]]; then
  rm -f "${TARGETS[@]}"
  echo "Removal complete."
else
  echo "Re-run with --execute to delete these files."
fi
