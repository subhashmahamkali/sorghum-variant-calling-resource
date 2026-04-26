#!/bin/bash
#SBATCH --job-name=filter_snps_chr
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_snps_chr_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/filter_snps_chr_%A_%a.err
#SBATCH --array=1-10

set -euo pipefail

module purge
module load gatk4/4.4

RAW_VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz
FINAL_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf
RESULT_DIR=${FINAL_DIR}/results/snps_by_chrom
mkdir -p "$RESULT_DIR"

# Default sorghum chromosomes labeled 1..10. Override with CUSTOM_CHR_LIST="1 2 3" if needed.
CHR_LIST=(1 2 3 4 5 6 7 8 9 10)
if [[ -n "${CUSTOM_CHR_LIST:-}" ]]; then
    # shellcheck disable=SC2206
    CHR_LIST=(${CUSTOM_CHR_LIST})
fi

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "ERROR: Submit this script with sbatch --array." >&2
    exit 1
fi
INDEX=$((SLURM_ARRAY_TASK_ID - 1))
if (( INDEX < 0 || INDEX >= ${#CHR_LIST[@]} )); then
    echo "ERROR: SLURM_ARRAY_TASK_ID ${SLURM_ARRAY_TASK_ID} exceeds CHR_LIST size (${#CHR_LIST[@]})." >&2
    exit 1
fi
CHROM=${CHR_LIST[$INDEX]}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SNPS_RAW=${TMP_DIR}/snps.chr${CHROM}.raw.vcf.gz
SNPS_FILTERED=${TMP_DIR}/snps.chr${CHROM}.filtered.vcf.gz
OUTPUT_VCF=${RESULT_DIR}/SAP_BQSR_filtered_snps.chr${CHROM}.vcf.gz

# Extract SNPs for the chromosome
gatk SelectVariants \
    -V "$RAW_VCF" \
    --select-type-to-include SNP \
    -L "$CHROM" \
    -O "$SNPS_RAW"

# Apply hard filters
gatk VariantFiltration \
    -V "$SNPS_RAW" \
    --filter-name "hardSNP" \
    --filter-expression "MQ < 20.0 || QD < 2.0 || FS > 60.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0 || QUAL < 30.0" \
    --genotype-filter-name "lowDP" \
    --genotype-filter-expression "DP < 3" \
    --set-filtered-genotype-to-no-call \
    -O "$SNPS_FILTERED"

# Keep PASS sites
gatk SelectVariants \
    -V "$SNPS_FILTERED" \
    --exclude-filtered true \
    -O "$OUTPUT_VCF"

gatk IndexFeatureFile -I "$OUTPUT_VCF"
