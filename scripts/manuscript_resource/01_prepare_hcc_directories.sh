#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

require_file "$SAMPLE_LIST_922"

log "Creating common pipeline directories"
mkdir -p \
  "$NEW_ROOT/1.fastq/logs" \
  "$NEW_ROOT/1.fastq/trim/reports" \
  "$NEW_ROOT/1.fastq/trim/logs" \
  "$NEW_ROOT/1.fastq/trim/slurm_logs" \
  "$NEW_ROOT/2.alignment/logs" \
  "$NEW_ROOT/picard/logs" \
  "$BQSR_ROOT/logs" \
  "$BQSR_ROOT/tables" \
  "$BQSR_ROOT/bam" \
  "$BQSR_ROOT/gvcf" \
  "$GDB_ROOT/logs" \
  "$GDB_ROOT/sample_maps" \
  "$GDB_ROOT/intervals" \
  "$GDB_ROOT/workspaces" \
  "$GDB_ROOT/genotype_vcfs/logs" \
  "$GDB_ROOT/genotype_vcfs/scripts" \
  "$GDB_ROOT/genotype_vcfs/RAW_vcf" \
  "$GDB_ROOT/genotype_vcfs/vcfs" \
  "$GDB_ROOT/genotype_vcfs/final_vcf/logs" \
  "$GDB_ROOT/genotype_vcfs/final_vcf/results"

log "Creating sample-level directories for IDs in $SAMPLE_LIST_922"
while IFS= read -r sample; do
  [[ -n "$sample" ]] || continue
  mkdir -p \
    "$NEW_ROOT/1.fastq/$sample" \
    "$NEW_ROOT/2.alignment/$sample" \
    "$NEW_ROOT/picard/$sample"
done < "$SAMPLE_LIST_922"

log "Directory preparation complete"
