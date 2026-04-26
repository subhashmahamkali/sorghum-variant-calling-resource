#!/usr/bin/env Rscript
# ==============================================================================
# Figure 4 Panel B: ALL NR traits — Inside vs Outside Fst_LI peaks
# ==============================================================================

library(data.table)
library(ggplot2)

# ==============================================================================
# PATHS
# ==============================================================================
BASE_DIR  <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
GWAS_ROOT <- file.path(BASE_DIR, "1.gwas_MLM_all_traits")
ANC_FILE  <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"
FST_LI    <- "/work/jyanglab/subhash/sorgsd/2.pos/genload_pos/FST_LvI_top1pct_FST_peaks_merged.bed"
FST_WL    <- "/work/jyanglab/subhash/sorgsd/2.pos/genload_pos/FST_WvL_top1pct_FST_peaks_merged.bed"

OUTDIR <- file.path(BASE_DIR, "4B_panel_B_inside_vs_outside")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

GWAS_THRESHOLD <- 5

# ==============================================================================
# NR TRAIT LIST (hardcoded — no metadata file needed)
# ==============================================================================
traits <- data.table(
  folder = c(
    "MLM_2020_branchInternodeLength_NR",
    "MLM_2020_daysToFlower_NR",
    "MLM_2020_estimatedPlotYield_NR",
    "MLM_2020_extantLeafNumber_NR",
    "MLM_2020_flagLeafLength_NR",
    "MLM_2020_flagLeafWidth_NR",
    "MLM_2020_leafAngleStandardDeviation_NR",
    "MLM_2020_medianLeafAngle_NR",
    "MLM_2020_panicleGrainWeight_NR",
    "MLM_2020_paniclesPerPlot_NR",
    "MLM_2020_plantHeight_NR",
    "MLM_2020_primaryBranchNumber_NR",
    "MLM_2020_rachisDiameterLower_NR",
    "MLM_2020_rachisDiameterUpper_NR",
    "MLM_2020_rachisLength_NR",
    "MLM_2020_stemDiameterLower_NR",
    "MLM_2020_stemDiameterUpper_NR",
    "MLM_2020_thirdLeafLength_NR",
    "MLM_2020_thirdLeafWidth_NR",
    "MLM_2020_tillersPerPlant_NR",
    "MLM_2021_daysToFlower_NR",
    "MLM_2021_plantHeight_NR",
    "MLM_2021_stemDiameterLower_NR",
    "MLM_2021_stemDiameterUpper_NR",
    "MLM_2021_tillersPerPlant_NR"
  ),
  category = c(
    "Panicle",         # branchInternodeLength
    "Developmental",   # daysToFlower
    "Seed",            # estimatedPlotYield
    "Developmental",   # extantLeafNumber
    "Architecture",    # flagLeafLength
    "Architecture",    # flagLeafWidth
    "Architecture",    # leafAngleStandardDeviation
    "Architecture",    # medianLeafAngle
    "Seed",            # panicleGrainWeight
    "Panicle",         # paniclesPerPlot
    "Architecture",    # plantHeight
    "Panicle",         # primaryBranchNumber
    "Panicle",         # rachisDiameterLower
    "Panicle",         # rachisDiameterUpper
    "Panicle",         # rachisLength
    "Architecture",    # stemDiameterLower
    "Architecture",    # stemDiameterUpper
    "Architecture",    # thirdLeafLength
    "Architecture",    # thirdLeafWidth
    "Architecture",    # tillersPerPlant
    "Developmental",   # 2021 daysToFlower
    "Architecture",    # 2021 plantHeight
    "Architecture",    # 2021 stemDiameterLower
    "Architecture",    # 2021 stemDiameterUpper
    "Architecture"     # 2021 tillersPerPlant
  )
)

# Extract trait name from folder
traits[, trait_id := gsub("^MLM_", "", folder)]

cat("=== Panel B: All NR traits — Inside vs Outside Fst_LI ===\n")
cat("Traits to process:", nrow(traits), "\n\n")

# ==============================================================================
# LOAD SHARED DATA
# ==============================================================================
cat("Loading ancestral alleles...\n")
anc <- fread(ANC_FILE)
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]
cat("  Sites:", format(nrow(anc), big.mark=","), "\n")

