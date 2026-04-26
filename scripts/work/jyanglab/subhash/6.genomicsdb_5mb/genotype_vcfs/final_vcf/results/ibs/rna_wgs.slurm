#!/bin/bash
#SBATCH --job-name=rna_wgs
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=40G
#SBATCH --time=40:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/ibs/rna_wgs_%j.out.txt
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/ibs/rna_wgs_%j.err.txt


ml vcftools
vcftools --gzvcf /work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/WGS.shared.vcf.gz --keep /work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/RNA.samples.txt --recode --out /work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/ibs/wgs_RNA_shared

perl /work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/ibs/get_simple_vcf.pl wgs_RNA_shared.recode.vcf wgs_RNA_shared.vcf
