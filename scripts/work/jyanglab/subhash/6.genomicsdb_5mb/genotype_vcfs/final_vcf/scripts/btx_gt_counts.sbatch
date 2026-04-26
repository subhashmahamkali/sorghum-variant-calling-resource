#!/bin/bash
#SBATCH --job-name=btx_gt_counts
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/btx_gt_counts_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/btx_gt_counts_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUTDIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/btx_ref_qc
mkdir -p "$OUTDIR"

for SAMPLE in BTx643 BTx645; do
  OUTFILE="${OUTDIR}/${SAMPLE}_genotype_counts.txt"
  echo "[INFO] Processing sample ${SAMPLE}, output -> ${OUTFILE}"

  bcftools query -s "$SAMPLE" -f '[%GT]\n' "$VCF" \
  | awk -v sample="$SAMPLE" '
      { cnt[$1]++; total++ }
      END{
        printf "sample\t%s\n", sample;
        printf "genotype\tcount\tfraction\n";
        for (g in cnt) {
          printf "%s\t%d\t%.6f\n", g, cnt[g], cnt[g]/total;
        }
        printf "total\t%d\t1.000000\n", total;
      }' > "$OUTFILE"
done

echo "[INFO] Done."
