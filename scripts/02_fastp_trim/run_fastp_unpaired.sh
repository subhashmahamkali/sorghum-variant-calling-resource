#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUT_DIR="${OUT_DIR:-$ROOT_DIR/trim}"
REPORT_DIR="${REPORT_DIR:-$OUT_DIR/reports}"
LOG_DIR="${LOG_DIR:-$OUT_DIR/logs}"
FASTP_BIN="${FASTP_BIN:-fastp}"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
PER_FILE_THREADS="${PER_FILE_THREADS:-4}"

mkdir -p "$OUT_DIR" "$REPORT_DIR" "$LOG_DIR"

UNPAIRED=()
while IFS= read -r -d '' file; do
  UNPAIRED+=("$file")
done < <(find "$ROOT_DIR" -type f -name '*_unpaired.fq.gz' -not -path "$OUT_DIR/*" -print0)

if [ "${#UNPAIRED[@]}" -eq 0 ]; then
  echo "No *_unpaired.fq.gz files found under $ROOT_DIR" >&2
  exit 1
fi

echo "Found ${#UNPAIRED[@]} unpaired FASTQ files to trim."

export OUT_DIR REPORT_DIR LOG_DIR FASTP_BIN PER_FILE_THREADS

run_fastp() {
  local file="$1"
  local sample
  sample="$(basename "$file")"
  sample="${sample%_unpaired.fq.gz}"
  local out="$OUT_DIR/${sample}_fastp.fq.gz"
  local html="$REPORT_DIR/${sample}.html"
  local json="$REPORT_DIR/${sample}.json"
  local log="$LOG_DIR/${sample}.log"

  {
    echo "=== $(date -u +'%Y-%m-%dT%H:%M:%SZ') | fastp trimming started ==="
    echo "Input : $file"
    echo "Output: $out"
    echo "Report: $html | $json"
    "$FASTP_BIN" --in1 "$file" --out1 "$out" \
      --thread "$PER_FILE_THREADS" --html "$html" --json "$json"
    echo "=== $(date -u +'%Y-%m-%dT%H:%M:%SZ') | fastp trimming finished ==="
  } >"$log" 2>&1
}
export -f run_fastp

if command -v parallel >/dev/null 2>&1; then
  parallel --jobs "$PARALLEL_JOBS" --halt soon,fail=1 run_fastp ::: "${UNPAIRED[@]}"
else
  printf '%s\0' "${UNPAIRED[@]}" | xargs -0 -n1 -P "$PARALLEL_JOBS" bash -c 'run_fastp "$1"' _
fi

echo "All fastp jobs completed. Trimmed FASTQs are in $OUT_DIR"
