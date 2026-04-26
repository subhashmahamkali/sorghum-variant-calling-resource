#!/bin/bash
#SBATCH --job-name=rep_conc
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/rep_conc_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/rep_conc_%A_%a.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
PAIRS=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/replicate_pairs.tsv
OUTDIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/rep_concordance
mkdir -p "$OUTDIR"

TASK_ID=${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID not set}

# Get the TASK_ID-th line from the pairs file
LINE=$(sed -n "${TASK_ID}p" "$PAIRS" || true)
if [[ -z "$LINE" ]]; then
    echo "No replicate pair for TASK_ID=${TASK_ID}" >&2
    exit 1
fi

# Read S1 and S2 from the line (tab or space separated)
read -r S1 S2 <<< "$LINE"

echo "[INFO] Comparing $S1 vs $S2" >&2

OUTFILE="${OUTDIR}/rep_concordance_${S1}_vs_${S2}.txt"

bcftools query -s "$S1","$S2" -f '[%GT\t]\n' "$VCF" \
  | awk -v s1="$S1" -v s2="$S2" '
    {
      a=$1; b=$2;
      total++;
      if (a=="./." || b=="./.") { missing++; next; }
      if (a==b) same++; else diff++;
    }
    END{
      nonmiss = total - missing;
      printf "sample1\t%s\nsample2\t%s\n", s1, s2;
      printf "total_sites\t%d\nnon_missing_sites\t%d\nmissing_sites\t%d\n", total, nonmiss, missing;
      if (nonmiss > 0) {
        printf "same_genotypes\t%d\t%.6f\n", same, same/nonmiss;
        printf "different_genotypes\t%d\t%.6f\n", diff, diff/nonmiss;
      }
    }' > "$OUTFILE"

echo "[INFO] Wrote $OUTFILE" >&2
