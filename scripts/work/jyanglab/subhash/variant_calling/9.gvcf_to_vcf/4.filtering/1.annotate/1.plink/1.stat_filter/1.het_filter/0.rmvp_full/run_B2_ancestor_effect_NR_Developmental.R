#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ===================== USER PATHS =====================

BASE_DIR <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"

GWAS_ROOT <- file.path(BASE_DIR, "1.gwas_MLM_all_traits_oldK")

META_FILE <- file.path(BASE_DIR, "NR_Developmental_traits.tsv")

## top1% B2 windows
B2_FILES <- list(
  Wild     = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/wild/wild.top1.ext5k.bed",
  Landrace = "/mnt/nrdstor/jyanglab/subhash/datasets/3.results/B2/land.top1.ext5k.bed",
  Modern   = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/imp/imp.top1.ext5k.bed"
)

## ancestral alleles from wild 50
ANC_FILE <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"

OUTDIR  <- file.path(BASE_DIR, "4B_integration")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

OUT_PREFIX <- file.path(OUTDIR, "NR_Developmental_B2_top1")

## ===================== READ METADATA =====================

meta <- fread(META_FILE)
if (!all(c("trait_id","gwas_folder") %in% names(meta))) {
  stop("META_FILE must have columns: trait_id, gwas_folder")
}
cat("Traits in NR-Developmental category:\n")
print(meta)

## ===================== LOAD ANCESTRAL =====================

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
    warning("  GWAS file not found: ", gwas_file, "  -> skipping this trait.")
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
    warning("  GWAS columns missing for trait ", trait_id, "; skipping.")
    return(NULL)
  }

  gwas[, chr := as.character(chr)]
  gwas[, pos := as.integer(pos)]
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

  ## container for this trait & all populations
  trait_curves <- list()

  for (pop in names(B2_FILES)) {

    b2_path <- B2_FILES[[pop]]
    cat("  Population:", pop, "  B2 =", b2_path, "\n")

    if (!file.exists(b2_path)) {
      warning("  B2 file not found for ", pop, "; skipping.")
      next
    }

    b2 <- fread(b2_path)
    setnames(b2, old = c("V1","V2","V3"), new = c("chr","start","end"), skip_absent = TRUE)

    b2[, chr   := as.character(chr)]
    b2[, start := as.integer(start)]
    b2[, end   := as.integer(end)]
    b2[, win_id := .I]
    setkey(b2, chr, start, end)

    cat("    B2 windows:", nrow(b2), "\n")

    ## overlap GWAS with B2
    ov <- foverlaps(gwas_int, b2, nomatch = 0L)
    cat("    GWAS SNPs within B2 =", nrow(ov), "\n")
    if (nrow(ov) == 0L) next

    ## merge with ancestry *before* picking best SNP,
    ## so we can pick the best SNP that actually has anc_allele
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

    ## one best (lowest p) with anc info per B2 window
    best <- ov2[order(p)][, .SD[1], by = win_id]
    cat("    B2 windows with ≥1 SNP+anc =", nrow(best), "\n")

    ## convert to ancestor-allele effect
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

all_curves_list <- list()

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

cat("\nTotal ancestor-effect loci (all traits, all pops):", nrow(all_curves), "\n")

## ===================== BUILD POOLED ECDF PER POPULATION =====================

curves_pooled <- all_curves[order(population, anc_effect)]
curves_pooled[, rank := seq_len(.N), by = population]

fwrite(curves_pooled,
       file = paste0(OUT_PREFIX, "_pooled_curves.tsv"),
       sep  = "\t")

## ===================== PLOT =====================

#pop_cols <- c(
 #"Wild"     = "#9370DB",
  #"Landrace" = "#FFA500",
  #"Modern"   = "#228B22"
#)

#p <- ggplot(curves_pooled,
            #aes(x = anc_effect, y = rank, colour = population)) +
  #geom_line() +
  #geom_point(size = 0.8) +
  #scale_colour_manual(values = pop_cols) +
  #theme_bw(base_size = 12) +
  #geom_vline(xintercept = 0, linetype = "dashed", colour = "red") +
  #labs(
    #x = "Ancestor-allele effect size (all NR Developmental traits)",
    #y = "SNPs within B2 top1% sweeps",
    #title = "Balancing selection (top1%)\nNR – Developmental category",
    #colour = NULL
  #)

#ggsave(paste0(OUT_PREFIX, ".pdf"), p, width = 4, height = 4)
#ggsave(paste0(OUT_PREFIX, ".png"), p, width = 4, height = 4, dpi = 300)

#cat("\nSaved pooled NR-Developmental plot to:\n",
    #paste0(OUT_PREFIX, ".pdf"), "\n",
    #paste0(OUT_PREFIX, ".png"), "\n")
## ===================== UPDATED PLOT =====================

# Rename Modern → Improved
curves_pooled[, population := fifelse(population == "Modern", "Improved", population)]

# Updated colors
pop_cols <- c(
  "Wild"      = "#4DAF4A",   # purple, transparent
  "Landrace"  = "#FF5733",   # orange, transparent
  "Improved"  = "#EBFF33"    # green, transparent
)

p <- ggplot(curves_pooled,
            aes(x = anc_effect, y = rank, colour = population)) +
  geom_line(size = 0.8) +
  geom_point(size = 1.8, alpha = 0.6) +   # << transparency here
  scale_colour_manual(values = pop_cols) +
  theme_bw(base_size = 12) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "red") +
  labs(
    x = "Ancestor–allele effect size",
    y = "SNPs within selection sweeps",
    title = "B2(top1%)\nNR Developmental trait",
    colour = NULL
  )

ggsave(paste0(OUT_PREFIX, "_ImprovedWildLandrace.pdf"), p, width = 4, height = 4)
ggsave(paste0(OUT_PREFIX, "_ImprovedWildLandrace.png"), p, width = 4, height = 4, dpi = 300)
