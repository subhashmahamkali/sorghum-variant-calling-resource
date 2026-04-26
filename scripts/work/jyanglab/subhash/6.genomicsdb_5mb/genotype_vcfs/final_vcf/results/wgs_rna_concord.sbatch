#!/bin/bash
#SBATCH --job-name=wgs_rna_concord
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=120G
#SBATCH --time=48:00:00
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/logs/wgs_rna_concord_%j.out.txt
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/logs/wgs_rna_concord_%j.err.txt

set -euo pipefail

module load bcftools

# ====== Paths ======
BASE=/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results
cd "$BASE"

# WGS: joint-called SNPs
WGS_VCF=SAP_BQSR_filtered_snps.vcf.gz

# RNA: renamed to have 1..10 chromosome names
RNA_VCF=SbDiv_811_maf0.05_het0.10.renamed.vcf.gz

mkdir -p logs

echo "Base dir: $BASE"
echo "WGS VCF:  $WGS_VCF"
echo "RNA VCF:  $RNA_VCF"

# ============================================================
# 1. Get sample lists for WGS and RNA
# ============================================================

echo "[1] Getting sample IDs..."
bcftools query -l "$WGS_VCF" > WGS.samples.txt
bcftools query -l "$RNA_VCF" > RNA.samples.txt

echo "WGS samples:  $(wc -l < WGS.samples.txt)"
echo "RNA samples:  $(wc -l < RNA.samples.txt)"

# ============================================================
# 2. Find shared samples (present in both WGS and RNA)
# ============================================================

echo "[2] Finding shared samples..."
comm -12 <(sort WGS.samples.txt) <(sort RNA.samples.txt) > shared.samples.txt
echo "Shared samples: $(wc -l < shared.samples.txt)"

# ============================================================
# 3. Subset WGS and RNA VCFs to shared samples only
# ============================================================

echo "[3] Creating WGS.shared.vcf.gz ..."
bcftools view -S shared.samples.txt \
  -Oz -o WGS.shared.vcf.gz "$WGS_VCF"
tabix -p vcf WGS.shared.vcf.gz

echo "[3] Creating RNA.shared.vcf.gz ..."
bcftools view -S shared.samples.txt \
  -Oz -o RNA.shared.vcf.gz "$RNA_VCF"
tabix -p vcf RNA.shared.vcf.gz

# ============================================================
# 4. Intersect SNP sites present in BOTH WGS and RNA
#    (matching on CHROM+POS+REF+ALT, NOT on ID)
# ============================================================

echo "[4] Running bcftools isec to find common SNPs..."
rm -rf isec_wgs_rna
mkdir -p isec_wgs_rna

bcftools isec -n=2 -Oz \
  -p isec_wgs_rna \
  WGS.shared.vcf.gz RNA.shared.vcf.gz

# 0002.vcf.gz = positions common to both
if [ ! -f isec_wgs_rna/0002.vcf.gz ]; then
  echo "ERROR: No common SNPs found between WGS and RNA VCFs."
  exit 1
fi

cp isec_wgs_rna/0002.vcf.gz intersect.vcf.gz
tabix -p vcf intersect.vcf.gz

# ============================================================
# 5. Subset each VCF to intersected SNP sites
# ============================================================

echo "[5] Subsetting WGS to intersect sites..."
bcftools view -R intersect.vcf.gz \
  -Oz -o WGS.intersect.vcf.gz WGS.shared.vcf.gz
tabix -p vcf WGS.intersect.vcf.gz

echo "[5] Subsetting RNA to intersect sites..."
bcftools view -R intersect.vcf.gz \
  -Oz -o RNA.intersect.vcf.gz RNA.shared.vcf.gz
tabix -p vcf RNA.intersect.vcf.gz

# ============================================================
# 6. Genotype concordance: WGS vs RNA (per sample)
# ============================================================

echo "[6] Running bcftools gtcheck for concordance..."
bcftools gtcheck \
  --ignore-phase 1 \
  -g WGS.intersect.vcf.gz \
  RNA.intersect.vcf.gz \
  > gtcheck.summary.txt

echo "[6] Finished. Concordance summary in gtcheck.summary.txt"

echo "[6] First 20 non-header lines of gtcheck.summary.txt:"
grep -v '^#' gtcheck.summary.txt | head -20 || true

echo "All done."
