#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <fastp_jobid> [array_concurrency]" >&2
  exit 1
fi

FASTP_JOBID="$1"
ARRAY_LIMIT="${2:-24}"

ROOT_DIR="${ROOT_DIR:-/work/jyanglab/subhash/NEW}"
SCRIPTS_DIR="$ROOT_DIR/scripts"
PREP_SCRIPT="$SCRIPTS_DIR/prepare_alignment_array.sh"
ALIGN_SCRIPT="$SCRIPTS_DIR/alignment_unpaired_array.sh"
LIST_FILE="${LIST_FILE:-$ROOT_DIR/2.alignment/alignment_samples.list}"

if [[ ! -x "$PREP_SCRIPT" ]]; then
  echo "Missing or non-executable prepare script: $PREP_SCRIPT" >&2
  exit 1
fi
if [[ ! -x "$ALIGN_SCRIPT" ]]; then
  echo "Missing or non-executable alignment script: $ALIGN_SCRIPT" >&2
  exit 1
fi

# Generate/refresh the sample list
OUTPUT=$("$PREP_SCRIPT")
echo "$OUTPUT"

COUNT=$(wc -l < "$LIST_FILE" | tr -d ' ')

if [[ "$COUNT" -eq 0 ]]; then
  echo "Sample list $LIST_FILE is empty" >&2
  exit 1
fi

echo "Submitting alignment array for $COUNT samples with dependency on job $FASTP_JOBID"
CMD=(sbatch "--dependency=afterok:${FASTP_JOBID}" "--array=1-${COUNT}%${ARRAY_LIMIT}" "$ALIGN_SCRIPT")
printf 'Running: %q ' "${CMD[@]}"
printf '\n'
${CMD[@]}
