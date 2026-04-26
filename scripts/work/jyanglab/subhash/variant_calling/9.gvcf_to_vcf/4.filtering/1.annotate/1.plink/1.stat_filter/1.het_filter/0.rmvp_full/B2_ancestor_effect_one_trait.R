#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ============================
## 0. USER INPUTS (EDIT HERE)
## ============================

trait_id   <- "2021_plantHeight_NR"   # folder name under 1.gwas_MLM_all_traits_oldK
trait_pretty <- "2021 NR plant height"

BASE_DIR   <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"

GWAS_FILE <- file.path(
  BASE_DIR, "1.gwas_MLM_all_traits_oldK",
  trait_id, "Trait.MLM.csv"
)

# B2 top1% windows
B2_FILES <- list(
  Wild     = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/wild/wild.top1.ext5k.bed",
  Landrace = "/mnt/nrdstor/jyanglab/subhash/datasets/3.results/B2/land.top1.ext5k.bed",
  Improved = "/work/jyanglab/subhash/sorgsd/bal_s/3.input/imp/imp.top1.ext5k.bed"
)

# ancestral alleles (from wild50 on SAP SNP set)
ANC_FILE <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"

OUT_DIR  <- file.path(BASE_DIR, "4B_integration_one_trait")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

## ============================
## 1. LOAD GWAS + ANCESTRAL
## ============================

cat("Reading GWAS from:", GWAS_FILE, "\n")
gwas <- fread(GWAS_FILE)
setnames(
  gwas,
  old = c("CHROM","POS","REF","ALT","Trait.MLM"),
  new = c("chr","pos","ref","alt","p"),
  skip_absent = TRUE
)
gwas[, chr := as.character(chr)]
gwas[, pos := as.integer(pos)]
cat("  GWAS SNPs:", nrow(gwas), "\n")

cat("Reading ancestral alleles from:", ANC_FILE, "\n")
anc <- fread(ANC_FILE)
if ("Chr" %in% names(anc)) setnames(anc, "Chr", "chr")
if ("Pos" %in% names(anc)) setnames(anc, "Pos", "pos")
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]
anc_small <- anc[, .(chr, pos, anc_allele)]
rm(anc)

## ============================
## 2. FUNCTION: one population
## ============================

process_population <- function(pop_name, b2_path, gwas, anc_small, trait_id) {
  cat("\n--- Population:", pop_name, "---\n")
  cat("B2 file:", b2_path, "\n")
  
  b2 <- fread(b2_path)
  # assume BED: chr, start, end, (other cols...)
  setnames(b2, old = c("V1","V2","V3"),
              new = c("chr","start","end"), skip_absent = TRUE)
  b2[, chr   := as.character(chr)]
  b2[, start := as.integer(start)]
  b2[, end   := as.integer(end)]
  b2[, win_id := .I]
  cat("  Total B2 windows:", nrow(b2), "\n")
  
  # list to collect one top SNP (with anc) per window
  best_list <- vector("list", nrow(b2))
  n_with_any_snp       <- 0L
  n_with_snp_and_anc   <- 0L
  
  for (i in seq_len(nrow(b2))) {
    w <- b2[i]
    
    sub <- gwas[chr == w$chr & pos >= w$start & pos <= w$end]
    if (nrow(sub) == 0L) next
    n_with_any_snp <- n_with_any_snp + 1L
    
    # add ancestral allele and KEEP only SNPs that have anc_allele
    sub2 <- merge(
      sub,
      anc_small,
      by = c("chr","pos"),
      all.x = FALSE,
      all.y = FALSE
    )
    if (nrow(sub2) == 0L) next
    n_with_snp_and_anc <- n_with_snp_and_anc + 1L
    
    # most significant SNP among those with ancestral call
    top <- sub2[order(p)][1]
    top[, win_id := w$win_id]
    best_list[[i]] <- top
  }
  
  best <- rbindlist(best_list, use.names = TRUE, fill = TRUE)
  
  cat("  B2 windows with ≥1 GWAS SNP:",       n_with_any_snp,     "\n")
  cat("  B2 windows with ≥1 SNP + anc call:", n_with_snp_and_anc, "\n")
  cat("  Top SNPs with anc per window:",      nrow(best),         "\n")
  
  if (nrow(best) == 0L) return(NULL)
  
  # flip effect to ancestor-allele effect
  best[, anc_effect := fifelse(
    anc_allele == alt,  Effect,
    fifelse(anc_allele == ref, -Effect, NA_real_)
  )]
  best <- best[!is.na(anc_effect)]
  cat("  SNPs retained after REF/ALT flipping:", nrow(best), "\n")
  
  if (nrow(best) == 0L) return(NULL)
  
  # prepare cumulative curve data for this population
  best <- best[order(anc_effect)]
  best[, rank := .I]
  best[, population := pop_name]
  best[, trait := trait_id]
  
  best[, .(population, trait, anc_effect, rank)]
}

## ============================
## 3. RUN FOR 3 POPULATIONS
## ============================

curves_list <- list()

for (pop in names(B2_FILES)) {
  curves_list[[pop]] <- process_population(
    pop_name  = pop,
    b2_path   = B2_FILES[[pop]],
    gwas      = gwas,
    anc_small = anc_small,
    trait_id  = trait_id
  )
}

curves <- rbindlist(curves_list, use.names = TRUE, fill = TRUE)
if (nrow(curves) == 0L) {
  stop("No SNPs retained after integration for any population.")
}

## ============================
## 4. PLOT
## ============================

pop_cols <- c(
  "Improved" = "#4daf4a",
  "Landrace" = "#ff9900",
  "Wild"     = "#7b6dff"
)

p <- ggplot(curves,
            aes(x = anc_effect,
                y = rank,
                colour = population)) +
  geom_line() +
  geom_point(alpha = 0.6, size = 2) +
  scale_colour_manual(values = pop_cols) +
  theme_bw(base_size = 14) +
  labs(
    title = paste0("B2 (top1%)\n", trait_pretty),
    x     = "Ancestor–allele effect size",
    y     = "SNPs within B2 sweeps"
  ) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "red") +
  theme(
    plot.title      = element_text(hjust = 0, face = "bold"),
    legend.title    = element_blank(),
    legend.position = "right"
  )

print(p)

out_pdf <- file.path(OUT_DIR,
                     paste0(trait_id, "_B2_top1pct_ancestor_effect.pdf"))
out_png <- file.path(OUT_DIR,
                     paste0(trait_id, "_B2_top1pct_ancestor_effect.png"))

ggsave(out_pdf, p, width = 4, height = 5, dpi = 300)
ggsave(out_png, p, width = 4, height = 5, dpi = 300)

cat("\nSaved plots to:\n", out_pdf, "\n", out_png, "\n")
