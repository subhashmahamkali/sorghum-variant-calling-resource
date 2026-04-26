#!/usr/bin/env bash
#SBATCH --job-name=picard_md
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/NEW/picard/logs/picard_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/NEW/picard/logs/picard_%A_%a.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-/work/jyanglab/subhash/NEW}"
ALIGN_DIR="${ALIGN_DIR:-$ROOT_DIR/2.alignment}"
PICARD_DIR="${PICARD_DIR:-$ROOT_DIR/picard}"
LOG_DIR="${LOG_DIR:-$PICARD_DIR/logs}"
LIST_FILE="${LIST_FILE:-$ROOT_DIR/2.alignment/alignment_samples.list}"
THREADS="${THREADS:-8}"

mkdir -p "$PICARD_DIR" "$LOG_DIR"

if [[ -f /etc/profile.d/modules.sh ]]; then
  # shellcheck source=/etc/profile.d/modules.sh
  source /etc/profile.d/modules.sh
fi
module purge
module load picard/3.0

TASK_ID="${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID must be set (submit with --array)}"
SAMPLE="$(sed -n "${TASK_ID}p" "$LIST_FILE" || true)"
if [[ -z "$SAMPLE" ]]; then
  echo "No sample for task $TASK_ID in $LIST_FILE" >&2
  exit 1
fi

INPUT_BAM="$ALIGN_DIR/$SAMPLE/${SAMPLE}.srt.bam"
if [[ ! -f "$INPUT_BAM" ]]; then
  echo "Input BAM not found: $INPUT_BAM" >&2
  exit 1
fi

SAMPLE_OUT_DIR="$PICARD_DIR/$SAMPLE"
mkdir -p "$SAMPLE_OUT_DIR"

DEDUP_BAM="$SAMPLE_OUT_DIR/${SAMPLE}_picard_dedup.bam"
METRICS_FILE="$SAMPLE_OUT_DIR/${SAMPLE}_picard_metrics.txt"

picard MarkDuplicates \
  INPUT="$INPUT_BAM" \
  OUTPUT="$DEDUP_BAM" \
  METRICS_FILE="$METRICS_FILE" \
  CREATE_INDEX=true \
  REMOVE_DUPLICATES=true \
  ASSUME_SORTED=true \
  VALIDATION_STRINGENCY=SILENT

echo "Picard MarkDuplicates complete for $SAMPLE"
