#!/bin/bash
#SBATCH --job-name=filter_indels
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_indels_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_indels_%j.err

set -euo pipefail

module purge
module load gatk4/4.4

RAW_VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz
FINAL_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf
RESULT_DIR=${FINAL_DIR}/results
mkdir -p "$RESULT_DIR"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

INDELS_RAW=${TMP_DIR}/indels.raw.vcf.gz
INDELS_FILTERED=${TMP_DIR}/indels.filtered.vcf.gz
OUTPUT_VCF=${RESULT_DIR}/SAP_BQSR_filtered_indels.vcf.gz

# Extract indel and mixed records
gatk SelectVariants \
    -V "$RAW_VCF" \
    --select-type-to-include INDEL \
    --select-type-to-include MIXED \
    -O "$INDELS_RAW"

# Apply hard filters tuned for indels
gatk VariantFiltration \
    -V "$INDELS_RAW" \
    --filter-name "hardINDEL" \
    --filter-expression "QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0 || SOR > 10.0 || QUAL < 30.0" \
    --genotype-filter-name "lowDP" \
    --genotype-filter-expression "DP < 3" \
    --set-filtered-genotype-to-no-call \
    -O "$INDELS_FILTERED"

# Keep only PASS indel calls and index the output
gatk SelectVariants \
    -V "$INDELS_FILTERED" \
    --exclude-filtered true \
    -O "$OUTPUT_VCF"

gatk IndexFeatureFile -I "$OUTPUT_VCF"
