#!/bin/bash
#SBATCH --job-name=BQSR_array
#SBATCH --account=jyanglab
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=60:00:00
#SBATCH --array=1-876
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --mail-type=END,FAIL
#SBATCH --output=/work/jyanglab/subhash/BQSR/logs/%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/BQSR/logs/%A_%a.err

set -euo pipefail
module load gatk4/4.4
module load samtools

MANIFEST=/work/jyanglab/subhash/BQSR/samples.tsv
REF="/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa"
KNOWN=/work/jyanglab/subhash/known_sites/known_sites_merged.num.renamed.vcf.gz   # merged sites-only SNPs

OUTROOT=/work/jyanglab/subhash/BQSR
LOGDIR=${OUTROOT}/logs
DTDIR=${OUTROOT}/tables
BQSR_BAM_DIR=${OUTROOT}/bam
GVCF_DIR=${OUTROOT}/gvcf
mkdir -p "$LOGDIR" "$DTDIR" "$BQSR_BAM_DIR" "$GVCF_DIR"

read -r SAMPLE BAM < <(sed -n "${SLURM_ARRAY_TASK_ID}p" "$MANIFEST")
[[ -n "${SAMPLE:-}" && -s "$BAM" ]] || { echo "Bad manifest line ${SLURM_ARRAY_TASK_ID}"; exit 1; }

SCRATCH=/scratch/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

DT=${DTDIR}/${SAMPLE}.recal_data.table
BQSR_BAM=${BQSR_BAM_DIR}/${SAMPLE}.BQSR.bam
GVCF=${GVCF_DIR}/${SAMPLE}.g.vcf.gz

echo "==> SAMPLE=${SAMPLE}"
echo "BAM=$BAM"

[[ -s "${BAM}.bai" ]] || samtools index "$BAM"

# 1) BaseRecalibrator
/usr/bin/time -v gatk --java-options "-Djava.io.tmpdir=${SCRATCH} -Xmx12g" BaseRecalibrator \
  -R "$REF" -I "$BAM" --known-sites "$KNOWN" -O "$DT"

# 2) ApplyBQSR
/usr/bin/time -v gatk --java-options "-Djava.io.tmpdir=${SCRATCH} -Xmx12g" ApplyBQSR \
  -R "$REF" -I "$BAM" --bqsr-recal-file "$DT" -O "$BQSR_BAM" --create-output-bam-index true

# 3) HaplotypeCaller → gVCF
/usr/bin/time -v gatk --java-options "-Djava.io.tmpdir=${SCRATCH} -Xmx12g" HaplotypeCaller \
  -R "$REF" -I "$BQSR_BAM" -ERC GVCF -O "$GVCF"

echo "Done: $SAMPLE"
