#!/bin/bash
#SBATCH --job-name=mvp_data_SAP
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/mvp_data_%j.out
#SBATCH --error=logs/mvp_data_%j.err

set -euo pipefail

# go to the folder that contains the R script
cd /lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full

# make a logs dir *here*
mkdir -p logs

module purge
module load R   # or: module load R/4.3.1 (whatever HCC uses)

echo "SLURM_CPUS_PER_TASK = $SLURM_CPUS_PER_TASK"
echo "Starting MVP.Data at $(date)"

# either of these is fine:
./prepare_mvp_data_full.R
# or: Rscript prepare_mvp_data_full.R

echo "Finished at $(date)"
