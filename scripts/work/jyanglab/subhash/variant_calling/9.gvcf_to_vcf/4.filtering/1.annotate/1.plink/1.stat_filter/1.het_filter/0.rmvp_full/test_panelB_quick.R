#!/usr/bin/env Rscript
library(data.table)
library(ggplot2)

GWAS_FILE <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full/1.gwas_MLM_all_traits/MLM_2020_plantHeight_NR/Trait.MLM.csv"
ANC_FILE  <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"
FST_LI    <- "/work/jyanglab/subhash/sorgsd/2.pos/genload_pos/FST_LvI_top1pct_FST_peaks_merged.bed"
OUTDIR    <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full/4B_panel_B_inside_vs_outside"
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

cat("Loading GWAS...\n")
gwas <- fread(GWAS_FILE)
gwas[, chr := as.character(CHROM)]
gwas[, pos := as.integer(POS)]
gwas[, logp := -log10(Trait.MLM)]
cat("  Rows:", format(nrow(gwas), big.mark=","), "  Sig (logp>5):", sum(gwas$logp > 5, na.rm=TRUE), "\n")

cat("Loading ancestral alleles...\n")
anc <- fread(ANC_FILE)
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]

cat("Loading Fst_LI peaks...\n")
peaks <- fread(FST_LI, header = FALSE, col.names = c("chr","start","end"))
peaks[, chr := as.character(chr)]
peaks[, start := as.integer(start)]
peaks[, end := as.integer(end)]
cat("  Intervals:", nrow(peaks), "\n\n")

# Filter significant and merge ancestral
sig <- gwas[logp > 5]
sig2 <- merge(sig, anc, by = c("chr","pos"))
cat("Significant with ancestral:", nrow(sig2), "\n")

# Polarize: Effect = effect of A1 (minor allele)
sig2[, anc_effect := fifelse(
  anc_allele == A1,  Effect,
  fifelse(anc_allele == A2, -Effect, NA_real_)
)]
sig2 <- sig2[!is.na(anc_effect)]
cat("Polarized:", nrow(sig2), "\n")

# Label inside/outside using simple loop (avoids foverlaps key issues)
sig2[, in_fst_li := FALSE]
for (i in seq_len(nrow(peaks))) {
  sig2[chr == peaks$chr[i] & pos >= peaks$start[i] & pos <= peaks$end[i],
       in_fst_li := TRUE]
}

n_in  <- sum(sig2$in_fst_li)
n_out <- sum(!sig2$in_fst_li)
cat("Inside Fst_LI:", n_in, " Outside:", n_out, "\n")

# Stats
sig2[, group := fifelse(in_fst_li, "Inside", "Outside")]
cat("\n--- Summary ---\n")
print(sig2[, .(
  n = .N,
  mean_beta = round(mean(anc_effect), 4),
  median_beta = round(median(anc_effect), 4),
  frac_negative = round(mean(anc_effect < 0), 3)
), by = group])

# Plot
p <- ggplot(sig2, aes(x = anc_effect, fill = group, color = group)) +
  geom_density(alpha = 0.35, adjust = 1.2, linewidth = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  scale_fill_manual(values = c(Inside = "#C62828", Outside = "#BDBDBD")) +
  scale_color_manual(values = c(Inside = "#C62828", Outside = "#757575")) +
  theme_bw(base_size = 12) +
  theme(legend.position = c(0.85, 0.85), legend.title = element_blank()) +
  labs(x = "Ancestral allele effect size (β)", y = "Density",
       title = "TEST: plantHeight_NR — Inside vs Outside Fst(L→I)") +
  annotate("text", x = Inf, y = Inf,
           label = paste0("In: n=", n_in, "\nOut: n=", n_out),
           hjust = 1.1, vjust = 1.5, size = 3.5)

ggsave(file.path(OUTDIR, "TEST_plantHeight_NR_density.pdf"),
       p, width = 5.5, height = 4, dpi = 300)

cat("\nSaved plot. DONE.\n")
