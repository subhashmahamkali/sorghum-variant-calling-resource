#!/bin/bash
#SBATCH --job-name=rmvp_prep
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --chdir=/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter
#SBATCH --output=0.rmvp/0.log_files/rmvp_prep_%j.out
#SBATCH --error=0.rmvp/0.log_files/rmvp_prep_%j.err

set -euo pipefail
module purge
module load R/4.3

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-1}

srun Rscript 0.rmvp/prepare_mvp_data.R
