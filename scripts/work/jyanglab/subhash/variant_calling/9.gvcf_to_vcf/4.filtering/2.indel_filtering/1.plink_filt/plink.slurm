#!/usr/bin/bash
#SBATCH --job-name=converting_to_plink
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=64G
#SBATCH --time=100:00:00
#SBATCH --partition=jclarke,batch,guest
#SBATCH --output=/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/PLINK.out
#SBATCH --error=/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/PLINK.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu

ml plink2
ml vcftools
ml bcftools

#converting to PLINK from .vcf
plink2 --vcf /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/filtered_indel.vcf --make-bed --out /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/SAP_indel

#basic statistics on the RAW data
plink2 --bfile /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/SAP_indel --freq alt1bins=0.01,0.02,0.03,0.04,0.05,0.1,0.2,0.3,0.4  --missing --hardy  --out /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/1.basic_stat/SAP_indel

#filtering the plink file for the MAF and MR
plink2 --bfile /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/SAP_indel --maf 0.001 --geno 0.3 --make-bed --out /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/1.plink_filt/2.filter/SAP_indel_v5_filt




















