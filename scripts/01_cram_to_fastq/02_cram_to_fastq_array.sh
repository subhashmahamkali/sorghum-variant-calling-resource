#!/usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --mem=16G
#SBATCH --time=24:00:00
#SBATCH --partition=jclarke,batch,guest
#SBATCH --job-name=cram2fq
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --output=/work/jyanglab/subhash/NEW/1.fastq/logs/%x_%j.out
#SBATCH --error=/work/jyanglab/subhash/NEW/1.fastq/logs/%x_%j.err

set -euo pipefail

module load samtools pigz 2>/dev/null || module load samtools

CRAM=${CRAM:?Set CRAM path via sbatch --export}
SAMPLE=${SAMPLE:-$(basename "${CRAM%.cram}")}
FASTQ_ROOT="${FASTQ_ROOT:-/work/jyanglab/subhash/NEW/1.fastq}"
LOG_DIR="${LOG_DIR:-/work/jyanglab/subhash/NEW/1.fastq/logs}"
CRAM_REF_FASTA="${CRAM_REF_FASTA:-/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa}"

FASTQ_DIR="$FASTQ_ROOT/$SAMPLE"
mkdir -p "$FASTQ_DIR" "$LOG_DIR"

samtools view -@ 8 -T "$CRAM_REF_FASTA" -b "$CRAM" \
  | samtools fastq -@ 8 - \
      -1 "$FASTQ_DIR/${SAMPLE}_R1.fq" \
      -2 "$FASTQ_DIR/${SAMPLE}_R2.fq" \
      -0 "$FASTQ_DIR/${SAMPLE}_unpaired.fq" \
      -s "$FASTQ_DIR/${SAMPLE}_single.fq" \
      -n

for fq in \
  "$FASTQ_DIR/${SAMPLE}_R1.fq" \
  "$FASTQ_DIR/${SAMPLE}_R2.fq" \
  "$FASTQ_DIR/${SAMPLE}_unpaired.fq" \
  "$FASTQ_DIR/${SAMPLE}_single.fq"; do
  [[ -f "$fq" ]] || : > "$fq"
  pigz -p 8 "$fq" || gzip "$fq"
done
