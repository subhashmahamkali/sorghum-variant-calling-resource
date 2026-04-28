#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/05_bqsr_haplotypecaller/BQSR_array.sh"
require_file "$ARRAY_SCRIPT"

MANIFEST="${MANIFEST:-$BQSR_ROOT/samples.tsv}"
MAX_CONCURRENT="${MAX_CONCURRENT:-48}"
require_file "$MANIFEST"
count="$(line_count "$MANIFEST")"

log "Submitting Step 05 BQSR+HaplotypeCaller array for $count samples"
log "Script expects manifest path: /work/jyanglab/subhash/BQSR/samples.tsv"
sbatch --array="1-${count}%${MAX_CONCURRENT}" "$ARRAY_SCRIPT"
