#!/usr/bin/env bash
# Batch download SRA runs listed in pi_run_map.tsv and merge into per-PI fastqs.

set -euo pipefail

TABLE_PATH="${1:-pi_run_map.tsv}"
FASTQ_DUMP="${FASTQ_DUMP:-fastq-dump}"
RUN_DIR="${RUN_DIR:-runs}"
OUTPUT_DIR="${OUTPUT_DIR:-pis}"
REDOWNLOAD="${REDOWNLOAD:-false}"

if [[ ! -f "$TABLE_PATH" ]]; then
  echo "Error: mapping table '$TABLE_PATH' not found" >&2
  exit 1
fi

if ! command -v "$FASTQ_DUMP" >/dev/null 2>&1; then
  echo "Error: '$FASTQ_DUMP' not found in PATH. Load the SRA Toolkit or adjust FASTQ_DUMP." >&2
  exit 1
fi

mkdir -p "$RUN_DIR" "$OUTPUT_DIR"

declare -A RUNS_BY_PI

# Read table into associative array of runs per PI.
while IFS=$'\t' read -r pi run layout; do
  if [[ "$pi" == "PI" && "$run" == "Run" ]]; then
    continue
  fi
  if [[ -z "$pi" || -z "$run" ]]; then
    continue
  fi
  if [[ -n "${RUNS_BY_PI[$pi]:-}" ]]; then
    RUNS_BY_PI[$pi]="${RUNS_BY_PI[$pi]} $run"
  else
    RUNS_BY_PI[$pi]="$run"
  fi
  if [[ -n "$layout" && "$layout" != "PAIRED" ]]; then
    echo "Warning: run $run for PI $pi has layout '$layout' (expected PAIRED)." >&2
  fi
# shellcheck disable=SC2059
# (shell does not support quoted format string in read loop comment, noted only for linters)
done < "$TABLE_PATH"

process_pi() {
  local pi="$1"
  local runs_string="$2"
  # shellcheck disable=SC2206
  local runs=($runs_string)
  if [[ ${#runs[@]} -eq 0 ]]; then
    return
  fi

  local pi_label="$pi"
  if [[ "$pi_label" =~ ^PI[0-9]+$ ]]; then
    pi_label="PI_${pi_label:2}"
  elif [[ "$pi_label" =~ ^[A-Za-z]{2}[0-9]+$ ]]; then
    pi_label="${pi_label:0:2}_${pi_label:2}"
  fi

  echo "Processing $pi (runs: ${runs[*]})"

  local run
  for run in "${runs[@]}"; do
    local r1_path="$RUN_DIR/${run}_1.fastq.gz"
    local r2_path="$RUN_DIR/${run}_2.fastq.gz"
    if [[ "$REDOWNLOAD" != "true" && -s "$r1_path" && -s "$r2_path" ]]; then
      echo "  Skipping download for $run (files already present)"
      continue
    fi
    echo "  Downloading $run"
    "$FASTQ_DUMP" --split-files --gzip --outdir "$RUN_DIR" "$run"
    if [[ ! -s "$r1_path" || ! -s "$r2_path" ]]; then
      echo "Error: expected files for $run not found after download" >&2
      exit 1
    fi
  done

  local out_r1="$OUTPUT_DIR/${pi_label}_1.fastq.gz"
  local out_r2="$OUTPUT_DIR/${pi_label}_2.fastq.gz"

  rm -f "$out_r1" "$out_r2"
  : > "$out_r1"
  : > "$out_r2"

  for run in "${runs[@]}"; do
    local r1_path="$RUN_DIR/${run}_1.fastq.gz"
    local r2_path="$RUN_DIR/${run}_2.fastq.gz"
    if [[ ! -s "$r1_path" || ! -s "$r2_path" ]]; then
      echo "Error: missing fastq for run $run while merging $pi" >&2
      exit 1
    fi
    echo "  Appending $run to ${pi_label}"
    cat "$r1_path" >> "$out_r1"
    cat "$r2_path" >> "$out_r2"
  done
}

mapfile -t PI_LIST < <(printf '%s\n' "${!RUNS_BY_PI[@]}" | sort)

for pi in "${PI_LIST[@]}"; do
  process_pi "$pi" "${RUNS_BY_PI[$pi]}"
done

echo "All PI fastqs written to $OUTPUT_DIR"
