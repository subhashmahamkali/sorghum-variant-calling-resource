suppressPackageStartupMessages({
  library(data.table)
  library(bigmemory)
  library(rMVP)
})

## Usage:
##   Rscript run_mvp_mlm_trait.R 5
## where 5 is the row index in trait_list.tsv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Provide the trait index, e.g. Rscript run_mvp_mlm_trait.R 1")
}
idx <- as.integer(args[1])

## ---- PATHS ----
base_dir <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
old_dir  <- file.path(base_dir, "geno_data/old")

trait_file <- file.path(base_dir, "trait_list.tsv")
pheno_file <- file.path(base_dir, "phenotype_final_400.csv")

## ---- READ TRAIT LIST ----
traits <- fread(trait_file)
if (idx < 1 || idx > nrow(traits)) {
  stop("Index out of range: idx = ", idx, ", nrow(traits) = ", nrow(traits))
}
trait_col <- traits$colname[idx]
label     <- traits$label[idx]

cat("\n=== Running MLM for trait index", idx, "===\n")
cat("    colname =", trait_col, "\n")
cat("    label   =", label, "\n\n")

## ---- ATTACH GENO + K (old MVP files) ----
setwd(old_dir)

geno_desc <- dget("mvp.plink.geno.desc")
geno      <- attach.big.matrix(geno_desc)          # nInd x nSNP

map       <- fread("mvp.plink.geno.map")           # map file created originally

kin_desc  <- dget("mvp.vcf.kin.desc")
K_mat     <- attach.big.matrix(kin_desc)           # nInd x nInd

ind_ids   <- scan("mvp.plink.geno.ind", what = "character", quiet = TRUE)

setwd(base_dir)

## ---- PHENOTYPE: align to geno order ----
pheno <- fread(pheno_file)

if (!"Taxa" %in% names(pheno)) {
  stop("phenotype file must have a 'Taxa' column")
}

pheno <- pheno[match(ind_ids, pheno$Taxa)]
if (!all(pheno$Taxa == ind_ids)) {
  stop("Order of Taxa in phenotype does not match geno.ind IDs")
}

if (!trait_col %in% names(pheno)) {
  stop("Trait column '", trait_col, "' not found in phenotype file")
}

phe_df <- data.frame(
  Taxa  = pheno$Taxa,
  Trait = pheno[[trait_col]]
)

## ---- OUTPUT DIRS ----
base_outdir <- file.path(base_dir, "1.gwas_MLM_all_traits_oldK")
if (!dir.exists(base_outdir)) {
  dir.create(base_outdir, recursive = TRUE, showWarnings = FALSE)
}

trait_dir <- file.path(base_outdir, label)
if (!dir.exists(trait_dir)) {
  dir.create(trait_dir, recursive = TRUE, showWarnings = FALSE)
}

out_prefix <- trait_dir  # MVP writes log + Trait.MLM.csv etc. directly here

## ---- RUN MLM ----
MVP(
  phe         = phe_df,    # data.frame: Taxa + Trait
  geno        = geno,
  map         = map,
  K           = K_mat,
  CV.MLM      = NULL,      # no external covariates
  nPC.MLM     = 3,         # let rMVP compute 3 PCs internally
  method      = "MLM",
  file.output = TRUE,
  out         = out_prefix
)

cat("\nFinished trait:", label, " (index", idx, ")\n")
