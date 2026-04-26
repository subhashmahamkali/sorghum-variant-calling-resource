#!/bin/bash
#SBATCH --job-name=unrel_conc
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/unrel_conc_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/unrel_conc_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
PAIR_FILE=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/unrelated_pairs.txt
OUT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results
OUT_SUMMARY=${OUT_DIR}/unrelated_concordance_summary.txt

mkdir -p "$OUT_DIR"

# empty / create summary file with header
cat > "$OUT_SUMMARY" <<EOF
pair_id  sample1  sample2  total_sites  non_missing_sites  missing_sites  same_genotypes  same_prop  diff_genotypes  diff_prop
EOF

pair_idx=0

while read -r S1 S2; do
    # skip empty or comment lines
    [[ -z "${S1:-}" || "${S1:0:1}" == "#" ]] && continue

    pair_idx=$((pair_idx + 1))
    echo "Comparing $S1 vs $S2 (pair ${pair_idx})" >&2

    # use bcftools to stream only these 2 samples, then AWK to count
    bcftools query -s "$S1","$S2" -f '[%GT\t]\n' "$VCF" \
      | awk -v s1="$S1" -v s2="$S2" -v pid="$pair_idx" '
        {
          a=$1; b=$2;
          total++;
          if (a=="./." || b=="./.") { missing++; next; }
          nonmiss++;
          if (a==b) same++; else diff++;
        }
        END{
          if (total==0) total=0;
          sp = (nonmiss>0 ? same/nonmiss : 0);
          dp = (nonmiss>0 ? diff/nonmiss : 0);
          printf "pair_%02d\t%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%d\t%.6f\n",
                 pid, s1, s2, total, nonmiss, missing, same, sp, diff, dp;
        }' >> "$OUT_SUMMARY"

done < "$PAIR_FILE"

echo "[INFO] Finished all unrelated pairs. Results: $OUT_SUMMARY" >&2
