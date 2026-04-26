#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ===================== ARGS =====================
## Usage:
##   Rscript run_B2_ancestor_effect_NR_category.R <CategoryName> <MetaFileName>
## Example:
##   Rscript run_B2_ancestor_effect_NR_category.R Developmental NR_Developmental_traits.tsv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Need 2 arguments: <CategoryName> <MetaFileName>")
}
CATEGORY      <- args[1]  # "Developmental", "Architecture", "Panicle", "Seed"
META_BASENAME <- args[2]  # e.g. "NR_Developmental_traits.tsv"

cat("Category:", CATEGORY, "\n")
cat("Metadata file:", META_BASENAME, "\n")

## ===================== PATHS =====================

BASE_DIR  <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
GWAS_ROOT <- file.path(BASE_DIR, "1.gwas_MLM_all_traits_oldK")

META_FILE <- file.path(BASE_DIR, META_BASENAME)

# B2 top1% windows for each population
B2_FILES <- list(
  Wild     = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/wild/wild.top1.ext5k.bed",
  Landrace = "/mnt/nrdstor/jyanglab/subhash/datasets/3.results/B2/land.top1.ext5k.bed",
  Modern   = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/imp/imp.top1.ext5k.bed"
)

# ancestral alleles computed from wild50 on SAP SNP set
ANC_FILE <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"

OUTDIR    <- file.path(BASE_DIR, "4B_integration")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)
OUT_PREFIX <- file.path(OUTDIR, paste0("NR_", CATEGORY, "_B2_top1"))

## ===================== METADATA =====================

meta <- fread(META_FILE)
if (!all(c("trait_id","gwas_folder") %in% names(meta))) {
  stop("META_FILE must have columns: trait_id, gwas_folder")
}
cat("Traits in NR-", CATEGORY, " category:\n", sep = "")
print(meta)

## ===================== ANCESTRAL =====================

anc <- fread(ANC_FILE)
if ("Chr" %in% names(anc)) setnames(anc, "Chr", "chr")
if ("Pos" %in% names(anc)) setnames(anc, "Pos", "pos")
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]
anc_small <- anc[, .(chr, pos, anc_allele)]
cat("Ancestral rows:", nrow(anc_small), "\n")

## ===================== FUNCTION: ONE TRAIT =====================

integrate_one_trait <- function(trait_id, folder_name) {
  cat("\n=== Trait:", trait_id, " (folder:", folder_name, ") ===\n")

  gwas_file <- file.path(GWAS_ROOT, folder_name, "Trait.MLM.csv")
  if (!file.exists(gwas_file)) {
    warning("  GWAS file not found: ", gwas_file, "  -> skipping.")
    return(NULL)
  }

  gwas <- fread(gwas_file)
  setnames(
    gwas,
    old = c("CHROM","POS","REF","ALT","Trait.MLM"),
    new = c("chr","pos","ref","alt","p"),
    skip_absent = TRUE
  )

  if (!all(c("chr","pos","Effect","ref","alt","p") %in% names(gwas))) {
    warning("  Missing columns for trait ", trait_id, "; skipping.")
    return(NULL)
  }

  gwas[, chr := as.character(chr)]
  gwas[, pos := as.integer(pos)]

  # for foverlaps
  gwas_int <- gwas[, .(
    chr,
    start = pos,
    end   = pos,
    SNP,
    p,
    Effect,
    ref,
    alt
  )]
  setkey(gwas_int, chr, start, end)

  trait_curves <- list()

  for (pop in names(B2_FILES)) {
    b2_path <- B2_FILES[[pop]]
    cat("  Population:", pop, "  B2 =", b2_path, "\n")

    if (!file.exists(b2_path)) {
      warning("  B2 file not found for ", pop, "; skipping.")
      next
    }

    b2 <- fread(b2_path)
    setnames(b2, old = c("V1","V2","V3"),
                 new = c("chr","start","end"), skip_absent = TRUE)
    b2[, chr   := as.character(chr)]
    b2[, start := as.integer(start)]
    b2[, end   := as.integer(end)]
    b2[, win_id := .I]
    setkey(b2, chr, start, end)

    cat("    B2 windows:", nrow(b2), "\n")

    ## GWAS ∩ B2
    ov <- foverlaps(gwas_int, b2, nomatch = 0L)
    cat("    GWAS SNPs within B2 =", nrow(ov), "\n")
    if (nrow(ov) == 0L) next

    ## add ancestral, keep only SNPs with anc call
    ov2 <- merge(
      ov,
      anc_small,
      by.x = c("chr","start"),
      by.y = c("chr","pos"),
      all.x = TRUE
    )
    ov2 <- ov2[!is.na(anc_allele)]
    cat("    SNPs with ancestral call =", nrow(ov2), "\n")
    if (nrow(ov2) == 0L) next

    ## one top SNP (lowest p) per B2 window
    best <- ov2[order(p)][, .SD[1], by = win_id]
    cat("    B2 windows with ≥1 SNP+anc =", nrow(best), "\n")

    ## flip to ancestor-allele effect
    best[, anc_effect := fifelse(
      anc_allele == alt,  Effect,
      fifelse(anc_allele == ref, -Effect, NA_real_)
    )]
    best <- best[!is.na(anc_effect)]
    cat("    SNPs retained after REF/ALT consistency =", nrow(best), "\n")
    if (nrow(best) == 0L) next

    trait_curves[[pop]] <- best[, .(
      population = pop,
      trait_id   = trait_id,
      anc_effect
    )]
  }

  if (length(trait_curves) == 0L) return(NULL)
  rbindlist(trait_curves)
}

