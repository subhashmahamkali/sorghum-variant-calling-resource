#!/bin/bash
set -euo pipefail

# Load fastp module. Adjust if your environment differs.
module load fastp/0.23

FASTQ_DIR="${1:-fastq/pis}"
OUT_DIR="${2:-trimmed/pis}"
LOG_DIR="${3:-trimmed/logs}"
THREADS="${THREADS:-8}"

mkdir -p "${OUT_DIR}" "${LOG_DIR}"

shopt -s nullglob
r1_files=("${FASTQ_DIR}"/PI_*_1.fastq.gz)
shopt -u nullglob

if [ ${#r1_files[@]} -eq 0 ]; then
  echo "No R1 FASTQ files found in ${FASTQ_DIR}" >&2
  exit 1
fi

for r1 in "${r1_files[@]}"; do
  base="$(basename "${r1}")"
  sample="${base%_1.fastq.gz}"
  r2="${FASTQ_DIR}/${sample}_2.fastq.gz"

  if [ ! -f "${r2}" ]; then
    echo "[WARN] Missing R2 mate for ${sample}, skipping" >&2
    continue
  fi

  out_r1="${OUT_DIR}/${sample}_1.fastq.gz"
  out_r2="${OUT_DIR}/${sample}_2.fastq.gz"
  json="${LOG_DIR}/${sample}.fastp.json"
  html="${LOG_DIR}/${sample}.fastp.html"
  log="${LOG_DIR}/${sample}.fastp.log"

  if [ -f "${out_r1}" ] && [ -f "${out_r2}" ]; then
    echo "[INFO] ${sample}: outputs already exist, skipping"
    continue
  fi

  echo "[INFO] ${sample}: trimming with fastp"

  fastp \
    -i "${r1}" \
    -I "${r2}" \
    -o "${out_r1}" \
    -O "${out_r2}" \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_tail \
    --cut_mean_quality 20 \
    --cut_window_size 4 \
    --length_required 30 \
    --thread "${THREADS}" \
    --html "${html}" \
    --json "${json}" \
    --report_title "${sample} fastp report" \
    > "${log}" 2>&1

  echo "[INFO] ${sample}: trimming finished"
done

