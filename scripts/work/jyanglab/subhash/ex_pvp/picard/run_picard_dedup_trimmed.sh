#!/bin/bash
#SBATCH --job-name=picard_ex_pvp_trimmed
#SBATCH --array=1-46
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --partition=jclarke,batch,guest
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --output=/lustre/work/jyanglab/subhash/ex_pvp/picard/logs/%x_%A_%a.out
#SBATCH --error=/lustre/work/jyanglab/subhash/ex_pvp/picard/logs/%x_%A_%a.err

set -euo pipefail

module purge
module load picard/3.0

SAMPLE_LIST=/lustre/work/jyanglab/subhash/ex_pvp/picard/alignment_trimmed_samples.txt
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$SAMPLE" ]]; then
    echo "No sample found for task ${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

INPUT_BAM=/lustre/work/jyanglab/subhash/ex_pvp/alignment_trimmed/${SAMPLE}.srt.bam
OUTPUT_DIR=/lustre/work/jyanglab/subhash/ex_pvp/picard/dedup_trimmed
METRICS_DIR=/lustre/work/jyanglab/subhash/ex_pvp/picard/metrics_trimmed
TMP_DIR=/lustre/work/jyanglab/subhash/ex_pvp/picard/tmp

mkdir -p "$OUTPUT_DIR" "$METRICS_DIR" "$TMP_DIR" /lustre/work/jyanglab/subhash/ex_pvp/picard/logs

OUTPUT_BAM="${OUTPUT_DIR}/${SAMPLE}_picard_dedup.bam"
METRICS_FILE="${METRICS_DIR}/${SAMPLE}_picard_metrics.txt"

if [[ -f "$OUTPUT_BAM" ]]; then
    echo "${OUTPUT_BAM} already exists; skipping Picard MarkDuplicates" >&2
    exit 0
fi

picard MarkDuplicates \
    INPUT="$INPUT_BAM" \
    OUTPUT="$OUTPUT_BAM" \
    METRICS_FILE="$METRICS_FILE" \
    CREATE_INDEX=true \
    REMOVE_DUPLICATES=true \
    VALIDATION_STRINGENCY=SILENT \
    TMP_DIR="$TMP_DIR"
