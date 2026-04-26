#!/bin/bash
#SBATCH --job-name=pi_align_trim
#SBATCH --array=0-399
#SBATCH --time=40:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --partition=jclarke,batch,guest
#SBATCH --output=/work/jyanglab/subhash/SAP/alignment/logs_trimmed/pi_align_trim_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/SAP/alignment/logs_trimmed/pi_align_trim_%A_%a.err

set -euo pipefail

THREADS="${SLURM_CPUS_PER_TASK:-8}"
PI_LIST="/work/jyanglab/subhash/SAP/fastq/unique_pis.txt"
FASTQ_DIR="/work/jyanglab/subhash/SAP/trimmed/pis"
OUT_DIR="/work/jyanglab/subhash/SAP/alignment/bams_trimmed"
TMP_ROOT="/work/jyanglab/subhash/SAP/alignment/tmp_trimmed"
REF="/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa"

mkdir -p "$OUT_DIR" "$TMP_ROOT"

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

INDEX=$((SLURM_ARRAY_TASK_ID + 1))
PI=$(sed -n "${INDEX}p" "$PI_LIST")

if [[ -z "$PI" ]]; then
  echo "No PI found at index $INDEX (SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID)" >&2
  exit 1
fi

PI_LABEL="$PI"
if [[ "$PI_LABEL" =~ ^PI([0-9]+)$ ]]; then
  PI_LABEL="PI_${BASH_REMATCH[1]}"
elif [[ "$PI_LABEL" =~ ^([A-Za-z]{2})([0-9]+)$ ]]; then
  PI_LABEL="${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
fi

R1="${FASTQ_DIR}/${PI_LABEL}_1.fastq.gz"
R2="${FASTQ_DIR}/${PI_LABEL}_2.fastq.gz"

if [[ ! -s "$R1" ]]; then
  echo "Missing read 1 for $PI at $R1" >&2
  exit 1
fi
if [[ ! -s "$R2" ]]; then
  echo "Missing read 2 for $PI at $R2" >&2
  exit 1
fi

OUT_BAM="${OUT_DIR}/${PI}.srt.bam"
TMP_DIR="${TMP_ROOT}/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
TMP_BAM="${TMP_DIR}/${PI}.srt.bam"

mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -f "${REF}.0123" ]]; then
  echo "Error: bwa-mem2 index files (.0123) not found for $REF" >&2
  echo "Please run bwa-mem2 index on the reference before launching this array." >&2
  exit 1
fi

if [[ -s "$OUT_BAM" && -s "${OUT_BAM}.bai" ]]; then
  echo "Output already exists for $PI; skipping."
  exit 0
fi

RG="@RG\tID:${PI}\tPL:ILLUMINA\tSM:${PI}"

bwa-mem2 mem -t "$THREADS" -R "$RG" "$REF" "$R1" "$R2" \
  | samtools view -@ "$THREADS" -b -h -f 2 -q 30 - \
  | samtools sort -@ "$THREADS" -o "$TMP_BAM" -

mv "$TMP_BAM" "$OUT_BAM"
samtools index -@ "$THREADS" "$OUT_BAM"

echo "Completed alignment for $PI"
