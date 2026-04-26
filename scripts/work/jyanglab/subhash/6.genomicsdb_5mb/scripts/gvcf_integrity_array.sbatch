#!/bin/bash
#SBATCH --job-name=gvcf_check
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=01:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/gvcf_check.%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/gvcf_check.%A_%a.err

set -euo pipefail

FILE_LIST=/work/jyanglab/subhash/6.genomicsdb_5mb/reports/gvcf_files.list
REPORT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/reports/gvcf_integrity
PYTHON=/util/opt/anaconda/deployed-conda-envs/packages/python/envs/python-3.9/bin/python

mkdir -p "${REPORT_DIR}"

if [[ ! -f "${FILE_LIST}" ]]; then
  echo "File list ${FILE_LIST} not found" >&2
  exit 1
fi

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
  echo "SLURM_ARRAY_TASK_ID is not set; submit with sbatch --array" >&2
  exit 1
fi

LINE_NUMBER=$((SLURM_ARRAY_TASK_ID + 1))
GVCF_PATH=$(sed -n "${LINE_NUMBER}p" "${FILE_LIST}")

if [[ -z "${GVCF_PATH}" ]]; then
  echo "No GVCF for array index ${SLURM_ARRAY_TASK_ID}" >&2
  exit 0
fi

BASENAME=$(basename "${GVCF_PATH}" .g.vcf)
REPORT_FILE="${REPORT_DIR}/${BASENAME}.tsv"

"${PYTHON}" - "${GVCF_PATH}" "${REPORT_FILE}" <<'PY'
import pathlib
import sys

if len(sys.argv) < 3:
    print("Usage: python - <gvcf> <report>", file=sys.stderr)
    sys.exit(2)

file_path = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])

status = "OK"
line_info = "-"
issue = "pass"
context = ""

if not file_path.exists():
    status = "FAIL"
    issue = "missing_gvcf"
else:
    idx_path = pathlib.Path(str(file_path) + ".idx")
    if not idx_path.exists() or idx_path.stat().st_size == 0:
        status = "FAIL"
        issue = "missing_or_empty_idx"
    with file_path.open('r', encoding='utf-8', errors='replace') as handle:
        prev_chr = None
        prev_pos = -1
        for line_no, raw in enumerate(handle, 1):
            if raw.startswith('#'):
                continue
            cols = raw.rstrip('\n').split('\t')
            if len(cols) < 9:
                status = "FAIL"
                line_info = str(line_no)
                issue = f"too_few_columns({len(cols)})"
                context = raw.rstrip().replace('\t', ' ')
                break
            chrom = cols[0]
            try:
                pos = int(cols[1])
            except ValueError:
                status = "FAIL"
                line_info = str(line_no)
                issue = "non_integer_pos"
                context = raw.rstrip().replace('\t', ' ')
                break
            if prev_chr == chrom and pos < prev_pos:
                status = "FAIL"
                line_info = str(line_no)
                issue = f"pos_out_of_order({chrom}:{pos}<{prev_pos})"
                context = raw.rstrip().replace('\t', ' ')
                break
            prev_chr = chrom
            prev_pos = pos
        else:
            if status == "OK":
                issue = "validated"

with report_path.open('w', encoding='utf-8') as out_handle:
    out_handle.write("file\tstatus\tline\tissue\tcontext\n")
    out_handle.write(f"{file_path.name}\t{status}\t{line_info}\t{issue}\t{context}\n")
PY

echo "Checked ${GVCF_PATH} -> ${REPORT_FILE}"
