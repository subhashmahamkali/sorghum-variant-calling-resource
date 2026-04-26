#!/usr/bin/env bash
set -euo pipefail

WORK="${WORK:-/mnt/nrdstor/jyanglab/subhash/sorghum_WGS_JS}"
FASTQ_ROOT="${FASTQ_ROOT:-/work/jyanglab/subhash/NEW/1.fastq}"
LOG_DIR="${LOG_DIR:-/work/jyanglab/subhash/NEW/1.fastq/logs}"
LIST="${LIST:-$FASTQ_ROOT/piscbt_crams.list}"
SCRIPT="${SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/02_cram_to_fastq_array.sh}"
MAX_DEPTH="${MAX_DEPTH:-4}"

mkdir -p "$FASTQ_ROOT" "$LOG_DIR"

find "$WORK" -maxdepth "$MAX_DEPTH" -type f -name '*.cram' \
  | grep -E '/(PI|SC|unknown|BT)[^/]*/[^/]+\.cram$' \
  | grep -v '_unmatched\.cram$' \
  | sort > "$LIST"

COUNT=$(wc -l < "$LIST" | tr -d ' ')
if [[ "$COUNT" -eq 0 ]]; then
  echo "No CRAM files found under $WORK" >&2
  exit 1
fi

echo "Prepared CRAM list: $LIST"
echo "CRAM files: $COUNT"

while read -r CRAM; do
  SAMPLE=$(basename "${CRAM%.cram}")
  sbatch --export=ALL,CRAM="$CRAM",SAMPLE="$SAMPLE",FASTQ_ROOT="$FASTQ_ROOT",LOG_DIR="$LOG_DIR" "$SCRIPT"
done < "$LIST"
