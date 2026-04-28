#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

ARRAY_SCRIPT="$PIPELINE_SCRIPTS_ROOT/07_genotype_gvcfs/genotype_from_gdb_array.sbatch"
require_file "$ARRAY_SCRIPT"

MANIFEST="${MANIFEST:-$GDB_ROOT/genotype_vcfs/scripts/genotype_5mb_manifest.tsv}"
MAX_CONCURRENT="${MAX_CONCURRENT:-24}"
require_file "$MANIFEST"
count="$(line_count "$MANIFEST")"

log "Submitting Step 07 GenotypeGVCFs array for $count intervals"
log "Script expects manifest path: /work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/scripts/genotype_5mb_manifest.tsv"
sbatch --array="1-${count}%${MAX_CONCURRENT}" "$ARRAY_SCRIPT"
