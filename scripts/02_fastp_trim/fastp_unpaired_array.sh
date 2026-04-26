#!/usr/bin/env bash
#SBATCH --job-name=fastp_unpaired
#SBATCH --partition=jclarke,batch,guest
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --export=ALL
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-${SLURM_SUBMIT_DIR:-$SCRIPT_DIR}}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/trim}"
REPORT_DIR="${REPORT_DIR:-$OUT_DIR/reports}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/logs}"
LIST_FILE="${LIST_FILE:-$OUT_DIR/unpaired_fastq.list}"
PER_FILE_THREADS="${PER_FILE_THREADS:-4}"

if [[ -z "${FASTP_BIN:-}" ]]; then
  MODULE_TO_LOAD="${FASTP_MODULE:-fastp/0.23}"
  if [[ -n "$MODULE_TO_LOAD" ]]; then
    if [[ -f /etc/profile.d/modules.sh ]]; then
      # shellcheck source=/etc/profile.d/modules.sh
      source /etc/profile.d/modules.sh
    fi
    if command -v module >/dev/null 2>&1; then
      module load "$MODULE_TO_LOAD"
    fi
  fi
fi

FASTP_BIN="${FASTP_BIN:-fastp}"

mkdir -p "$OUT_DIR" "$REPORT_DIR" "$LOG_DIR"

TASK_ID="${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID must be set (use sbatch --array)}"
INPUT_FILE="$(sed -n "${TASK_ID}p" "$LIST_FILE" || true)"

if [[ -z "$INPUT_FILE" ]]; then
  echo "No entry for task $TASK_ID in $LIST_FILE" >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input FASTQ not found: $INPUT_FILE" >&2
  exit 1
fi

sample="$(basename "$INPUT_FILE")"
sample="${sample%_unpaired.fq.gz}"

OUT_FASTQ="$OUT_DIR/${sample}_fastp.fq.gz"
HTML_REPORT="$REPORT_DIR/${sample}.html"
JSON_REPORT="$REPORT_DIR/${sample}.json"
LOG_FILE="$LOG_DIR/${sample}.log"

{
  echo "=== $(date -u +'%Y-%m-%dT%H:%M:%SZ') | fastp trimming started ==="
  echo "Task ID : $TASK_ID"
  echo "Input   : $INPUT_FILE"
  echo "Output  : $OUT_FASTQ"
  echo "Reports : $HTML_REPORT | $JSON_REPORT"
  "$FASTP_BIN" --in1 "$INPUT_FILE" --out1 "$OUT_FASTQ" \
    --thread "$PER_FILE_THREADS" --html "$HTML_REPORT" --json "$JSON_REPORT"
  echo "=== $(date -u +'%Y-%m-%dT%H:%M:%SZ') | fastp trimming finished ==="
} >"$LOG_FILE" 2>&1

echo "fastp completed for $INPUT_FILE"
