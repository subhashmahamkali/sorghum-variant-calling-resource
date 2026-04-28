#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

SCRIPT="$PIPELINE_SCRIPTS_ROOT/01_cram_to_fastq/01_prepare_cram_list_and_submit.sh"
require_file "$SCRIPT"

log "Submitting Step 01 (CRAM -> FASTQ)"
WORK="$RAW_CRAM_ROOT" \
FASTQ_ROOT="$NEW_ROOT/1.fastq" \
LOG_DIR="$NEW_ROOT/1.fastq/logs" \
LIST="$NEW_ROOT/1.fastq/piscbt_crams.list" \
"$SCRIPT"
