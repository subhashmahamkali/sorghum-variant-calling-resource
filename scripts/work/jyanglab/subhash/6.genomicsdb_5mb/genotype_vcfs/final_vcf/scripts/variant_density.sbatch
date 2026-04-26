#!/bin/bash
#SBATCH --job-name=snp_density
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/snp_density_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/snp_density_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUT_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc
mkdir -p "${OUT_DIR}"

POS_TSV=${OUT_DIR}/snp_positions.tsv

bcftools query -f '%CHROM\t%POS\n' "${VCF}" > "${POS_TSV}"

echo "[INFO] SNP positions written to ${POS_TSV}"
