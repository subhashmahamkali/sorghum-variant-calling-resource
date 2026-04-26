#!/bin/bash
#SBATCH --job-name=BQSR_hc_only
#SBATCH --account=jyanglab
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=140:00:00
#SBATCH --array=371,862,783
#SBATCH --output=/work/jyanglab/subhash/BQSR/logs/%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/BQSR/logs/%A_%a.err

set -euo pipefail
module load gatk4/4.4

MANIFEST=/work/jyanglab/subhash/BQSR/samples.tsv
REF=/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa

SCRATCH=/scratch/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

#344,371,439,509,627,628,653,658,662,779,783,817
#379,463,497,541,664,862,719,329,389
read -r SAMPLE BAM < <(sed -n "${SLURM_ARRAY_TASK_ID}p" "$MANIFEST")
[[ -n "${SAMPLE:-}" ]] || { echo "Bad manifest line ${SLURM_ARRAY_TASK_ID}"; exit 1; }

BQSR_BAM=/work/jyanglab/subhash/BQSR/bam/${SAMPLE}.BQSR.bam
GVCF=/work/jyanglab/subhash/BQSR/gvcf/${SAMPLE}.g.vcf.gz

[[ -s "$BQSR_BAM" ]] || { echo "Missing BQSR BAM for $SAMPLE"; exit 1; }
rm -f "$GVCF" "$GVCF.tbi" "$GVCF.idx"

/usr/bin/time -v gatk --java-options "-Djava.io.tmpdir=${SCRATCH} -Xmx12g" HaplotypeCaller \
  -R "$REF" -I "$BQSR_BAM" -ERC GVCF -O "$GVCF"

echo "Done: $SAMPLE"
