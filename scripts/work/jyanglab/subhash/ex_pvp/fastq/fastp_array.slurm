#!/usr/bin/env bash
#SBATCH --job-name=fastp_trim
#SBATCH --partition=jclarke,batch,guest
#SBATCH --cpus-per-task=4
#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --array=1-46
#SBATCH --output=logs/fastp_%A_%a.out.txt
#SBATCH --error=logs/fastp_%A_%a.err.txt

set -euo pipefail

module purge
module load fastp

# Guard array upper bound vs actual sample count
TOTAL=$(wc -l < manifest/samples.txt)
if (( SLURM_ARRAY_TASK_ID > TOTAL )); then
  echo "Task ${SLURM_ARRAY_TASK_ID} > total ${TOTAL}; exiting."
  exit 0
fi

PREFIX=$(sed -n "${SLURM_ARRAY_TASK_ID}p" manifest/samples.txt)

R1="${PREFIX}_R1.fastq.gz"
R2="${PREFIX}_R2.fastq.gz"

OUTDIR_TRIM="trimmed"
OUTDIR_REP="reports"
mkdir -p "$OUTDIR_TRIM" "$OUTDIR_REP" logs

OUT_R1="${OUTDIR_TRIM}/$(basename "$PREFIX")_R1.trim.fastq.gz"
OUT_R2="${OUTDIR_TRIM}/$(basename "$PREFIX")_R2.trim.fastq.gz"
HTML="${OUTDIR_REP}/$(basename "$PREFIX").fastp.html"
JSON="${OUTDIR_REP}/$(basename "$PREFIX").fastp.json"
LOG="logs/$(basename "$PREFIX").fastp.log"

echo "[$(date)] START $PREFIX"
echo "Threads: ${SLURM_CPUS_PER_TASK}"

# Skip if outputs already exist and are valid gz
if [[ -s "$OUT_R1" && -s "$OUT_R2" ]]; then
  if zcat -t "$OUT_R1" >/dev/null 2>&1 && zcat -t "$OUT_R2" >/dev/null 2>&1; then
    echo "Outputs exist and are valid, skipping: $PREFIX"
    exit 0
  else
    echo "Existing outputs appear corrupted—recomputing: $PREFIX"
    rm -f "$OUT_R1" "$OUT_R2"
  fi
fi

fastp \
  -i "$R1" -I "$R2" \
  -o "$OUT_R1" -O "$OUT_R2" \
  -c -Q --thread="${SLURM_CPUS_PER_TASK}" \
  -h "$HTML" -j "$JSON" \
  > "$LOG" 2>&1

echo "[$(date)] DONE $PREFIX"
