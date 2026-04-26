#!/bin/bash
#SBATCH --job-name=rep_pair_patterns
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/rep_pair_patterns_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/rep_pair_patterns_%j.err

set -euo pipefail
module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUT=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc/rep_pair_genotype_patterns.txt

# the two problematic pairs
cat > /tmp/rep_pairs.$$ <<EOF
PI576404_1 PI576404_2
PI576416   PI576416_1
EOF

echo -e "pair_id\ts1\ts2\tgt1\tgt2\tcount" > "$OUT"

pair_idx=0
while read -r S1 S2; do
  [[ -z "$S1" ]] && continue
  pair_idx=$((pair_idx+1))

  bcftools query -s "$S1","$S2" -f '[%GT\t]\n' "$VCF" \
    | awk -v id="pair_$pair_idx" -v s1="$S1" -v s2="$S2" '
        {
          g1=$1; g2=$2;
          if (g1=="./." || g2=="./.") next;
          key=g1 "|" g2;
          cnt[key]++
        }
        END{
          for (k in cnt) {
            split(k,a,"|");
            printf "%s\t%s\t%s\t%s\t%s\t%d\n", id, s1, s2, a[1], a[2], cnt[k];
          }
        }' >> "$OUT"

done < /tmp/rep_pairs.$$

rm /tmp/rep_pairs.$$
echo "[INFO] wrote patterns to $OUT"
