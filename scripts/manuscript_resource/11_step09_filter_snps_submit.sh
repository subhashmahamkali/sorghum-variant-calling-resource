#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

SCRIPT="$PIPELINE_SCRIPTS_ROOT/09_filter_snps/filter_snps.sbatch"
require_file "$SCRIPT"

log "Submitting Step 09 SNP filtering"
sbatch "$SCRIPT"
