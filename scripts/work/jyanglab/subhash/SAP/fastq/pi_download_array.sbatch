#!/bin/bash
#SBATCH --job-name=pi_fastq
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --partition=jclarke,batch,guest
#SBATCH --output=logs/pi_%A_%a.out
#SBATCH --error=logs/pi_%A_%a.err
#SBATCH --array=0-399

set -euo pipefail

if command -v ml >/dev/null 2>&1; then
  ml SRAtoolkit || true
else
  module load sratoolkit || true
fi

PI_LIST_FILE="${PI_LIST_FILE:-unique_pis.txt}"
TABLE_FILE="${TABLE_FILE:-pi_run_map.tsv}"
SCRIPT="${SCRIPT:-$(pwd)/download_pi_fastqs.sh}"
RUN_DIR_BASE="${RUN_DIR_BASE:-runs}"
OUT_DIR_BASE="${OUT_DIR_BASE:-pis}"

if [[ ! -f "$PI_LIST_FILE" ]]; then
  echo "Missing PI list file: $PI_LIST_FILE" >&2
  exit 1
fi

if [[ ! -f "$TABLE_FILE" ]]; then
  echo "Missing mapping table: $TABLE_FILE" >&2
  exit 1
fi

if [[ ! -x "$SCRIPT" ]]; then
  echo "Download script not executable: $SCRIPT" >&2
  exit 1
fi

INDEX=$((SLURM_ARRAY_TASK_ID + 1))
PI=$(sed -n "${INDEX}p" "$PI_LIST_FILE")

if [[ -z "$PI" ]]; then
  echo "No PI found at index $INDEX" >&2
  exit 1
fi

echo "[$(date)] Processing PI $PI"
TMP_TABLE=$(mktemp)
trap 'rm -f "$TMP_TABLE"' EXIT

{ head -n 1 "$TABLE_FILE"; awk -v pi="$PI" '$1==pi' "$TABLE_FILE"; } > "$TMP_TABLE"

RUN_DIR="${RUN_DIR_BASE}/${PI}"
OUT_DIR="${OUT_DIR_BASE}"
mkdir -p "$RUN_DIR" "$OUT_DIR"

FASTQ_DUMP=${FASTQ_DUMP:-fastq-dump} RUN_DIR="$RUN_DIR" OUTPUT_DIR="$OUT_DIR" "$SCRIPT" "$TMP_TABLE"

echo "[$(date)] Completed PI $PI"
