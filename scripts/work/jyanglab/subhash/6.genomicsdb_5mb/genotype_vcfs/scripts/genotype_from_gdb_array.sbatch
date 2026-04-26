#!/bin/bash
#SBATCH --job-name=geno_gdb_5mb
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=48:00:00
#SBATCH --array=1-149
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/logs/genotype_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/logs/genotype_%A_%a.err

set -euo pipefail

module purge
module load gatk4/4.4

MANIFEST=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/scripts/genotype_5mb_manifest.tsv
REF_FASTA=/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa

TASK_ID=${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID not set}
LINE=$(sed -n "${TASK_ID}p" "${MANIFEST}" || true)
if [[ -z "${LINE}" ]]; then
    echo "No manifest entry for task ${TASK_ID}" >&2
    exit 1
fi
IFS=$'\t' read -r INTERVAL WORKSPACE OUTPUT_VCF <<< "${LINE}"
mkdir -p "$(dirname "${OUTPUT_VCF}")"

echo "[$(date)] Genotyping ${INTERVAL} from ${WORKSPACE}" >&2

gatk --java-options "-Xms4g -Xmx14g" GenotypeGVCFs \
    -R "${REF_FASTA}" \
    -V "gendb://${WORKSPACE}" \
    -O "${OUTPUT_VCF}"

gatk IndexFeatureFile -I "${OUTPUT_VCF}"

echo "[$(date)] Finished ${INTERVAL}" >&2
