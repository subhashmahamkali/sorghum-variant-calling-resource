#!/bin/bash
#SBATCH --job-name=variant_qc
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=08:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/variant_qc_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/variant_qc_%j.err

set -euo pipefail

module purge
module load bcftools/1.21
module load python/3.11
module load gnuplot/5.4

FINAL_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf
RESULT_DIR=${FINAL_DIR}/results
QC_DIR=${FINAL_DIR}/qc
mkdir -p "$QC_DIR"

THREADS=${SLURM_CPUS_PER_TASK:-4}

summarize_stream() {
    local metric=$1
    local outfile=$2
    python3 - "$outfile" "$metric" <<'PY'
import sys
import math
from pathlib import Path

out_path = Path(sys.argv[1])
metric = sys.argv[2]

if metric == "site_depth":
    edges = [0, 5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1000]
elif metric == "genotype_gq":
    edges = list(range(0, 105, 5))
else:
    raise SystemExit(f"Unknown metric: {metric}")

counts = [0] * len(edges)
used = 0
missing = 0
seen = 0
val_sum = 0.0
val_sumsq = 0.0
min_val = None
max_val = None

for raw_line in sys.stdin:
    raw_line = raw_line.strip()
    if not raw_line:
        continue
    tokens = raw_line.replace('\t', ' ').split()
    for token in tokens:
        seen += 1
        if token in {'.', './.'}:
            missing += 1
            continue
        try:
            value = float(token)
        except ValueError:
            missing += 1
            continue
        used += 1
        val_sum += value
        val_sumsq += value * value
        min_val = value if min_val is None or value < min_val else min_val
        max_val = value if max_val is None or value > max_val else max_val
        placed = False
        for idx in range(len(edges) - 1):
            if edges[idx] <= value < edges[idx + 1]:
                counts[idx] += 1
                placed = True
                break
        if not placed:
            counts[-1] += 1

out_path.parent.mkdir(parents=True, exist_ok=True)
with out_path.open('w') as handle:
    handle.write(f"metric\t{metric}\n")
    handle.write(f"values_seen\t{seen}\n")
    handle.write(f"values_used\t{used}\n")
    handle.write(f"missing_or_invalid\t{missing}\n")
    if used:
        mean = val_sum / used
        variance = max(val_sumsq / used - mean * mean, 0.0)
        stdev = math.sqrt(variance)
        handle.write(f"min\t{min_val:.4f}\n")
        handle.write(f"max\t{max_val:.4f}\n")
        handle.write(f"mean\t{mean:.4f}\n")
        handle.write(f"stdev\t{stdev:.4f}\n")
    else:
        handle.write("min\tNA\n")
        handle.write("max\tNA\n")
        handle.write("mean\tNA\n")
        handle.write("stdev\tNA\n")
    handle.write("\nhistogram\n")
    handle.write("bin\tcount\n")
    for idx in range(len(edges) - 1):
        handle.write(f"[{edges[idx]},{edges[idx + 1]})\t{counts[idx]}\n")
    handle.write(f">={edges[-1]}\t{counts[-1]}\n")
PY
}

run_qc() {
    local label=$1
    local vcf=$2
    local prefix="${QC_DIR}/${label}"
    local stats_file="${prefix}.stats.txt"

    echo "[INFO] Running bcftools stats for ${label}"
    bcftools stats --threads "$THREADS" "$vcf" > "$stats_file"

    echo "[INFO] Plotting stats for ${label}"
    plot-vcfstats -p "${prefix}_plots" "$stats_file"

    echo "[INFO] Summarizing per-chrom counts for ${label}"
    bcftools query --threads "$THREADS" -f '%CHROM\n' "$vcf" \
        | LC_ALL=C sort \
        | uniq -c \
        | awk 'BEGIN {print "chrom\tvariant_count"} {print $2"\t"$1}' \
        > "${prefix}_per_chrom.tsv"

    echo "[INFO] Summarizing INFO/DP for ${label}"
    bcftools query --threads "$THREADS" -f '%INFO/DP\n' "$vcf" \
        | summarize_stream site_depth "${prefix}_site_depth.txt"

    echo "[INFO] Summarizing FORMAT/GQ for ${label}"
    bcftools query --threads "$THREADS" -f '[%GQ\t]\n' "$vcf" \
        | summarize_stream genotype_gq "${prefix}_genotype_gq.txt"
}

SNPS_VCF=${RESULT_DIR}/SAP_BQSR_filtered_snps.vcf.gz
INDELS_VCF=${RESULT_DIR}/SAP_BQSR_filtered_indels.vcf.gz

run_qc "SAP_BQSR_filtered_snps" "$SNPS_VCF"
run_qc "SAP_BQSR_filtered_indels" "$INDELS_VCF"

python3 - <<'PY'
from pathlib import Path

qc_dir = Path('/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc')
summary_path = qc_dir / 'bcftools_summary.tsv'
metrics = {
    'number of samples:',
    'number of records:',
    'number of SNPs:',
    'number of indels:',
    'number of multiallelic sites:',
    'number of multiallelic SNP sites:'
}
entries = []
for label in ('SAP_BQSR_filtered_snps', 'SAP_BQSR_filtered_indels'):
    stats_file = qc_dir / f'{label}.stats.txt'
    if not stats_file.exists():
        continue
    with stats_file.open() as handle:
        for line in handle:
            if line.startswith('SN\t'):
                parts = line.rstrip('\n').split('\t')
                if len(parts) >= 4 and parts[2] in metrics:
                    metric = parts[2].replace(':', '').replace(' ', '_').replace('/', '_').lower()
                    entries.append((label, metric, parts[3]))
            elif line.startswith('TSTV\t'):
                parts = line.rstrip('\n').split('\t')
                if len(parts) >= 5:
                    entries.append((label, 'ts', parts[2]))
                    entries.append((label, 'tv', parts[3]))
                    entries.append((label, 'ts_tv_ratio', parts[4]))
summary_path.parent.mkdir(parents=True, exist_ok=True)
with summary_path.open('w') as out:
    out.write('cohort\tmetric\tvalue\n')
    for entry in entries:
        out.write('\t'.join(entry) + '\n')
PY

echo "[INFO] QC outputs are in ${QC_DIR}"