cat("Loading Fst peaks...\n")
peaks_li <- fread(FST_LI, header=FALSE, col.names=c("chr","start","end"))
peaks_li[, chr := as.character(chr)]
peaks_wl <- fread(FST_WL, header=FALSE, col.names=c("chr","start","end"))
peaks_wl[, chr := as.character(chr)]
cat("  Fst_LI:", nrow(peaks_li), "intervals,", format(sum(peaks_li$end - peaks_li$start), big.mark=","), "bp\n")
cat("  Fst_WL:", nrow(peaks_wl), "intervals,", format(sum(peaks_wl$end - peaks_wl$start), big.mark=","), "bp\n\n")

# Fast overlap function using vectorized approach
label_in_peaks <- function(snp_chr, snp_pos, peaks_dt) {
  result <- rep(FALSE, length(snp_chr))
  for (i in seq_len(nrow(peaks_dt))) {
    result <- result | (snp_chr == peaks_dt$chr[i] & 
                        snp_pos >= peaks_dt$start[i] & 
                        snp_pos <= peaks_dt$end[i])
  }
  result
}

# ==============================================================================
# PROCESS ALL TRAITS
# ==============================================================================
cat("Processing GWAS results...\n\n")

all_sig <- list()
idx <- 0L
trait_summary <- list()

for (i in seq_len(nrow(traits))) {
  tid  <- traits$trait_id[i]
  fold <- traits$folder[i]
  catg <- traits$category[i]
  
  gfile <- file.path(GWAS_ROOT, fold, "Trait.MLM.csv")
  if (!file.exists(gfile)) {
    cat("  SKIP:", tid, "- file not found\n")
    next
  }
  
  gwas <- fread(gfile, showProgress = FALSE)
  gwas[, chr := as.character(CHROM)]
  gwas[, pos := as.integer(POS)]
  gwas[, logp := -log10(Trait.MLM)]
  
  sig <- gwas[is.finite(logp) & logp > GWAS_THRESHOLD]
  
  if (nrow(sig) == 0) {
    cat("  ", tid, ": 0 sig\n")
    trait_summary[[i]] <- data.table(trait_id=tid, category=catg, n_sig=0, n_polarized=0)
    next
  }
  
  # Merge ancestral
  sig2 <- merge(sig, anc[, .(chr, pos, anc_allele)], by = c("chr","pos"))
  
  # Polarize
  sig2[, anc_effect := fifelse(
    anc_allele == A1,  Effect,
    fifelse(anc_allele == A2, -Effect, NA_real_)
  )]
  sig2 <- sig2[!is.na(anc_effect)]
  
  if (nrow(sig2) == 0) {
    cat("  ", tid, ":", nrow(sig), "sig but 0 polarized\n")
    trait_summary[[i]] <- data.table(trait_id=tid, category=catg, n_sig=nrow(sig), n_polarized=0)
    next
  }
  
  sig2[, trait_id := tid]
  sig2[, category := catg]
  idx <- idx + 1
  all_sig[[idx]] <- sig2[, .(chr, pos, logp, Effect, A1, A2, anc_allele, anc_effect, trait_id, category)]
  
  cat("  ", tid, ":", nrow(sig2), "polarized sig SNPs\n")
  trait_summary[[i]] <- data.table(trait_id=tid, category=catg, n_sig=nrow(sig), n_polarized=nrow(sig2))
}

trait_tab <- rbindlist(trait_summary, fill=TRUE)
cat("\n--- Trait summary ---\n")
print(trait_tab[order(-n_polarized)])
cat("Total traits with sig SNPs:", sum(trait_tab$n_polarized > 0), "/", nrow(traits), "\n\n")

if (idx == 0) stop("No significant polarized SNPs found!")

all_snps <- rbindlist(all_sig)
cat("Total NR sig SNPs (all traits):", format(nrow(all_snps), big.mark=","), "\n")

# Deduplicate: same position → keep lowest p
all_dedup <- all_snps[order(-logp)][!duplicated(paste(chr, pos))]
cat("Unique positions:", format(nrow(all_dedup), big.mark=","), "\n\n")

