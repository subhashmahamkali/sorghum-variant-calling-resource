#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ===================== ARGS =====================
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Need 2 arguments: <CategoryName> <MetaFileName>")

CATEGORY      <- args[1]
META_BASENAME <- args[2]

cat("Category:", CATEGORY, "\n")
cat("Metadata:", META_BASENAME, "\n")

## ===================== PATHS =====================

BASE_DIR  <- "/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
GWAS_ROOT <- file.path(BASE_DIR, "1.gwas_MLM_all_traits_oldK")

META_FILE <- file.path(BASE_DIR, META_BASENAME)

## ------------ POSITIVE SELECTION WINDOWS (FST top1%) --------------
POS_FILES <- list(
  Landrace = "/work/jyanglab/subhash/sorgsd/2.pos/genload_pos/FST_WvL_top1pct_FST_peaks_merged.bed",
  Improved = "/work/jyanglab/subhash/sorgsd/2.pos/genload_pos/FST_LvI_top1pct_FST_peaks_merged.bed"
)

## ancestral alleles
ANC_FILE <- "/work/jyanglab/subhash/sorgsd/bal_s/sorghum_wild50_ancestral_alleles.tsv"

## output directory
OUTDIR <- file.path(BASE_DIR, "4B_integration_pos")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

OUT_PREFIX <- file.path(OUTDIR, paste0("NR_", CATEGORY, "_PosSel_top1"))

## ===================== LOAD METADATA =====================

meta <- fread(META_FILE)
if (!all(c("trait_id","gwas_folder") %in% names(meta))) {
  stop("META must contain: trait_id, gwas_folder")
}

## ===================== LOAD ANCESTRAL ALLELES =====================

anc <- fread(ANC_FILE)
setnames(anc, old=c("Chr","Pos"), new=c("chr","pos"), skip_absent=TRUE)
anc[, chr := as.character(chr)]
anc[, pos := as.integer(pos)]
anc_small <- anc[, .(chr,pos,anc_allele)]

## ===================== FUNCTION FOR ONE POP × TRAIT =====================

process_one_pop_one_trait <- function(pop_name, pos_path, gwas, anc_small, trait_id) {
  
  cat("\n=== Trait:", trait_id, " Population:", pop_name, "===\n")
  
  pos <- fread(pos_path)
  setnames(pos, old=c("V1","V2","V3"), new=c("chr","start","end"))
  pos[, chr := as.character(chr)]
  pos[, start := as.integer(start)]
  pos[, end := as.integer(end)]
  pos[, win_id := .I]
  
  best_list <- list()
  idx <- 0L
  
  for (i in seq_len(nrow(pos))) {
    w <- pos[i]
    sub <- gwas[chr==w$chr & pos>=w$start & pos<=w$end]
    if (nrow(sub)==0) next
    
    ## merge ancestral
    sub2 <- merge(sub, anc_small, by=c("chr","pos"))
    if (nrow(sub2)==0) next
    
    top <- sub2[order(p)][1]
    top[, win_id := w$win_id]
    
    idx <- idx + 1
    best_list[[idx]] <- top
  }
  
  if (idx==0) return(NULL)
  
  best <- rbindlist(best_list)
  
  ## effect orientation
  best[, anc_effect := fifelse(
    anc_allele == alt, Effect,
    fifelse(anc_allele == ref, -Effect, NA_real_)
  )]
  
  best <- best[!is.na(anc_effect)]
  if (nrow(best)==0) return(NULL)
  
  best[, .(population=pop_name, trait_id, anc_effect)]
}

## ===================== PROCESS ALL TRAITS =====================

all_res <- list()
idx <- 0L

for (i in seq_len(nrow(meta))) {
  
  trait_id <- meta$trait_id[i]
  folder   <- meta$gwas_folder[i]
  
  cat("\n##### Running:", trait_id, "#####\n")
  
  gfile <- file.path(GWAS_ROOT, folder, "Trait.MLM.csv")
  if (!file.exists(gfile)) {
    warning("Missing GWAS:", gfile)
    next
  }
  
  gwas <- fread(gfile)
  setnames(gwas,
           old=c("CHROM","POS","REF","ALT","Trait.MLM"),
           new=c("chr","pos","ref","alt","p"), skip_absent=TRUE)
  gwas[, chr := as.character(chr)]
  gwas[, pos := as.integer(pos)]
  
  for (pop in names(POS_FILES)) {
    res <- process_one_pop_one_trait(pop, POS_FILES[[pop]], gwas, anc_small, trait_id)
    if (!is.null(res)) {
      idx <- idx + 1
      all_res[[idx]] <- res
    }
  }
}

pos_all <- rbindlist(all_res, fill=TRUE)

fwrite(pos_all, paste0(OUT_PREFIX, "_raw_points.tsv"), sep="\t")

## ===================== BUILD CUMULATIVE CURVES =====================

curve <- pos_all[order(population, anc_effect)]
curve[, rank := seq_len(.N), by=population]

fwrite(curve, paste0(OUT_PREFIX, "_pooled_curves.tsv"), sep="\t")

## ===================== PLOT =====================

cols <- c(
  Landrace = "#E69F00",
  Improved = "#009E73"
)

p <- ggplot(curve, aes(x=anc_effect, y=rank, color=population)) +
  geom_line(linewidth=0.8) +
  geom_point(size=1.6, alpha=0.6) +
  scale_color_manual(values=cols) +
  geom_vline(xintercept=0, linetype="dashed") +
  theme_bw(base_size=13) +
  labs(
    title = paste0("Positive Selection (top1%) – NR ", CATEGORY),
    x = "Ancestral-allele effect size (beta)",
    y = "SNPs within selection sweeps",
    color = "Population"
  )

ggsave(paste0(OUT_PREFIX, "_plot.pdf"), p, width=4.3, height=3.5, dpi=300)

cat("\nDONE.\n")
