#!/bin/bash
#SBATCH --job-name=SAP_GWAS_MLM_sub
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=72:00:00
#SBATCH --chdir=/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full
#SBATCH --output=logs/gwas_mlm_subset_%j.out
#SBATCH --error=logs/gwas_mlm_subset_%j.err

set -euo pipefail

mkdir -p logs

module purge
module load R/4.3

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-1}

echo "SLURM_CPUS_PER_TASK = $SLURM_CPUS_PER_TASK"
echo "Starting GWAS (subset) at $(date)"

Rscript run_mvp_gwas_subset.R

echo "Finished at $(date)"
