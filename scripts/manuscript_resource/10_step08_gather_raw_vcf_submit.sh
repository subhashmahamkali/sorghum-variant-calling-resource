#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

SCRIPT="$PIPELINE_SCRIPTS_ROOT/08_gather_raw_vcf/gather_raw_vcf.sbatch"
require_file "$SCRIPT"

log "Submitting Step 08 GatherVcfs"
sbatch "$SCRIPT"
