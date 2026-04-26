#!/bin/bash
#SBATCH --job-name=filter_snps
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_snps_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_snps_%j.err

set -euo pipefail

module purge
module load gatk4/4.4

RAW_VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz
FINAL_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf
RESULT_DIR=${FINAL_DIR}/results
mkdir -p "$RESULT_DIR"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SNPS_RAW=${TMP_DIR}/snps.raw.vcf.gz
SNPS_FILTERED=${TMP_DIR}/snps.filtered.vcf.gz
OUTPUT_VCF=${RESULT_DIR}/SAP_BQSR_filtered_snps.vcf.gz

# Extract only SNP records
gatk SelectVariants \
    -V "$RAW_VCF" \
    --select-type-to-include SNP \
    -O "$SNPS_RAW"

# Apply hard filters that mirror the historical Perl script
gatk VariantFiltration \
    -V "$SNPS_RAW" \
    --filter-name "hardSNP" \
    --filter-expression "MQ < 20.0 || QD < 2.0 || FS > 60.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0 || QUAL < 30.0" \
    --genotype-filter-name "lowDP" \
    --genotype-filter-expression "DP < 3" \
    --set-filtered-genotype-to-no-call \
    -O "$SNPS_FILTERED"

# Keep only PASS sites and index the final SNP VCF
gatk SelectVariants \
    -V "$SNPS_FILTERED" \
    --exclude-filtered true \
    -O "$OUTPUT_VCF"

gatk IndexFeatureFile -I "$OUTPUT_VCF"
