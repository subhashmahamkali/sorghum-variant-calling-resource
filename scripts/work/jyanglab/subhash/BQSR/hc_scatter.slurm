#!/usr/bin/env bash
#SBATCH --job-name=HC_scatter
#SBATCH --account=jyanglab
#SBATCH --partition=jclarke,batch,guest
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=08:00:00
# set a safe upper bound; we’ll guard below (or pass --array at submit)
#SBATCH --array=1-200%40
#SBATCH --output=logs/hc_scatter_%x_%A_%a.out
#SBATCH --error=logs/hc_scatter_%x_%A_%a.err

set -euo pipefail
module load gatk4/4.4

REF=/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa
INTERVAL_DIR=intervals/primary100            # <<< make sure this matches what you created
SAMPLE="$1"                                  # pass sample name on sbatch
BQSR_BAM=/work/jyanglab/subhash/BQSR/bam/${SAMPLE}.BQSR.bam

[[ -s "$BQSR_BAM" ]] || { echo "Missing $BQSR_BAM"; exit 1; }
mkdir -p "shards/${SAMPLE}" logs

# figure out how many interval files we actually have
mapfile -t LISTS < <(ls -1 "${INTERVAL_DIR}"/*.interval_list | sort -V)
N=${#LISTS[@]}
[[ $N -gt 0 ]] || { echo "No interval files in ${INTERVAL_DIR}"; exit 1; }

# guard the array bound
if (( SLURM_ARRAY_TASK_ID > N )); then
  echo "Task ${SLURM_ARRAY_TASK_ID} > ${N}; exiting."
  exit 0
fi

ILIST="${LISTS[$((SLURM_ARRAY_TASK_ID-1))]}"
OUT="shards/${SAMPLE}/$(basename "${ILIST%.interval_list}").g.vcf.gz"

# skip-if-exists for safe requeues
if [[ -s "$OUT" && -s "$OUT.tbi" ]]; then echo "exists: $OUT"; exit 0; fi

SCRATCH="/scratch/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

gatk --java-options "-Xmx12g -Djava.io.tmpdir=${SCRATCH}" HaplotypeCaller \
  -R "$REF" -I "$BQSR_BAM" -ERC GVCF -L "$ILIST" \
  --native-pair-hmm-threads "${SLURM_CPUS_PER_TASK}" \
  -O "$OUT"
