#!/bin/bash
#SBATCH --job-name=gather_raw_vcf
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/logs/gather_raw_vcf_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/logs/gather_raw_vcf_%j.err

set -euo pipefail

module purge
module load gatk4/4.4

VCF_LIST=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/scripts/vcf_list_manifest_order.txt
OUTPUT_VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz
mkdir -p "$(dirname "$OUTPUT_VCF")"

ARGS_FILE=$(mktemp)
trap 'rm -f "$ARGS_FILE"' EXIT
awk '{print "-I"; print $0}' "$VCF_LIST" > "$ARGS_FILE"

gatk --java-options "-Xmx10g" GatherVcfs \
    --arguments_file "$ARGS_FILE" \
    -O "$OUTPUT_VCF"

gatk IndexFeatureFile -I "$OUTPUT_VCF"
