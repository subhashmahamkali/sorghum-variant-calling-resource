#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(rMVP)
  library(data.table)
  library(bigmemory)
})

## ===== paths =====
base_dir <- "/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
setwd(base_dir)

geno_dir   <- file.path(base_dir, "geno_data")
pheno_file <- file.path(base_dir, "BLUEs_SAP2020_2021_pheno_clean.csv")

out_root   <- file.path(base_dir, "1.gwas_MLM_subset")
if (!dir.exists(out_root)) dir.create(out_root, recursive = TRUE)

## ===== load geno, kin, PC =====
cat("Attaching genotype, kinship and PC matrices...\n")

geno <- attach.big.matrix(file.path(geno_dir, "geno.geno.desc"))
map  <- fread(file.path(geno_dir, "geno.geno.map"), data.table = FALSE)
Kbm  <- attach.big.matrix(file.path(geno_dir, "geno.kin.desc"))
PCbm <- attach.big.matrix(file.path(geno_dir, "geno.pc.desc"))
PC   <- as.matrix(PCbm)

ind_ids <- scan(file.path(geno_dir, "geno.geno.ind"), what = "character", quiet = TRUE)

cat("dim(geno) =", dim(geno)[1], "x", dim(geno)[2], "\n")
cat("dim(K)    =", dim(Kbm)[1],  "x", dim(Kbm)[2],  "\n")
cat("dim(PC)   =", dim(PC)[1],   "x", dim(PC)[2],   "\n")

## ===== load phenotype and fix IDs =====
phe_raw <- fread(pheno_file, data.table = FALSE)
colnames(phe_raw)[1] <- "Taxa"

# IDs there should already be like "PI576348", but just in case:
phe_raw$Taxa <- gsub("\\s+", "", phe_raw$Taxa)

## ===== find overlapping individuals =====
overlap <- intersect(ind_ids, phe_raw$Taxa)
cat("Total genotype IDs:", length(ind_ids), "\n")
cat("Total phenotype IDs:", nrow(phe_raw), "\n")
cat("Overlapping IDs    :", length(overlap), "\n")

# order overlap in genotype order
overlap <- ind_ids[ind_ids %in% overlap]

# indices in genotype structures
keep_idx <- match(overlap, ind_ids)

# subset phenotype to the same individuals, same order
phe <- phe_raw[match(overlap, phe_raw$Taxa), ]
stopifnot(all(phe$Taxa == overlap))

cat("After subsetting, phe rows:", nrow(phe), "\n")

## ===== subset geno, K, PC to overlapping individuals =====
cat("Subsetting geno, K, and PC to overlapping individuals...\n")

# create a column-subset view of the big.matrix (no full copy)
geno_sub <- sub.big.matrix(geno, cols = keep_idx)

# K is small, we can use a normal matrix
K_full   <- as.matrix(Kbm)
K_sub    <- K_full[keep_idx, keep_idx, drop = FALSE]

PC_sub   <- PC[keep_idx, , drop = FALSE]
n_pc_use <- min(3, ncol(PC_sub))

cat("dim(geno_sub) =", dim(geno_sub)[1], "x", dim(geno_sub)[2], "\n")
cat("dim(K_sub)    =", dim(K_sub)[1],    "x", dim(K_sub)[2],    "\n")
cat("dim(PC_sub)   =", dim(PC_sub)[1],   "x", dim(PC_sub)[2],   "\n")
cat("dim(phe)      =", nrow(phe),        "x", ncol(phe),        "\n")

## ===== choose traits =====
trait_cols <- setdiff(colnames(phe), "Taxa")
trait_cols <- trait_cols[colSums(!is.na(phe[, trait_cols, drop = FALSE])) >= 30]

cat("Number of traits to run:", length(trait_cols), "\n")

## helper: group traits
get_trait_group <- function(trait_name) {
  parts <- strsplit(trait_name, ":", fixed = TRUE)[[1]]
  if (length(parts) >= 2) paste(parts[1], parts[2], sep = "_") else "other"
}

## ===== run MLM per trait =====
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
    geno       = geno_sub,
    map        = map,
    K          = K_sub,
    CV.GLM     = PC_sub[, 1:n_pc_use, drop = FALSE],
    CV.MLM     = PC_sub[, 1:n_pc_use, drop = FALSE],
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
