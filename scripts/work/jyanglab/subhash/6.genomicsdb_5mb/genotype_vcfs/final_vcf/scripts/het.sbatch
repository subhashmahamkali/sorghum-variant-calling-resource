#!/bin/bash
#SBATCH --job-name=het_stats
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=12:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/het_stats_%j.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/logs/het_stats_%j.err

set -euo pipefail

module purge
module load bcftools/1.21
module load R   

VCF=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz
OUTDIR=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/sample_qc
mkdir -p "${OUTDIR}"

echo "[$(date)] Running bcftools stats..."
bcftools stats -s - "${VCF}" > "${OUTDIR}/joint.stats.txt"

echo "[$(date)] Parsing per-sample het rates..."
grep "^PSC" "${OUTDIR}/joint.stats.txt" \
  | awk 'BEGIN{OFS="\t"; print "sample","nRefHom","nAltHom","nHet","nMissing","nCalled","het_rate"} \
         {sample=$2; nRef=$3; nAlt=$4; nHet=$5; nMiss=$6; nCalled=nRef+nAlt+nHet; \
          hetRate = (nCalled>0 ? nHet/nCalled : "NA"); \
          print sample,nRef,nAlt,nHet,nMiss,nCalled,hetRate}' \
  > "${OUTDIR}/per_sample_het.tsv"

echo "[$(date)] Making R plot..."
Rscript - << 'EOF'
library(data.table)
library(ggplot2)

outdir <- "/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/sample_qc"
het <- fread(file.path(outdir, "per_sample_het.tsv"))

p <- ggplot(het, aes(x = het_rate)) +
  geom_histogram(bins = 50) +
  xlab("Per-sample heterozygosity rate") +
  ylab("Number of samples") +
  ggtitle("Het rate across inbred lines")

ggsave(file.path(outdir, "per_sample_het_hist.png"),
       p, width = 6, height = 4, dpi = 300)
EOF

echo "[$(date)] Done."




library(data.table)
library(ggplot2)

outdir <- "/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/sample_qc"
het <- fread(file.path(outdir, "per_sample_het.tsv"))

# If first column is the '0' ID, drop it and rename properly
if (names(het)[1] == "sample" && het[1, sample] == "0") {
  # shift columns: sample name is currently in column 2
  het[, sample_name := nRefHom]
  het[, c("sample","nRefHom") := NULL]
  setnames(het, old = "sample_name", new = "sample")
}

# compute missing rate: nMissing / (nMissing + nCalled)
het[, miss_rate := nMissing / (nMissing + nCalled)]

# histogram of missing rate
p_miss <- ggplot(het, aes(x = miss_rate)) +
  geom_histogram(bins = 50) +
  xlab("Per-sample missing rate") +
  ylab("Number of samples") +
  ggtitle("Missing rate across samples")

ggsave(file.path(outdir, "per_sample_missing_hist.png"),
       p_miss, width = 6, height = 4, dpi = 300)
