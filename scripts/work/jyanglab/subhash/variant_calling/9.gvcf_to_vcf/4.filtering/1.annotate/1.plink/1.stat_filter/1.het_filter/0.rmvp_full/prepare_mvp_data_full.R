#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(rMVP)
})

# ---- inputs ----
work_dir    <- "/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter"
setwd(work_dir)

plink_prefix <- "1.het_0.1_SAP"   # uses .bed/.bim/.fam in work_dir

out_dir <- file.path(work_dir, "0.rmvp_full", "geno_data")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# how many cores did SLURM give?
max_core <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "4"))
if (is.na(max_core) || max_core < 1L) max_core <- 1L

cat("Using", max_core, "cores\n")
cat("Working dir:", work_dir, "\n")

MVP.Data(
  fileBed  = plink_prefix,
  out      = file.path(out_dir, "geno"),
  filePC   = TRUE,          # <– instead of eigenOut
  fileKin  = TRUE,          # <– instead of kinshipOut
  type     = "char",
  maxCore  = max_core,
  maxLine  = 20000
)
