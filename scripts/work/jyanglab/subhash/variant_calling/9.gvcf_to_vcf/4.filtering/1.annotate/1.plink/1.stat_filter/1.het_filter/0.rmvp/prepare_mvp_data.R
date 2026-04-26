#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(rMVP)
})

plink_prefix <- "1.het_0.1_SAP"
out_dir <- file.path("0.rmvp", "geno_data")
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

max_core <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "4"))
if (is.na(max_core) || max_core < 1L) {
  max_core <- 1L
}

MVP.Data.Bfile2MVP(
  bfile = plink_prefix,
  out = file.path(out_dir, "geno"),
  maxLine = 10000
)