# ==============================================================================
# LABEL INSIDE/OUTSIDE
# ==============================================================================
cat("Labeling inside/outside peaks...\n")
all_dedup[, in_fst_li := label_in_peaks(chr, pos, peaks_li)]
all_dedup[, in_fst_wl := label_in_peaks(chr, pos, peaks_wl)]

n_in_li  <- sum(all_dedup$in_fst_li)
n_out_li <- sum(!all_dedup$in_fst_li)
n_in_wl  <- sum(all_dedup$in_fst_wl)

cat("  Fst_LI: Inside =", n_in_li, " Outside =", n_out_li, "\n")
cat("  Fst_WL: Inside =", n_in_wl, " Outside =", sum(!all_dedup$in_fst_wl), "\n\n")

# Save full annotated table
fwrite(all_dedup, file.path(OUTDIR, "NR_all_sig_snps_annotated.tsv"), sep = "\t")

# ==============================================================================
# STATISTICS
# ==============================================================================
cat("========== STATISTICS ==========\n\n")
all_dedup[, group_li := fifelse(in_fst_li, "Inside Fst(L→I)", "Outside")]

cat("--- Fst_LI: Inside vs Outside ---\n")
stats <- all_dedup[, .(
  n = .N,
  mean_beta = round(mean(anc_effect), 4),
  median_beta = round(median(anc_effect), 4),
  sd_beta = round(sd(anc_effect), 4),
  mean_abs_beta = round(mean(abs(anc_effect)), 4),
  frac_negative = round(mean(anc_effect < 0), 3)
), by = group_li]
print(stats)
cat("\n")

if (n_in_li >= 5) {
  in_eff  <- all_dedup[in_fst_li == TRUE, anc_effect]
  out_eff <- all_dedup[in_fst_li == FALSE, anc_effect]
  
  wt <- wilcox.test(in_eff, out_eff)
  cat("Wilcoxon (inside vs outside): p =", format(wt$p.value, scientific=TRUE, digits=3), "\n")
  
  ks <- ks.test(in_eff, out_eff)
  cat("KS test: D =", round(ks$statistic, 4), ", p =", format(ks$p.value, scientific=TRUE, digits=3), "\n")
  
  wt_abs <- wilcox.test(abs(in_eff), abs(out_eff))
  cat("Wilcoxon |effect| : p =", format(wt_abs$p.value, scientific=TRUE, digits=3), "\n")
  
  tt_in <- t.test(in_eff, mu = 0)
  cat("Inside t-test vs 0: mean =", round(tt_in$estimate, 4), 
      ", p =", format(tt_in$p.value, scientific=TRUE, digits=3), "\n")
  
  tt_out <- t.test(out_eff, mu = 0)
  cat("Outside t-test vs 0: mean =", round(tt_out$estimate, 4),
      ", p =", format(tt_out$p.value, scientific=TRUE, digits=3), "\n")
}
cat("\n")

# Per-category breakdown
cat("--- By trait category ---\n")
cat_stats <- all_dedup[, .(
  n_total = .N,
  n_inside = sum(in_fst_li),
  pct_inside = round(100*mean(in_fst_li), 1),
  mean_eff_inside = round(mean(anc_effect[in_fst_li], na.rm=TRUE), 4),
  mean_eff_outside = round(mean(anc_effect[!in_fst_li], na.rm=TRUE), 4)
), by = category]
print(cat_stats)
cat("\n")

# ==============================================================================
# PLOTS
# ==============================================================================
cat("========== GENERATING PLOTS ==========\n\n")

# --- Plot 1: Main density — Inside vs Outside Fst_LI ---
p1 <- ggplot(all_dedup, aes(x = anc_effect, fill = group_li, color = group_li)) +
  geom_density(alpha = 0.35, adjust = 1.2, linewidth = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.5) +
  scale_fill_manual(values = c("Inside Fst(L→I)" = "#C62828", "Outside" = "#BDBDBD")) +
  scale_color_manual(values = c("Inside Fst(L→I)" = "#C62828", "Outside" = "#757575")) +
  theme_bw(base_size = 12) +
  theme(
    legend.position = c(0.82, 0.85),
    legend.background = element_rect(fill = alpha("white", 0.8)),
    legend.title = element_blank()
  ) +
  labs(
    x = "Ancestral allele effect size (β)",
    y = "Density",
    title = "NR GWAS hits: Inside vs Outside improvement Fst peaks"
  ) +
  annotate("text", x = Inf, y = Inf,
           label = paste0("Inside: n=", n_in_li, "\nOutside: n=", n_out_li),
           hjust = 1.1, vjust = 1.5, size = 3.2, fontface = "italic")

