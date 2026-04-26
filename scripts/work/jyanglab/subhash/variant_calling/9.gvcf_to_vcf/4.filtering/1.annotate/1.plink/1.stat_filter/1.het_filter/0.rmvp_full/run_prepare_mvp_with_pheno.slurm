#!/bin/bash
#SBATCH --job-name=mvp_prep_pheno
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --chdir=/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full
#SBATCH --output=logs/mvp_prep_pheno_%j.out
#SBATCH --error=logs/mvp_prep_pheno_%j.err

set -euo pipefail
mkdir -p logs

module purge
module load R/4.3

echo "SLURM_CPUS_PER_TASK = $SLURM_CPUS_PER_TASK"
echo "Starting MVP.Data with phenotype at $(date)"

Rscript prepare_mvp_with_pheno.R

echo "Finished at $(date)"
