#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## =====================
## 0. Paths
## =====================
base_dir <- "/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results"
setwd(base_dir)

gt_file      <- file.path(base_dir, "gtcheck.genome.summary.txt")
out_table    <- file.path(base_dir, "RNA_WGS_genome_concordance_sameID.tsv")
out_plot_pdf <- file.path(base_dir, "RNA_WGS_genome_concordance_sameID.pdf")

cat("[R] Reading gtcheck summary from:", gt_file, "\n")

## =====================
## 1. Load gtcheck summary (raw)
## =====================
gt_raw <- fread(gt_file,
                header = FALSE,
                fill   = TRUE,
                quote  = "")

cat("[R] Rows in raw table:", nrow(gt_raw), "  ncol:", ncol(gt_raw), "\n")

## Remove header (#...) and INFO lines
gt_raw <- gt_raw[!grepl("^#",  V1)]
gt_raw <- gt_raw[!grepl("^INFO", V1)]

## =====================
## 2. Parse columns (handles both real tabs and literal \"\\t\")
## =====================
if (ncol(gt_raw) == 1) {
  # case like we saw before: everything in V1 with literal \t
  cols <- tstrsplit(gt_raw$V1, "\t", fixed = TRUE)
  gt <- data.table(
    Method   = cols[[1]],
    WGS      = cols[[2]],
    RNA      = cols[[3]],
    Score    = as.numeric(cols[[4]]),
    PL_ratio = as.numeric(cols[[5]]),
    N_sites  = as.integer(cols[[6]]),
    N_match  = as.integer(cols[[7]])
  )
} else {
  # normal case: already split into columns
  gt <- gt_raw[, .(Method = V1,
                   WGS    = V2,
                   RNA    = V3,
                   Score  = as.numeric(V4),
                   PL_ratio = as.numeric(V5),
                   N_sites  = as.integer(V6),
                   N_match  = as.integer(V7))]
}

cat("[R] Rows after cleanup:", nrow(gt), "\n")
print(head(gt))

## =====================
## 3. Keep only SAME sample IDs (RNA vs WGS)
## =====================
same <- gt[WGS == RNA & !is.na(N_sites) & N_sites > 0]

cat("[R] Matching-sample rows:", nrow(same), "\n")

## =====================
## 4. Compute concordance
## =====================
same[, Concordance := N_match / N_sites]

cat("[R] Concordance summary:\n")
print(summary(same$Concordance))

## Save table
fwrite(same, out_table, sep = "\t")
cat("[R] Wrote table:", out_table, "\n")

## =====================
## 5. Plot concordance (one dot per sample)
## =====================
same_ord <- same[order(Concordance)]
same_ord[, Sample := factor(RNA, levels = RNA)]

p <- ggplot(same_ord,
            aes(x = Concordance,
                y = Sample)) +
  geom_point(size = 0.6) +
  coord_flip() +
  theme_bw(base_size = 10) +
  theme(
    axis.text.y = element_text(size = 4),
    panel.grid.major.y = element_blank()
  ) +
  labs(
    title = "WGS vs RNA-seq genotype concordance (genome-wide, same IDs)",
    x     = "Concordance (N_match / N_sites)",
    y     = "Sample (RNA & WGS ID)"
  )

ggsave(out_plot_pdf, p, width = 6, height = 10, useDingbats = FALSE)
cat("[R] Saved plot to:", out_plot_pdf, "\n")
