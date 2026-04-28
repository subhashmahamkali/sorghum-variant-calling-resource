#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/04_picard_markduplicates/picard_markduplicates_array.sh"
require_file "$ARRAY_SCRIPT"

ROOT_DIR="$NEW_ROOT"
ALIGN_DIR="$ROOT_DIR/2.alignment"
PICARD_DIR="$ROOT_DIR/picard"
LOG_DIR="$PICARD_DIR/logs"
LIST_FILE="$ALIGN_DIR/alignment_samples.list"
MAX_CONCURRENT="${MAX_CONCURRENT:-24}"

require_file "$LIST_FILE"
count="$(line_count "$LIST_FILE")"

log "Submitting Step 04 Picard array for $count samples"
sbatch --array="1-${count}%${MAX_CONCURRENT}" \
  --export=ALL,ROOT_DIR="$ROOT_DIR",ALIGN_DIR="$ALIGN_DIR",PICARD_DIR="$PICARD_DIR",LOG_DIR="$LOG_DIR",LIST_FILE="$LIST_FILE" \
  "$ARRAY_SCRIPT"
