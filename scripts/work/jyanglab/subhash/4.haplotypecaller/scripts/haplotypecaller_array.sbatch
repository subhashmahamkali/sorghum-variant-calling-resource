#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=50:00:00
#SBATCH --job-name=hc_array
#SBATCH --partition=jclarke,batch,guest
#SBATCH --array=1-971
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --mail-type=FAIL
#SBATCH --output=/work/jyanglab/subhash/4.haplotypecaller/logs/%x_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/4.haplotypecaller/logs/%x_%A_%a.err

set -euo pipefail

module purge
module load gatk4/4.4

MANIFEST=/work/jyanglab/subhash/4.haplotypecaller/manifests/all_samples.tsv
REF=/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa
GVCF_DIR=/work/jyanglab/subhash/5.gvcf

mkdir -p "${GVCF_DIR}" "${GVCF_DIR}/log_files"

LINE_NUM=$((SLURM_ARRAY_TASK_ID + 1))
LINE=$(sed -n "${LINE_NUM}p" "${MANIFEST}")
IFS=$'\t' read -r SAMPLE SOURCE BAM_PATH <<< "${LINE}"

if [[ -z "${SAMPLE}" || -z "${BAM_PATH}" ]]; then
    echo "Failed to parse manifest line ${LINE_NUM}" >&2
    exit 1
fi

OUT_GVCF="${GVCF_DIR}/${SAMPLE}.g.vcf"

if [[ -f "${OUT_GVCF}" ]]; then
    echo "Output ${OUT_GVCF} exists; skipping."
    exit 0
fi

srun --ntasks=1 --cpus-per-task=${SLURM_CPUS_PER_TASK:-8} gatk HaplotypeCaller \
    -R "${REF}" \
    -I "${BAM_PATH}" \
    -O "${OUT_GVCF}" \
    -ERC GVCF \
    --native-pair-hmm-threads 8 \
    --tmp-dir /tmp

