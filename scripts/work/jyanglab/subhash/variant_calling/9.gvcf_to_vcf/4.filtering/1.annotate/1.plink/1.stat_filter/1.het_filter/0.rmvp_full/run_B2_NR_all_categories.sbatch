#!/bin/bash
#SBATCH --job-name=pos_NR_allCats
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --array=0-3
#SBATCH --output=B2_NR_cat_%A_%a.out.txt
#SBATCH --error=B2_NR_cat_%A_%a.err.txt

module load R

# Categories and corresponding metadata files (must be in BASE_DIR)
CATS=(Developmental Architecture Panicle Seed)
METAS=(NR_Developmental_traits.tsv NR_Architecture_traits.tsv NR_Panicle_traits.tsv NR_Seed_traits.tsv)

CATEGORY=${CATS[$SLURM_ARRAY_TASK_ID]}
META=${METAS[$SLURM_ARRAY_TASK_ID]}

echo "Running category = $CATEGORY  meta = $META"

#Rscript run_B2_ancestor_effect_NR_category_fixed.R "${CATEGORY}" "${META}"
Rscript run_PosSel_ancestor_effect_NR_category.R "${CATEGORY}" "${META}"
