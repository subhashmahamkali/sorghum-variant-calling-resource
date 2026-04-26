#!/usr/bin/env bash
#SBATCH --job-name=bwa_mem2_unp
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/NEW/2.alignment/logs/bwa_mem2_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/NEW/2.alignment/logs/bwa_mem2_%A_%a.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-${SLURM_SUBMIT_DIR:-/work/jyanglab/subhash/NEW}}"
TRIM_DIR="${TRIM_DIR:-$ROOT_DIR/1.fastq/trim}"
ALIGN_DIR="${ALIGN_DIR:-$ROOT_DIR/2.alignment}"
LOG_DIR="${LOG_DIR:-$ALIGN_DIR/logs}"
LIST_FILE="${LIST_FILE:-$ALIGN_DIR/alignment_samples.list}"
REFERENCE_FASTA="${REFERENCE_FASTA:-/work/jyanglab/subhash/variant_calling/0.test/1.Raw_reads/4.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/Sorghum_bicolorv5.Sb-BTX623-REFERENCE-JGI-5.1.dna.toplevel.fa}"
THREADS="${THREADS:-8}"

mkdir -p "$ALIGN_DIR" "$LOG_DIR"

if [[ -f /etc/profile.d/modules.sh ]]; then
  # shellcheck source=/etc/profile.d/modules.sh
  source /etc/profile.d/modules.sh
fi
module purge
module load bwa-mem2
module load samtools

TASK_ID="${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID must be set (submit with --array)}"
SAMPLE="$(sed -n "${TASK_ID}p" "$LIST_FILE" || true)"
if [[ -z "$SAMPLE" ]]; then
  echo "No sample for task $TASK_ID in $LIST_FILE" >&2
  exit 1
fi

FASTQ="$TRIM_DIR/${SAMPLE}_fastp.fq.gz"
if [[ ! -f "$FASTQ" ]]; then
  echo "FASTQ not found: $FASTQ" >&2
  exit 1
fi

SAMPLE_OUT="$ALIGN_DIR/$SAMPLE"
mkdir -p "$SAMPLE_OUT"

RG="@RG\tID:${SAMPLE}\tPL:ILLUMINA\tSM:${SAMPLE}"
OUT_BAM="$SAMPLE_OUT/${SAMPLE}.srt.bam"

bwa-mem2 mem -t "$THREADS" -R "$RG" "$REFERENCE_FASTA" "$FASTQ" \
  | samtools view --threads "$THREADS" -b -q 30 -F 4 -h - \
  | samtools sort --threads "$THREADS" -o "$OUT_BAM" -

samtools index -@ "$THREADS" "$OUT_BAM"
samtools flagstat -@ "$THREADS" "$OUT_BAM" > "$SAMPLE_OUT/${SAMPLE}.flagstat.txt"

echo "Alignment complete for $SAMPLE"
