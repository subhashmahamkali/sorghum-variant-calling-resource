#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ===================== ARGS =====================
## Usage: Rscript run_B2_ancestor_effect_NR_category_fixed.R <CategoryName> <MetaFileName>
## Example:
##   Rscript run_B2_ancestor_effect_NR_category_fixed.R Developmental NR_Developmental_traits.tsv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Need 2 arguments: <CategoryName> <MetaFileName>")
}
CATEGORY      <- args[1]          # e.g. "Developmental"
META_BASENAME <- args[2]          # e.g. "NR_Developmental_traits.tsv"

cat("Category:", CATEGORY, "\n")
cat("Metadata file:", META_BASENAME, "\n")

## ===================== PATHS =====================

BASE_DIR  <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
GWAS_ROOT <- file.path(BASE_DIR, "1.gwas_MLM_all_traits_oldK")

META_FILE <- file.path(BASE_DIR, META_BASENAME)

B2_FILES <- list(
  Wild     = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/wild/wild.top1.ext5k.bed",
  Landrace = "/mnt/nrdstor/jyanglab/subhash/datasets/3.results/B2/land.top1.ext5k.bed",
  Improved = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/imp/imp.top1.ext5k.bed"
)

ANC_FILE <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"

OUTDIR    <- file.path(BASE_DIR, "4B_integration")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

OUT_PREFIX <- file.path(OUTDIR, paste0("NR_", CATEGORY, "_B2_top1"))

## ===================== METADATA =====================

meta <- fread(META_FILE)
if (!all(c("trait_id","gwas_folder") %in% names(meta))) {
  stop("META_FILE must have columns: trait_id, gwas_folder")
}
cat("Traits in NR-", CATEGORY, "category:\n", sep = "")
print(meta)

## ===================== ANCESTRAL =====================

anc <- fread(ANC_FILE)
if ("Chr" %in% names(anc)) setnames(anc, "Chr", "chr")
if ("Pos" %in% names(anc)) setnames(anc, "Pos", "pos")
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]
anc_small <- anc[, .(chr, pos, anc_allele)]
rm(anc)

cat("Ancestral rows:", nrow(anc_small), "\n")

## ===================== FUNCTION: ONE POP FOR ONE TRAIT =====================

process_one_pop_one_trait <- function(pop_name, b2_path, gwas, anc_small, trait_id) {
  cat("\n--- Trait:", trait_id, "  Population:", pop_name, "---\n")
  cat("  B2 file:", b2_path, "\n")
  
  b2 <- fread(b2_path)
  setnames(b2, old = c("V1","V2","V3"),
              new = c("chr","start","end"), skip_absent = TRUE)
  b2[, chr   := as.character(chr)]
  b2[, start := as.integer(start)]
  b2[, end   := as.integer(end)]
  b2[, win_id := .I]
  cat("  Total B2 windows:", nrow(b2), "\n")
  
  best_list            <- vector("list", nrow(b2))
  n_with_any_snp       <- 0L
  n_with_snp_and_anc   <- 0L
  
  for (i in seq_len(nrow(b2))) {
    w <- b2[i]
    
    # all GWAS SNPs in this B2 window
    sub <- gwas[chr == w$chr & pos >= w$start & pos <= w$end]
    if (nrow(sub) == 0L) next
    n_with_any_snp <- n_with_any_snp + 1L
    
    # add ancestral & keep only SNPs with anc_allele
    sub2 <- merge(
      sub,
      anc_small,
      by = c("chr","pos"),
      all.x = FALSE,
      all.y = FALSE
    )
    if (nrow(sub2) == 0L) next
    n_with_snp_and_anc <- n_with_snp_and_anc + 1L
    
    # best SNP (lowest p) among those WITH ancestral call
    top <- sub2[order(p)][1]
    top[, win_id := w$win_id]
    best_list[[i]] <- top
  }
  
  best <- rbindlist(best_list, use.names = TRUE, fill = TRUE)
  
  cat("  B2 windows with ≥1 GWAS SNP:",           n_with_any_snp,     "\n")
  cat("  B2 windows with ≥1 SNP + ancestral:",    n_with_snp_and_anc, "\n")
  cat("  Top SNPs (per window) with ancestral:",  nrow(best),         "\n")
  
  if (nrow(best) == 0L) return(NULL)
  
  # ancestor-allele effect
  best[, anc_effect := fifelse(
    anc_allele == alt,  Effect,
    fifelse(anc_allele == ref, -Effect, NA_real_)
  )]
  best <- best[!is.na(anc_effect)]
  cat("  SNPs retained after REF/ALT flipping:", nrow(best), "\n")
  
  if (nrow(best) == 0L) return(NULL)
  
  best[, .(
    population = pop_name,
    trait_id   = trait_id,
    anc_effect
  )]
}

