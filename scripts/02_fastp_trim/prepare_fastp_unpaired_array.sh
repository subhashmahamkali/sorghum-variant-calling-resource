#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/trim}"
REPORT_DIR="${REPORT_DIR:-$OUT_DIR/reports}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/logs}"
SLURM_LOG_DIR="${SLURM_LOG_DIR:-$OUT_DIR/slurm_logs}"
LIST_FILE="${LIST_FILE:-$OUT_DIR/unpaired_fastq.list}"

mkdir -p "$OUT_DIR" "$REPORT_DIR" "$LOG_DIR" "$SLURM_LOG_DIR"

TMP_LIST="${LIST_FILE}.tmp"
find "$ROOT_DIR" -type f -name '*_unpaired.fq.gz' -not -path "$OUT_DIR/*" | sort > "$TMP_LIST"

COUNT=$(wc -l < "$TMP_LIST" | tr -d ' ')
if [[ "$COUNT" -eq 0 ]]; then
  rm -f "$TMP_LIST"
  echo "No *_unpaired.fq.gz files found under $ROOT_DIR" >&2
  exit 1
fi

mv "$TMP_LIST" "$LIST_FILE"

cat <<EOM
Prepared list file: $LIST_FILE
Total unpaired FASTQs: $COUNT
Recommended sbatch command:
  sbatch --array=1-${COUNT}%${MAX_CONCURRENT:-16} fastp_unpaired_array.sh
Set FASTP_BIN if fastp is not on PATH.
EOM
