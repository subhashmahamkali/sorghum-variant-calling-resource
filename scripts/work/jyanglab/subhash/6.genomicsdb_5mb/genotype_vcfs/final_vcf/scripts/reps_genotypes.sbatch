#!/bin/bash
#SBATCH --job-name=reps_genotypes
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/reps_genotypes_%j.out.txt
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/reps_genotypes_%j.err.txt


module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
SAMPLE_LIST=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/reps_samples.txt
OUT=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/reps_genotypes.tsv

bcftools query -S "${SAMPLE_LIST}" \
  -f '%CHROM\t%POS[\t%GT]\n' \
  "${VCF}" > "${OUT}"
