#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

PREP="$PIPELINE_SCRIPTS_ROOT/03_bwa_mem2_alignment/prepare_alignment_array.sh"
ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/03_bwa_mem2_alignment/alignment_unpaired_array.sh"
require_file "$PREP"
require_file "$ARRAY_SCRIPT"

ROOT_DIR="$NEW_ROOT"
TRIM_DIR="$ROOT_DIR/1.fastq/trim"
ALIGN_DIR="$ROOT_DIR/2.alignment"
LOG_DIR="$ALIGN_DIR/logs"
LIST_FILE="$ALIGN_DIR/alignment_samples.list"
MAX_CONCURRENT="${MAX_CONCURRENT:-24}"

log "Preparing Step 03 alignment list"
ROOT_DIR="$ROOT_DIR" TRIM_DIR="$TRIM_DIR" ALIGN_DIR="$ALIGN_DIR" LOG_DIR="$LOG_DIR" LIST_FILE="$LIST_FILE" "$PREP"

count="$(line_count "$LIST_FILE")"
log "Submitting Step 03 alignment array for $count samples"
sbatch --array="1-${count}%${MAX_CONCURRENT}" \
  --export=ALL,ROOT_DIR="$ROOT_DIR",TRIM_DIR="$TRIM_DIR",ALIGN_DIR="$ALIGN_DIR",LOG_DIR="$LOG_DIR",LIST_FILE="$LIST_FILE",REFERENCE_FASTA="$REF_FASTA" \
  "$ARRAY_SCRIPT"
