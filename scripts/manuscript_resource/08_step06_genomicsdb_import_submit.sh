#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/06_genomicsdb_import/genomicsdb_import_array_922.sbatch"
require_file "$ARRAY_SCRIPT"

SAMPLE_MAP="${SAMPLE_MAP:-$GDB_ROOT/sample_maps/gdb_sample_map_922.tsv}"
INTERVAL_LIST="${INTERVAL_LIST:-$GDB_ROOT/intervals/intervals_5mb.list}"
MAX_CONCURRENT="${MAX_CONCURRENT:-24}"

require_file "$SAMPLE_MAP"
require_file "$INTERVAL_LIST"
count="$(line_count "$INTERVAL_LIST")"

log "Submitting Step 06 GenomicsDBImport array for $count intervals"
sbatch --array="1-${count}%${MAX_CONCURRENT}" \
  --export=ALL,SAMPLE_MAP="$SAMPLE_MAP",INTERVAL_LIST="$INTERVAL_LIST" \
  "$ARRAY_SCRIPT"
