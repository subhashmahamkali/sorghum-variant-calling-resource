#!/bin/bash
#SBATCH --job-name=wgs_rna_conc_full
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/wgs_rna_conc_full_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/wgs_rna_conc_full_%j.err

module purge
# adjust module names if needed on HCC
module load bcftools
module load R

BASE=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results
cd "$BASE"

WGS_VCF=WGS.shared.vcf.gz
RNA_VCF=RNA.shared.vcf.gz

echo "[1] Extracting all RNA sites..."
bcftools query -f '%CHROM\t%POS\n' "$RNA_VCF" \
  | sort -k1,1 -k2,2n -u > RNA.all.sites.txt

echo "[2] Subsetting WGS to overlapping sites..."
bcftools view -R RNA.all.sites.txt -Oz \
  -o WGS.overlap.vcf.gz \
  "$WGS_VCF"

tabix -p vcf WGS.overlap.vcf.gz

echo "[3] Subsetting RNA to overlapping sites..."
bcftools view -R RNA.all.sites.txt -Oz \
  -o RNA.overlap.vcf.gz \
  "$RNA_VCF"

tabix -p vcf RNA.overlap.vcf.gz

echo "[4] Running bcftools gtcheck on genome-wide overlap..."
bcftools gtcheck \
  -g WGS.overlap.vcf.gz \
  RNA.overlap.vcf.gz \
  > gtcheck.genome.summary.txt

echo "[5] Running R concordance script..."
Rscript wgs_rna_concordance_genome.R

echo "[DONE] Full-genome WGS vs RNA concordance finished."
