#!/bin/bash
#SBATCH --job-name=gvcf_integrity
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=12G
#SBATCH --time=04:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/gvcf_integrity.%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/gvcf_integrity.%j.err

set -euo pipefail

PYTHON=/util/opt/anaconda/deployed-conda-envs/packages/python/envs/python-3.9/bin/python
GVCF_DIR=/work/jyanglab/subhash/5.gvcf
REPORT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/reports
REPORT=${REPORT_DIR}/corrupt_gvcf_report.tsv

mkdir -p "${REPORT_DIR}"

"${PYTHON}" - <<'PY' > "${REPORT}"
import pathlib
import sys

gvcf_dir = pathlib.Path('/work/jyanglab/subhash/5.gvcf')
print('file\tline\tissue\textra')
for path in sorted(gvcf_dir.glob('*.g.vcf')):
    prev_chr = None
    prev_pos = -1
    with path.open() as fh:
        for line_no, raw in enumerate(fh, 1):
            if raw.startswith('#'):
                continue
            cols = raw.rstrip('\n').split('\t')
            if len(cols) < 9:
                print(f"{path.name}\t{line_no}\ttoo_few_columns({len(cols)})\t{raw.rstrip()}\n", end='')
                break
            chrom, pos = cols[0], int(cols[1])
            if prev_chr == chrom and pos < prev_pos:
                print(f"{path.name}\t{line_no}\tout_of_order({chrom}:{pos}<{prev_pos})\t{raw.rstrip()}\n", end='')
                break
            prev_chr, prev_pos = chrom, pos
PY

echo "Integrity report written to ${REPORT}"
