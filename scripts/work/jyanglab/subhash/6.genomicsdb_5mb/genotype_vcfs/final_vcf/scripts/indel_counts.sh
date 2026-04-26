#!/bin/bash
#SBATCH --job-name=indel_counts
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/indel_counts_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/indel_counts_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

INDEL_VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_indels.vcf.gz
OUTDIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/indel_qc
mkdir -p "${OUTDIR}"

echo "[$(date)] INDEL VCF: ${INDEL_VCF}"

# 1) number of samples
echo "[$(date)] Counting samples..."
bcftools query -l "${INDEL_VCF}" > "${OUTDIR}/samples_indels.list"
wc -l "${OUTDIR}/samples_indels.list" > "${OUTDIR}/n_samples_indels.txt"

# 2) number of indel variants
echo "[$(date)] Counting indel variants..."
bcftools index --threads 4 -f "${INDEL_VCF}"
bcftools index -n "${INDEL_VCF}" > "${OUTDIR}/n_indels.txt"

echo "[$(date)] Done. Results in ${OUTDIR}"
