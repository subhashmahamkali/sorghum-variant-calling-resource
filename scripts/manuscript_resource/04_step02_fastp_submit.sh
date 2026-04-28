#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

PREP="$PIPELINE_SCRIPTS_ROOT/02_fastp_trim/prepare_fastp_unpaired_array.sh"
ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/02_fastp_trim/fastp_unpaired_array.sh"
require_file "$PREP"
require_file "$ARRAY_SCRIPT"

ROOT_DIR="$NEW_ROOT/1.fastq"
OUT_DIR="$ROOT_DIR/trim"
REPORT_DIR="$OUT_DIR/reports"
LOG_DIR="$OUT_DIR/logs"
LIST_FILE="$OUT_DIR/unpaired_fastq.list"
MAX_CONCURRENT="${MAX_CONCURRENT:-16}"

log "Preparing Step 02 list"
ROOT_DIR="$ROOT_DIR" OUT_DIR="$OUT_DIR" REPORT_DIR="$REPORT_DIR" LOG_DIR="$LOG_DIR" LIST_FILE="$LIST_FILE" "$PREP"

count="$(line_count "$LIST_FILE")"
log "Submitting Step 02 fastp array for $count samples"
sbatch --array="1-${count}%${MAX_CONCURRENT}" \
  --export=ALL,ROOT_DIR="$ROOT_DIR",OUT_DIR="$OUT_DIR",REPORT_DIR="$REPORT_DIR",LOG_DIR="$LOG_DIR",LIST_FILE="$LIST_FILE" \
  "$ARRAY_SCRIPT"
