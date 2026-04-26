#!/bin/bash
#SBATCH --job-name=mvp_MLM_traits
#SBATCH --partition=jclarke,batch,guest
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --array=1-90%10
#SBATCH --output=logs/mvp_MLM_%A_%a.out
#SBATCH --error=logs/mvp_MLM_%A_%a.err

module load R

cd /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full

Rscript run_mvp_mlm_trait.R ${SLURM_ARRAY_TASK_ID}