## ===================== RUN ALL TRAITS =====================

all_curves_list <- vector("list", nrow(meta))
for (i in seq_len(nrow(meta))) {
  all_curves_list[[i]] <- integrate_one_trait(
    trait_id    = meta$trait_id[i],
    folder_name = meta$gwas_folder[i]
  )
}

all_curves <- rbindlist(all_curves_list, use.names = TRUE, fill = TRUE)
if (nrow(all_curves) == 0L) stop("No data produced for any trait.")

fwrite(all_curves,
       file = paste0(OUT_PREFIX, "_raw_points.tsv"),
       sep  = "\t")

cat("\nTotal ancestor-effect loci (all traits, all pops):",
    nrow(all_curves), "\n")

## ===================== BUILD POOLED CURVES =====================

curves_pooled <- all_curves[order(population, anc_effect)]

## rename Modern -> Improved
curves_pooled[, population :=
                fifelse(population == "Modern", "Improved", population)]

curves_pooled[, rank := seq_len(.N), by = population]

fwrite(curves_pooled,
       file = paste0(OUT_PREFIX, "_pooled_curves.tsv"),
       sep  = "\t")

## ===================== PLOT =====================

pop_cols <- c(
  "Wild"      = "#9370DB",
  "Landrace"  = "#FFA500",
  "Improved"  = "#228B22"
)

p <- ggplot(curves_pooled,
            aes(x = anc_effect, y = rank, colour = population)) +
  geom_line(size = 0.8) +
  geom_point(size = 1.8, alpha = 0.3) +  # transparency
  scale_colour_manual(values = pop_cols) +
  theme_bw(base_size = 12) +
  geom_vline(xintercept = 0,
             linetype = "dashed",
             colour   = "red") +
  labs(
    x     = "Ancestor allele effect",
    y     = "SNPs within B2 sweeps",
    title = paste0("B2 (top1%)\nNR – ", CATEGORY),
    colour = NULL
  )

pdf_file <- paste0(OUT_PREFIX, "_ImprovedWildLandrace.pdf")
png_file <- paste0(OUT_PREFIX, "_ImprovedWildLandrace.png")

ggsave(pdf_file, p, width = 4, height = 4)
ggsave(png_file, p, width = 4, height = 4, dpi = 300)

cat("\nSaved pooled NR-", CATEGORY, " plot to:\n",
    pdf_file, "\n",
    png_file, "\n", sep = "")


