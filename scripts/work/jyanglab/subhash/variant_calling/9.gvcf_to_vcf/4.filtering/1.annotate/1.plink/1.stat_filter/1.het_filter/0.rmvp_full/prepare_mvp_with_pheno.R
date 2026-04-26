#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(rMVP)
  library(data.table)
})

base_dir <- "/lustre/work/jyanglab/subhash/variant_calling/9.gvcf_to_vcf/4.filtering/1.annotate/1.plink/1.stat_filter/1.het_filter/0.rmvp_full"
setwd(base_dir)

plink_prefix <- "../1.het_0.1_SAP"   # go one level up from 0.rmvp_full
pheno_file   <- "BLUEs_SAP2020_2021_pheno_clean.csv"

out_prefix   <- file.path(base_dir, "mvp_SAP_pheno")

# how many cores from SLURM?
max_core <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "4"))
if (is.na(max_core) || max_core < 1L) max_core <- 1L

cat("Using", max_core, "cores\n")
cat("PLINK prefix:", plink_prefix, "\n")
cat("Phenotype   :", pheno_file, "\n")
cat("Output      :", out_prefix, "\n")

MVP.Data(
  fileBed  = plink_prefix,
  filePhe  = pheno_file,
  filePC   = TRUE,
  fileKin  = TRUE,
  type     = "char",
  maxCore  = max_core,
  maxLine  = 20000,
  out      = out_prefix
)

cat("Done preparing MVP data with phenotype.\n")
