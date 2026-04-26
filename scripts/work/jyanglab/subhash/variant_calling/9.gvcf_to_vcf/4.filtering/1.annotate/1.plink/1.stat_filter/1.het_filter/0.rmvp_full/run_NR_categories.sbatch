#!/bin/bash
#SBATCH --job-name=NRcats_B2
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --array=0-3                 # 4 array elements: 0,1,2,3
#SBATCH --output=logs/NRcats_%A_%a.out.txt
#SBATCH --error=logs/NRcats_%A_%a.err.txt

# Move to your working directory
cd /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full

# Make sure log dir exists
mkdir -p logs

# Map array index -> category + metadata file
categories=("Developmental" "Architecture" "Panicle" "Seed")
meta_files=("NR_Developmental_traits.tsv" "NR_Architecture_traits.tsv" "NR_Panicle_traits.tsv" "NR_Seed_traits.tsv")

CATEGORY=${categories[$SLURM_ARRAY_TASK_ID]}
META=${meta_files[$SLURM_ARRAY_TASK_ID]}

echo "Running category: ${CATEGORY}  with meta file: ${META}"
date

module load R/4.3

Rscript run_B2_ancestor_effect_NR_category.R "${CATEGORY}" "${META}"

echo "Done category: ${CATEGORY}"
date