ggsave(file.path(OUTDIR, "PanelB_density_FstLI.pdf"), p1, width = 5.5, height = 4, dpi = 300)
cat("Saved: PanelB_density_FstLI.pdf\n")

# --- Plot 2: Faceted by trait category ---
p2 <- ggplot(all_dedup, aes(x = anc_effect, fill = group_li, color = group_li)) +
  geom_density(alpha = 0.35, adjust = 1.5, linewidth = 0.7) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.4) +
  facet_wrap(~category, nrow = 1, scales = "free_y") +
  scale_fill_manual(values = c("Inside Fst(L→I)" = "#C62828", "Outside" = "#BDBDBD")) +
  scale_color_manual(values = c("Inside Fst(L→I)" = "#C62828", "Outside" = "#757575")) +
  theme_bw(base_size = 10) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    strip.background = element_rect(fill = "grey92"),
    strip.text = element_text(face = "bold")
  ) +
  labs(x = "Ancestral allele effect size (β)", y = "Density")

ggsave(file.path(OUTDIR, "PanelB_density_FstLI_by_category.pdf"), p2, width = 10, height = 3.5, dpi = 300)
cat("Saved: PanelB_density_FstLI_by_category.pdf\n")

# --- Plot 3: Violin of absolute effects ---
p3 <- ggplot(all_dedup, aes(x = group_li, y = abs(anc_effect), fill = group_li)) +
  geom_violin(trim = FALSE, alpha = 0.5) +
  geom_boxplot(width = 0.12, outlier.size = 0.5, alpha = 0.8) +
  scale_fill_manual(values = c("Inside Fst(L→I)" = "#C62828", "Outside" = "#BDBDBD")) +
  theme_bw(base_size = 12) +
  theme(legend.position = "none") +
  labs(x = NULL, y = "|Ancestral allele effect size (β)|",
       title = "Effect magnitude: Inside vs Outside Fst(L→I)")

ggsave(file.path(OUTDIR, "PanelB_violin_FstLI.pdf"), p3, width = 4, height = 4.5, dpi = 300)
cat("Saved: PanelB_violin_FstLI.pdf\n")

# --- Plot 4: Per-trait heatmap of % inside peaks ---
trait_pct <- all_snps[, .(
  n_sig = .N,
  n_inside = sum(label_in_peaks(chr, pos, peaks_li)),
  category = category[1]
), by = trait_id]
trait_pct[, pct_inside := round(100 * n_inside / n_sig, 1)]
trait_pct <- trait_pct[n_sig >= 5][order(-pct_inside)]  # only traits with enough SNPs

if (nrow(trait_pct) > 0) {
  trait_pct[, trait_id := factor(trait_id, levels = rev(trait_id))]
  
  p4 <- ggplot(trait_pct, aes(x = pct_inside, y = trait_id, fill = category)) +
    geom_col(width = 0.7, alpha = 0.8) +
    geom_vline(xintercept = 1.6, linetype = "dashed", color = "red", linewidth = 0.5) +
    scale_fill_brewer(palette = "Set2") +
    theme_bw(base_size = 10) +
    theme(legend.position = "bottom") +
    labs(x = "% GWAS hits inside Fst(L→I) peaks",
         y = NULL, fill = "Category",
         title = "Per-trait overlap with improvement selection peaks") +
    annotate("text", x = 1.6, y = 0.5, label = "genome avg (~1.6%)",
             hjust = -0.1, size = 2.8, color = "red")
  
  ggsave(file.path(OUTDIR, "PanelB_per_trait_pct.pdf"), p4, width = 6, height = 6, dpi = 300)
  cat("Saved: PanelB_per_trait_pct.pdf\n")
}

cat("\n=== ALL DONE ===\n")
