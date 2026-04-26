#!/bin/bash
#SBATCH -J multiqc_full
#SBATCH -c 8
#SBATCH -t 08:00:00
#SBATCH -o multiqc_full.%j.log
#SBATCH -p short

set -euo pipefail

# Tunables
FASTQC_JOBS=8        # parallel FastQC processes (1 thread each)
SAMTOOLS_JOBS=8      # parallel samtools jobs
BCFTOOLS_JOBS=4      # parallel bcftools stats jobs

# Load required modules (adjust names/versions if different on your cluster)
module load fastqc
module load samtools
module load bcftools
module load multiqc/py37/1.8

# Input directories
RAW_DIRS=(
  /work/jyanglab/subhash/SAP/fastq/pis
  /work/jyanglab/subhash/NEW/1.fastq
  /work/jyanglab/subhash/ex_pvp/fastq
)
TRIM_DIRS=(
  /work/jyanglab/subhash/SAP/trimmed/pis
  /work/jyanglab/subhash/NEW/1.fastq/trim
  /work/jyanglab/subhash/ex_pvp/fastq/trimmed
)
ALIGN_BAM_DIRS=(
  /work/jyanglab/subhash/SAP/alignment/bams_trimmed
  /work/jyanglab/subhash/NEW/2.alignment
  /work/jyanglab/subhash/ex_pvp/alignment_trimmed
  /work/jyanglab/subhash/SAP/picard/dedup_trimmed
  /work/jyanglab/subhash/NEW/picard
  /work/jyanglab/subhash/ex_pvp/picard/dedup_trimmed
  /work/jyanglab/subhash/BQSR/bam
  /work/jyanglab/subhash/ex_pvp/BQSR_ex_pvp/bam
)
VARIANT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs
REPORT_BASE=/work/jyanglab/subhash/multiqc_reports

# Centralized output locations
RAW_FASTQC_BASE=$REPORT_BASE/raw_fastq/fastqc
TRIM_FASTQC_BASE=$REPORT_BASE/trimmed_fastq/fastqc
ALIGN_STATS_BASE=$REPORT_BASE/alignment/bam_stats
VARIANT_STATS_BASE=$REPORT_BASE/variants/bcftools_stats

mkdir -p "$RAW_FASTQC_BASE" "$TRIM_FASTQC_BASE" "$ALIGN_STATS_BASE" "$VARIANT_STATS_BASE"

make_label() {
  local dir="$1"
  local clean="${dir#/}"
  echo "${clean//\//_}"
}

run_fastqc_dir() {
  local dir="$1" base_out="$2" label out
  label="$(make_label "$dir")"
  out="$base_out/$label"
  mkdir -p "$out"
  if find "$dir" -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -print -quit | grep -q .; then
    find "$dir" -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -print0 \
      | xargs -0 -n 1 -P "$FASTQC_JOBS" fastqc -t 1 -o "$out"
  fi
}

run_samtools_stats() {
  local dir="$1" base_out="$2" label out
  label="$(make_label "$dir")"
  out="$base_out/$label"
  mkdir -p "$out"
  if find "$dir" -type f -name "*.bam" -print -quit | grep -q .; then
    find "$dir" -type f -name "*.bam" -print0 \
      | xargs -0 -n 1 -P "$SAMTOOLS_JOBS" bash -lc 'bam="$0"; outdir="'"$out"'"; base=$(basename "$bam"); samtools flagstat "$bam" > "$outdir/$base.flagstat" && samtools stats "$bam" > "$outdir/$base.stats"'
  fi
}

run_bcftools_stats_dir() {
  local dir="$1" base_out="$2" label out
  label="$(make_label "$dir")"
  out="$base_out/$label"
  mkdir -p "$out"
  if find "$dir" -type f \( -name "*.vcf.gz" -o -name "*.g.vcf.gz" -o -name "*.vcf" -o -name "*.g.vcf" \) ! -name "*.tbi" -print -quit | grep -q .; then
    find "$dir" -type f \( -name "*.vcf.gz" -o -name "*.g.vcf.gz" -o -name "*.vcf" -o -name "*.g.vcf" \) ! -name "*.tbi" -print0 \
      | xargs -0 -n 1 -P "$BCFTOOLS_JOBS" bash -lc 'vcf="$0"; outdir="'"$out"'"; base=$(basename "$vcf"); bcftools stats "$vcf" > "$outdir/$base.stats"'
  fi
}

echo "[FASTQC] Raw reads"
for d in "${RAW_DIRS[@]}"; do
  run_fastqc_dir "$d" "$RAW_FASTQC_BASE"
done

echo "[FASTQC] Trimmed reads"
for d in "${TRIM_DIRS[@]}"; do
  run_fastqc_dir "$d" "$TRIM_FASTQC_BASE"
done

echo "[SAMTOOLS] BAM stats"
for d in "${ALIGN_BAM_DIRS[@]}"; do
  run_samtools_stats "$d" "$ALIGN_STATS_BASE"
done

echo "[BCFTOOLS] Variant stats"
run_bcftools_stats_dir "$VARIANT_DIR/RAW_vcf" "$VARIANT_STATS_BASE"
run_bcftools_stats_dir "$VARIANT_DIR/genotype_vcfs/vcfs" "$VARIANT_STATS_BASE"
run_bcftools_stats_dir "$VARIANT_DIR/final_vcf/results" "$VARIANT_STATS_BASE"
run_bcftools_stats_dir "$VARIANT_DIR/BQSR/gvcf" "$VARIANT_STATS_BASE"
run_bcftools_stats_dir "$VARIANT_DIR/ex_pvp/BQSR_ex_pvp/gvcf" "$VARIANT_STATS_BASE"

# MultiQC aggregation (read-only scan of centralized outputs + Picard metrics)

echo "[MULTIQC] Raw reads"
multiqc "$RAW_FASTQC_BASE" -o "$REPORT_BASE/raw_fastq"

echo "[MULTIQC] Trimmed reads"
multiqc "$TRIM_FASTQC_BASE" -o "$REPORT_BASE/trimmed_fastq"

echo "[MULTIQC] Alignment/BAMs"
multiqc "$ALIGN_STATS_BASE" /work/jyanglab/subhash/SAP/picard /work/jyanglab/subhash/NEW/picard /work/jyanglab/subhash/ex_pvp/picard -o "$REPORT_BASE/alignment"

echo "[MULTIQC] Variants"
multiqc "$VARIANT_STATS_BASE" -o "$REPORT_BASE/variants"

echo "[DONE] Reports in $REPORT_BASE"
