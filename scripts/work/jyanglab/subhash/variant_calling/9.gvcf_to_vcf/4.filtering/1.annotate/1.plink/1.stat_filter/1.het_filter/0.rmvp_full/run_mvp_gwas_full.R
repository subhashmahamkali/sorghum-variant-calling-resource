#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(rMVP)
  library(data.table)
  library(bigmemory)
})

## ====== paths ======
base_dir <- "/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
setwd(base_dir)

mvp_prefix <- file.path(base_dir, "mvp_SAP_pheno")

out_root   <- file.path(base_dir, "1.gwas_MLM_phenoAligned")
if (!dir.exists(out_root)) dir.create(out_root, recursive = TRUE)

## ====== load MVP objects (geno, map, kin, PCs, phe) ======
cat("Attaching genotype, kinship, PC, and phenotype...\n")

geno <- attach.big.matrix(paste0(mvp_prefix, ".geno.desc"))
map  <- fread(paste0(mvp_prefix, ".geno.map"), data.table = FALSE)
K    <- attach.big.matrix(paste0(mvp_prefix, ".kin.desc"))
PCbm <- attach.big.matrix(paste0(mvp_prefix, ".pc.desc"))
PC   <- as.matrix(PCbm)

phe  <- fread(paste0(mvp_prefix, ".phe"), data.table = FALSE)
colnames(phe)[1] <- "Taxa"

cat("Dimensions:\n")
cat("  geno :", dim(geno)[1], "x", dim(geno)[2], "\n")
cat("  K    :", dim(K)[1],    "x", dim(K)[2],    "\n")
cat("  PC   :", dim(PC)[1],   "x", dim(PC)[2],   "\n")
cat("  phe  :", nrow(phe),    "x", ncol(phe),    "\n")

n_pc_use <- min(3, ncol(PC))

## ====== choose traits ======
trait_cols <- setdiff(colnames(phe), "Taxa")
# keep traits with at least 30 non-missing values
trait_cols <- trait_cols[colSums(!is.na(phe[, trait_cols, drop = FALSE])) >= 30]

cat("Number of traits to run:", length(trait_cols), "\n")

## helper to group traits
get_trait_group <- function(trait_name) {
  parts <- strsplit(trait_name, ":", fixed = TRUE)[[1]]
  if (length(parts) >= 2) paste(parts[1], parts[2], sep = "_") else "other"
}

## ====== run MLM per trait ======
for (trait_name in trait_cols) {
  cat("\n=====================================\n")
  cat("Running MLM GWAS for trait:", trait_name, "\n")

  phe_trait <- phe[, c("Taxa", trait_name), drop = FALSE]
  colnames(phe_trait) <- c("Taxa", "Trait")

  if (all(is.na(phe_trait$Trait))) {
    cat("  -> skipped (all NA)\n")
    next
  }
  if (length(unique(na.omit(phe_trait$Trait))) < 3) {
    cat("  -> skipped (too little variation)\n")
    next
  }

  grp <- get_trait_group(trait_name)
  grp_dir <- file.path(out_root, grp)
  if (!dir.exists(grp_dir)) dir.create(grp_dir, recursive = TRUE)

  trait_safe <- gsub("[^A-Za-z0-9_]+", "_", trait_name)
  trait_dir  <- file.path(grp_dir, trait_safe)
  if (!dir.exists(trait_dir)) dir.create(trait_dir, recursive = TRUE)

  cat("  -> group directory :", grp_dir,  "\n")
  cat("  -> trait directory :", trait_dir, "\n")

  MVP(
    phe        = phe_trait,
    geno       = geno,
    map        = map,
    K          = K,
    CV.GLM     = PC[, 1:n_pc_use, drop = FALSE],
    CV.MLM     = PC[, 1:n_pc_use, drop = FALSE],
    nPC.GLM    = n_pc_use,
    nPC.MLM    = n_pc_use,
    method     = c("MLM"),
    threshold  = 0.05 / nrow(map),
    permutation.threshold = FALSE,
    file.output = TRUE,
    out        = trait_dir
  )

  cat("  -> finished trait:", trait_name, "\n")
}

cat("\nAll GWAS runs finished.\n")
