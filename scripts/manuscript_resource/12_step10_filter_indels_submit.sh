#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

SCRIPT="$PIPELINE_SCRIPTS_ROOT/10_filter_indels/filter_indels.sbatch"
require_file "$SCRIPT"

log "Submitting Step 10 indel filtering"
sbatch "$SCRIPT"
