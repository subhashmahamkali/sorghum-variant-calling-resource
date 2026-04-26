#!/usr/bin/env bash
#SBATCH --job-name=expvp_align_trim
#SBATCH --array=1-46
#SBATCH --time=40:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --partition=jclarke,batch,guest
#SBATCH --chdir=/lustre/work/jyanglab/subhash/ex_pvp/fastq
#SBATCH --output=/lustre/work/jyanglab/subhash/ex_pvp/alignment_logs/expvp_align_trim_%A_%a.out
#SBATCH --error=/lustre/work/jyanglab/subhash/ex_pvp/alignment_logs/expvp_align_trim_%A_%a.err

set -euo pipefail

THREADS="${SLURM_CPUS_PER_TASK:-8}"
SAMPLE_LIST="/lustre/work/jyanglab/subhash/ex_pvp/fastq/manifest/samples.txt"
TRIM_DIR="/lustre/work/jyanglab/subhash/ex_pvp/fastq/trimmed"
OUT_DIR="/lustre/work/jyanglab/subhash/ex_pvp/alignment_trimmed"
TMP_ROOT="/lustre/work/jyanglab/subhash/ex_pvp/alignment_tmp"
REF="/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa"

mkdir -p "$OUT_DIR" "$TMP_ROOT" /lustre/work/jyanglab/subhash/ex_pvp/alignment_logs

if command -v ml >/dev/null 2>&1; then
  ml purge
  ml load bwa-mem2/2.2 || ml load bwa-mem2 || true
  ml load samtools || true
else
  module purge
  module load bwa-mem2/2.2 || module load bwa-mem2 || true
  module load samtools || true
fi

if ! command -v bwa-mem2 >/dev/null 2>&1; then
  echo "Error: bwa-mem2 not available in PATH after module load" >&2
  exit 1
fi

if ! command -v samtools >/dev/null 2>&1; then
  echo "Error: samtools not available in PATH after module load" >&2
  exit 1
fi

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST" | tr -d '\r')
if [[ -z "$SAMPLE" ]]; then
  echo "No sample found at array index $SLURM_ARRAY_TASK_ID" >&2
  exit 1
fi

R1="$TRIM_DIR/${SAMPLE}_R1.trim.fastq.gz"
R2="$TRIM_DIR/${SAMPLE}_R2.trim.fastq.gz"

if [[ ! -s "$R1" ]]; then
  echo "Missing trimmed read 1 for $SAMPLE at $R1" >&2
  exit 1
fi

if [[ ! -s "$R2" ]]; then
  echo "Missing trimmed read 2 for $SAMPLE at $R2" >&2
  exit 1
fi

OUT_BAM="$OUT_DIR/${SAMPLE}.srt.bam"
TMP_DIR="$TMP_ROOT/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
TMP_BAM="$TMP_DIR/${SAMPLE}.srt.bam"

mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -f "${REF}.0123" ]]; then
  echo "Error: bwa-mem2 index (.0123) not found for $REF" >&2
  exit 1
fi

if [[ -s "$OUT_BAM" && -s "${OUT_BAM}.bai" ]]; then
  echo "Output already exists for $SAMPLE; skipping."
  exit 0
fi

RG="@RG\tID:${SAMPLE}\tPL:ILLUMINA\tSM:${SAMPLE}"

echo "[$(date)] START $SAMPLE"

bwa-mem2 mem -t "$THREADS" -R "$RG" "$REF" "$R1" "$R2" \
  | samtools view -@ "$THREADS" -b -h -f 2 -q 30 - \
  | samtools sort -@ "$THREADS" -o "$TMP_BAM" -

mv "$TMP_BAM" "$OUT_BAM"
samtools index -@ "$THREADS" "$OUT_BAM"

echo "[$(date)] DONE $SAMPLE"
