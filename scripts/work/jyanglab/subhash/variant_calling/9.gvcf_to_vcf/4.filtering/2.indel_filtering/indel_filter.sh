#!/bin/sh
#SBATCH --ntasks-per-node=8
#SBATCH --nodes=1
#SBATCH --mem=16G
#SBATCH --time=150:00:00
#SBATCH --job-name=indel
#SBATCH --mail-user=smahamkalivenkatas2@huskers.unl.edu
#SBATCH --mail-type=ALL
#SBATCH --error=/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/indel.err
#SBATCH --output=/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/indel.out


perl indel.pl  /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/3.merged_vcf/RAW_SAP_BQSR.vcf.gz  /work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/2.indel_filtering/filtered_indel.vcf
