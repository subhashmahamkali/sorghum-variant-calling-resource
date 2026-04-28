#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00_env.sh"

require_file "$SAMPLE_LIST_922"

BQSR_INPUT_BAM_ROOT="${BQSR_INPUT_BAM_ROOT:-$NEW_ROOT/picard}"
BQSR_MANIFEST_OUT="${BQSR_MANIFEST_OUT:-$BQSR_ROOT/samples.tsv}"
BQSR_MISSING_OUT="${BQSR_MISSING_OUT:-$BQSR_ROOT/samples.missing_bams.txt}"

GVCF_ROOT="${GVCF_ROOT:-$BQSR_ROOT/gvcf}"
SAMPLE_MAP_OUT="${SAMPLE_MAP_OUT:-$GDB_ROOT/sample_maps/gdb_sample_map_922.tsv}"
GVCF_MISSING_OUT="${GVCF_MISSING_OUT:-$GDB_ROOT/sample_maps/gdb_sample_map_922.missing_gvcf.txt}"

INTERVAL_LIST="${INTERVAL_LIST:-$GDB_ROOT/intervals/intervals_5mb.list}"
GENO_MANIFEST_OUT="${GENO_MANIFEST_OUT:-$GDB_ROOT/genotype_vcfs/scripts/genotype_5mb_manifest.tsv}"
VCF_LIST_OUT="${VCF_LIST_OUT:-$GDB_ROOT/genotype_vcfs/scripts/vcf_list_manifest_order.txt}"
GENO_VCF_OUTDIR="${GENO_VCF_OUTDIR:-$GDB_ROOT/genotype_vcfs/vcfs}"

mkdir -p "$(dirname "$BQSR_MANIFEST_OUT")" "$(dirname "$SAMPLE_MAP_OUT")" "$(dirname "$GENO_MANIFEST_OUT")" "$GENO_VCF_OUTDIR"

log "Building BQSR manifest: $BQSR_MANIFEST_OUT"
: > "$BQSR_MANIFEST_OUT"
: > "$BQSR_MISSING_OUT"
while IFS= read -r sample; do
  [[ -n "$sample" ]] || continue
  bam="$BQSR_INPUT_BAM_ROOT/$sample/${sample}_picard_dedup.bam"
  if [[ -s "$bam" ]]; then
    printf '%s\t%s\n' "$sample" "$bam" >> "$BQSR_MANIFEST_OUT"
  else
    printf '%s\t%s\n' "$sample" "$bam" >> "$BQSR_MISSING_OUT"
  fi
done < "$SAMPLE_LIST_922"

log "Building GenomicsDB sample map: $SAMPLE_MAP_OUT"
: > "$SAMPLE_MAP_OUT"
: > "$GVCF_MISSING_OUT"
while IFS= read -r sample; do
  [[ -n "$sample" ]] || continue
  gvcf="$GVCF_ROOT/${sample}.g.vcf.gz"
  if [[ -s "$gvcf" ]]; then
    printf '%s\t%s\n' "$sample" "$gvcf" >> "$SAMPLE_MAP_OUT"
  else
    printf '%s\t%s\n' "$sample" "$gvcf" >> "$GVCF_MISSING_OUT"
  fi
done < "$SAMPLE_LIST_922"

if [[ -s "$INTERVAL_LIST" ]]; then
  log "Building genotype manifest: $GENO_MANIFEST_OUT"
  : > "$GENO_MANIFEST_OUT"
  : > "$VCF_LIST_OUT"
  while IFS= read -r interval; do
    [[ -n "$interval" ]] || continue
    label="$(echo "$interval" | tr ':-' '__')"
    workspace="$GDB_ROOT/workspaces/$label"
    out_vcf="$GENO_VCF_OUTDIR/${label}.vcf.gz"
    printf '%s\t%s\t%s\n' "$interval" "$workspace" "$out_vcf" >> "$GENO_MANIFEST_OUT"
    printf '%s\n' "$out_vcf" >> "$VCF_LIST_OUT"
  done < "$INTERVAL_LIST"
else
  log "Interval list not found yet, skipping genotype manifest build: $INTERVAL_LIST"
fi

log "Manifest build complete"
log "BQSR manifest rows: $(line_count "$BQSR_MANIFEST_OUT")"
log "Sample map rows: $(line_count "$SAMPLE_MAP_OUT")"
[[ -f "$GENO_MANIFEST_OUT" ]] && log "Genotype manifest rows: $(line_count "$GENO_MANIFEST_OUT")"
[[ -s "$BQSR_MISSING_OUT" ]] && log "Missing BAM list: $BQSR_MISSING_OUT"
[[ -s "$GVCF_MISSING_OUT" ]] && log "Missing gVCF list: $GVCF_MISSING_OUT"