## ===================== FUNCTION: ONE TRAIT OVER ALL POPS =====================

integrate_one_trait <- function(trait_id, folder_name) {
  cat("\n==============================\n")
  cat("Trait:", trait_id, "  (folder:", folder_name, ")\n")
  cat("==============================\n")
  
  gwas_file <- file.path(GWAS_ROOT, folder_name, "Trait.MLM.csv")
  if (!file.exists(gwas_file)) {
    warning("  GWAS file not found: ", gwas_file, " -> skipping trait.")
    return(NULL)
  }
  
  gwas <- fread(gwas_file)
  setnames(
    gwas,
    old = c("CHROM","POS","REF","ALT","Trait.MLM"),
    new = c("chr","pos","ref","alt","p"),
    skip_absent = TRUE
  )
  
  need_cols <- c("chr","pos","ref","alt","Effect","p")
  if (!all(need_cols %in% names(gwas))) {
    warning("  Missing columns in GWAS for trait ", trait_id, " -> skipping.")
    return(NULL)
  }
  
  gwas[, chr := as.character(chr)]
  gwas[, pos := as.integer(pos)]
  
  trait_list <- list()
  for (pop in names(B2_FILES)) {
    trait_list[[pop]] <- process_one_pop_one_trait(
      pop_name  = pop,
      b2_path   = B2_FILES[[pop]],
      gwas      = gwas,
      anc_small = anc_small,
      trait_id  = trait_id
    )
  }
  
  trait_curves <- rbindlist(trait_list, use.names = TRUE, fill = TRUE)
  trait_curves
}

## ===================== RUN ALL TRAITS =====================

all_curves_list <- list()
for (i in seq_len(nrow(meta))) {
  all_curves_list[[i]] <- integrate_one_trait(
    trait_id    = meta$trait_id[i],
    folder_name = meta$gwas_folder[i]
  )
}

all_curves <- rbindlist(all_curves_list, use.names = TRUE, fill = TRUE)
if (nrow(all_curves) == 0L) stop("No data produced for any trait in this category.")

fwrite(all_curves,
       file = paste0(OUT_PREFIX, "_raw_points.tsv"),
       sep  = "\t")

cat("\nTotal ancestor-effect loci (all traits, all populations):", nrow(all_curves), "\n")

## ===================== BUILD POOLED CURVES PER POP =====================

curves_pooled <- all_curves[order(population, anc_effect)]
curves_pooled[, rank := seq_len(.N), by = population]

fwrite(curves_pooled,
       file = paste0(OUT_PREFIX, "_pooled_curves.tsv"),
       sep  = "\t")

## ===================== PLOT =====================

pop_cols <- c(
  "Wild"     = "#7b6dff",
  "Landrace" = "#ff9900",
  "Improved" = "#4daf4a"
)

p <- ggplot(curves_pooled,
            aes(x = anc_effect,
                y = rank,
                colour = population)) +
  geom_line(size = 0.8) +
  geom_point(size = 1.8, alpha = 0.6) +
  scale_colour_manual(values = pop_cols) +
  theme_bw(base_size = 12) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "red") +
  labs(
    x = paste0("Ancestor–allele effect size (NR ", CATEGORY, " traits)"),
    y = "SNPs within B2 top1% sweeps",
    title = paste0("Balancing selection (top1%)\nNR – ", CATEGORY, " category"),
    colour = NULL
  )

ggsave(paste0(OUT_PREFIX, "_ImprovedWildLandrace.pdf"), p, width = 4, height = 4)
ggsave(paste0(OUT_PREFIX, "_ImprovedWildLandrace.png"), p, width = 4, height = 4, dpi = 300)

cat("\nSaved pooled NR-", CATEGORY, " plot to:\n",
    paste0(OUT_PREFIX, "_ImprovedWildLandrace.pdf"), "\n",
    paste0(OUT_PREFIX, "_ImprovedWildLandrace.png"), "\n", sep = "")
