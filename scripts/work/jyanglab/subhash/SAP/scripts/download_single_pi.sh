#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 PI_ID [MAP_FILE]" >&2
  exit 1
fi

PI_ID="$1"
MAP_FILE="${2:-fastq/problem_pi_run_map.tsv}"
RUN_DIR="${RUN_DIR:-fastq/runs}"
OUT_DIR="${OUTPUT_DIR:-fastq/pis}"
FASTQ_DUMP="${FASTQ_DUMP:-fastq-dump}"

if [ ! -f "$MAP_FILE" ]; then
  echo "Error: map file $MAP_FILE not found" >&2
  exit 1
fi

module load SRAtoolkit/2.11 >/dev/null 2>&1

if ! command -v "$FASTQ_DUMP" >/dev/null 2>&1; then
  echo "Error: fastq-dump not available" >&2
  exit 1
fi

mkdir -p "$RUN_DIR" "$OUT_DIR"

runs=$(awk -F '\t' -v pi="$PI_ID" 'NR>1 && $1==pi {print $2}' "$MAP_FILE")
if [ -z "$runs" ]; then
  echo "Error: no runs found for $PI_ID in $MAP_FILE" >&2
  exit 1
fi

# Normalize PI label to match PI_##### naming
pi_label="$PI_ID"
if [[ "$pi_label" =~ ^PI([0-9]+)$ ]]; then
  pi_label="PI_${BASH_REMATCH[1]}"
fi

out_r1="$OUT_DIR/${pi_label}_1.fastq.gz"
out_r2="$OUT_DIR/${pi_label}_2.fastq.gz"

rm -f "$out_r1" "$out_r2"
: > "$out_r1"
: > "$out_r2"

for run in $runs; do
  mkdir -p "$RUN_DIR/$PI_ID"
  rdir="$RUN_DIR/$PI_ID"
  r1="$rdir/${run}_1.fastq.gz"
  r2="$rdir/${run}_2.fastq.gz"

  if [ "${REDOWNLOAD:-true}" = "true" ] || [ ! -s "$r1" ] || [ ! -s "$r2" ]; then
    rm -f "$r1" "$r2"
    echo "[$PI_ID] Downloading $run"
    "$FASTQ_DUMP" --split-files --gzip --outdir "$rdir" "$run"
  else
    echo "[$PI_ID] Using existing $run"
  fi

  if [ ! -s "$r1" ] || [ ! -s "$r2" ]; then
    echo "Error: missing FASTQ files for $run" >&2
    exit 1
  fi

  echo "[$PI_ID] Appending $run"
  cat "$r1" >> "$out_r1"
  cat "$r2" >> "$out_r2"
done

echo "[$PI_ID] Finished"
