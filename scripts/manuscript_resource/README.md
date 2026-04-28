# Manuscript Resource Orchestration

This folder provides step-level orchestration scripts for the full variant-calling
resource, organized for reproducible manuscript execution on HCC.

These scripts do not replace the underlying pipeline scripts in `scripts/01..10`.
They orchestrate them for complete cohorts and standard paths.

## Files

- `00_env.sh`: shared defaults and helper functions
- `01_prepare_hcc_directories.sh`: create required directory tree for sample-level steps
- `02_build_manifests.sh`: build core manifests used by BQSR/GenomicsDB/Genotype steps
- `03_step01_cram_to_fastq_submit.sh` ... `12_step10_filter_indels_submit.sh`: one submit wrapper per pipeline step

## Typical Usage

```bash
cd /path/to/sorghum-variant-calling-resource/scripts/manuscript_resource

# 1) Create required directory structure
bash 01_prepare_hcc_directories.sh

# 2) Build manifests for 922 integration
bash 02_build_manifests.sh

# 3) Submit each step when inputs are ready
bash 03_step01_cram_to_fastq_submit.sh
bash 04_step02_fastp_submit.sh
bash 05_step03_alignment_submit.sh
bash 06_step04_picard_submit.sh
bash 07_step05_bqsr_haplotypecaller_submit.sh
bash 08_step06_genomicsdb_import_submit.sh
bash 09_step07_genotype_gvcfs_submit.sh
bash 10_step08_gather_raw_vcf_submit.sh
bash 11_step09_filter_snps_submit.sh
bash 12_step10_filter_indels_submit.sh
```

## Notes

- Export variables before running to customize paths (see `00_env.sh`).
- Run on HCC where `/work`, `/mnt`, and Slurm (`sbatch`) are available.
- Step 01-04 usually operate on NEW-run cohorts; 06-10 operate on final 922 integration manifests.
