#!/bin/bash
#SBATCH --job-name=variant_qc
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/variant_qc_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/variant_qc_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc
mkdir -p "${OUT_DIR}"

N_SAMPLES=922   # from bcftools stats

OUT_TSV=${OUT_DIR}/variant_het_missing.tsv

echo -e "chrom\tpos\tAN\tAC_Het\tn_called\tn_het\thet_rate\tmissing_rate" > "${OUT_TSV}"

bcftools +fill-tags "${VCF}" -Ou -- -t AN,AC_Het \
  | bcftools query -f '%CHROM\t%POS\t%AN\t%INFO/AC_Het\n' \
  | awk -v ns="${N_SAMPLES}" 'BEGIN{OFS="\t"}
    {
      chrom=$1; pos=$2; AN=$3; AC_Het=$4;
      n_called = AN/2;
      n_het    = AC_Het;
      missing  = ns - n_called;
      het_rate = (n_called>0 ? n_het/n_called : 0);
      miss_rate = missing/ns;
      print chrom,pos,AN,AC_Het,n_called,n_het,het_rate,miss_rate;
    }' >> "${OUT_TSV}"

echo "[INFO] Wrote variant-level het/missing to ${OUT_TSV}"
