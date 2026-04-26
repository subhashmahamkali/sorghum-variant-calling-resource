#!/bin/bash
#SBATCH --job-name=SAP_vcf_qc
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/SAP_vcf_qc_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/SAP_vcf_qc_%j.err

set -euo pipefail

module purge
module load bcftools/1.21

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUTDIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc_stats
mkdir -p "${OUTDIR}"

echo "Indexing VCF (if needed)..."
bcftools index --threads 8 -f "${VCF}"

############################
# 1. Number of samples
############################
echo "Counting samples..."
bcftools query -l "${VCF}" > "${OUTDIR}/samples.list"
wc -l "${OUTDIR}/samples.list" > "${OUTDIR}/n_samples.txt"

############################
# 2. Number of variants
############################
echo "Counting variants..."
bcftools index -n "${VCF}" > "${OUTDIR}/n_variants.txt"

############################
# 3. Per-sample het & missing (fast)
############################
echo "Running bcftools stats for per-sample counts..."
bcftools view --threads 8 -m2 -M2 -v snps -Ou "${VCF}" \
  | bcftools stats -s - - > "${OUTDIR}/SAP_BQSR.stats"

# PSC lines: sample-level counts
grep "^PSC" "${OUTDIR}/SAP_BQSR.stats" > "${OUTDIR}/psc_raw.txt"

# Columns: SAMPLE  N_ref_hom  N_nonref_hom  N_het  N_missing
awk '{print $3,$4,$5,$6,$7}' OFS="\t" "${OUTDIR}/psc_raw.txt" \
  > "${OUTDIR}/per_sample_counts.tsv"

# Heterozygosity rate = N_het / (N_ref_hom + N_nonref_hom + N_het)
awk '{het_rate = $4/($2+$3+$4); print $1,het_rate}' OFS="\t" \
  "${OUTDIR}/per_sample_counts.tsv" \
  > "${OUTDIR}/heterozygosity.tsv"

# Missing rate = N_missing / (N_ref_hom + N_nonref_hom + N_het + N_missing)
awk '{miss_rate = $5/($2+$3+$4+$5); print $1,miss_rate}' OFS="\t" \
  "${OUTDIR}/per_sample_counts.tsv" \
  > "${OUTDIR}/missing_rate.tsv"

############################
# 4. MAF per site
############################
echo "Computing MAF per SNP..."
bcftools view --threads 8 -m2 -M2 -v snps -Ou "${VCF}" \
  | bcftools +fill-tags -Ou -- -t MAF \
  | bcftools query -f "%CHROM\t%POS\t%REF\t%ALT\t%MAF\n" \
  > "${OUTDIR}/SAP_BQSR_maf.tsv"

echo "All done. Outputs in: ${OUTDIR}"
