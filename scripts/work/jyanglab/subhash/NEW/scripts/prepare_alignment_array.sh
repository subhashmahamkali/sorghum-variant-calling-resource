#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/work/jyanglab/subhash/NEW}"
TRIM_DIR="${TRIM_DIR:-$ROOT_DIR/1.fastq/trim}"
ALIGN_DIR="${ALIGN_DIR:-$ROOT_DIR/2.alignment}"
LOG_DIR="${LOG_DIR:-$ALIGN_DIR/logs}"
LIST_FILE="${LIST_FILE:-$ALIGN_DIR/alignment_samples.list}"
MASTER_SAMPLE_LIST="${MASTER_SAMPLE_LIST:-/work/jyanglab/subhash/scripts/samples_unpaired.txt}"

mkdir -p "$ALIGN_DIR" "$LOG_DIR"

TMP_LIST="${LIST_FILE}.tmp"

if [[ -f "$MASTER_SAMPLE_LIST" ]]; then
  cp "$MASTER_SAMPLE_LIST" "$TMP_LIST"
else
  find "$TRIM_DIR" -maxdepth 1 -type f -name '*_fastp.fq.gz' | sort \
    | sed 's#.*/##' | sed 's/_fastp\.fq\.gz$//' > "$TMP_LIST"
fi

COUNT=$(wc -l < "$TMP_LIST" | tr -d ' ')
if [[ "$COUNT" -eq 0 ]]; then
  rm -f "$TMP_LIST"
  echo "No *_fastp.fq.gz files found in $TRIM_DIR" >&2
  exit 1
fi

mv "$TMP_LIST" "$LIST_FILE"

cat <<EOM
Prepared alignment sample list: $LIST_FILE
Total samples: $COUNT
Use this count when submitting the alignment array.
EOM
