#!/bin/bash
#SBATCH --job-name=picard_trimmed
#SBATCH --array=1-400
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --partition=jclarke,batch,guest
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --output=/work/jyanglab/subhash/SAP/picard/logs/%x_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/SAP/picard/logs/%x_%A_%a.err

set -euo pipefail

module purge
module load picard/3.0

SAMPLE_LIST=/work/jyanglab/subhash/SAP/picard/trimmed_samples.txt
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$SAMPLE" ]]; then
    echo "No sample found for task ${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

INPUT_BAM=/work/jyanglab/subhash/SAP/alignment/bams_trimmed/${SAMPLE}.srt.bam
OUTPUT_DIR=/work/jyanglab/subhash/SAP/picard/dedup_trimmed
METRICS_DIR=/work/jyanglab/subhash/SAP/picard/metrics_trimmed
TMP_DIR=/work/jyanglab/subhash/SAP/picard/tmp

mkdir -p "$OUTPUT_DIR" "$METRICS_DIR" "$TMP_DIR"

picard MarkDuplicates \
    INPUT="$INPUT_BAM" \
    OUTPUT="${OUTPUT_DIR}/${SAMPLE}_picard_dedup.bam" \
    METRICS_FILE="${METRICS_DIR}/${SAMPLE}_picard_metrics.txt" \
    CREATE_INDEX=true \
    REMOVE_DUPLICATES=true \
    VALIDATION_STRINGENCY=SILENT \
    TMP_DIR="$TMP_DIR"
