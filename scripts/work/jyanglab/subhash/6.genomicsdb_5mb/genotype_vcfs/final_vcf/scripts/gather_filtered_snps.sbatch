#!/bin/bash
#SBATCH --job-name=gather_snps
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/gather_snps_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/gather_snps_%j.err

set -euo pipefail

module purge
module load gatk4/4.4

FINAL_DIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf
CHROM_DIR=${FINAL_DIR}/results/snps_by_chrom
OUTPUT_VCF=${FINAL_DIR}/results/SAP_BQSR_filtered_snps.vcf.gz

# Default chromosomes 1..10 unless CUSTOM_CHR_LIST overrides
CHR_LIST=(1 2 3 4 5 6 7 8 9 10)
if [[ -n "${CUSTOM_CHR_LIST:-}" ]]; then
    # shellcheck disable=SC2206
    CHR_LIST=(${CUSTOM_CHR_LIST})
fi

INPUTS=()
for CHROM in "${CHR_LIST[@]}"; do
    VCF=${CHROM_DIR}/SAP_BQSR_filtered_snps.chr${CHROM}.vcf.gz
    IDX=${VCF}.tbi
    if [[ ! -s "$VCF" || ! -s "$IDX" ]]; then
        echo "ERROR: Missing VCF or index for chromosome ${CHROM}: $VCF" >&2
        exit 1
    fi
    INPUTS+=("-I" "$VCF")
done

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

gatk GatherVcfs \
    "${INPUTS[@]}" \
    -O "$OUTPUT_VCF" \
    --TMP_DIR "$TMP_DIR"

# Index combined file
gatk IndexFeatureFile -I "$OUTPUT_VCF"
