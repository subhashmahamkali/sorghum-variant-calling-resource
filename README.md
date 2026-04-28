# Sorghum Variant Calling Pipeline

This repository documents the variant-calling workflow and metadata for a
large sorghum WGS callset curated to a final **922** samples.

Only scripts, step-level workflow notebooks, and curated metadata are kept in
Git. Raw/intermediate sequencing files stay on HCC storage and are referenced
by path manifests.

## Repository Scope

- Pipeline code: Slurm/Bash scripts in `scripts/`
- Manuscript wrappers: `scripts/manuscript_resource/`
- Step documentation: R Markdown notebooks in `workflows/`
- Sample metadata and accounting: `metadata/`

## Sample Milestones

- `metadata/curated/haplotypecaller_971_sample_sources.tsv`: 971 source rows
- `metadata/curated/bqsr_876_samples.txt`: 876 curated core samples
- `metadata/curated/expvp_46_samples.txt`: 46 ExPVP/Wild additions
- `metadata/curated/final_922_samples.txt`: final combined sample set
- `metadata/stats/sample_accounting.tsv`: count and set-consistency checks
- `metadata/curated/sample_transition_audit.xlsx`: transition audit workbook
- `metadata/curated/sample_ids_included.xlsx`: included IDs by stage
- `metadata/curated/sample_ids_removed.xlsx`: removed IDs by stage

## Detailed Sample Accounting

- NEW path: `576 -> 571 -> 553`
- SAP path: `400 -> 385 -> 323`
- Core merged set: `553 + 323 = 876`
- Final merged set: `876 + 46 (ExPVP) = 922`

## HCC Runtime Paths and Tracking

Path inventories:

- `metadata/locations/storage_locations.tsv`
- `metadata/locations/hcc_manifest_paths.tsv`
- `metadata/locations/sample_artifact_path_templates.tsv`
- `metadata/locations/sample_paths_922_by_step.tsv`
- `metadata/locations/step_outputs_paths.tsv`

Step-oriented organization in these files:

- CRAM paths
- FASTQ paths
- alignment BAM/SAM-stage paths
- Picard BAM paths
- GATK BQSR/gVCF paths
- RAW VCF path
- final SNP/indel VCF paths

HCC run tracking snapshots:

- `metadata/run_tracking/2026-04-28_hcc_status_snapshot.tsv`
- `metadata/run_tracking/2026-04-28_slurm_submission_chain_steps06_10.tsv`

## Current HCC State (Captured 2026-04-28)

- HCC repo path used for execution:
  `/home/jyanglab/subhash/sorghum-variant-calling-resource`
- Manifest counts:
  - `samples.tsv`: 876
  - `gdb_sample_map_922.tsv`: 922
  - `intervals_5mb.list`: 149
  - `genotype_5mb_manifest.tsv`: 149
  - `vcf_list_manifest_order.txt`: 149
- BQSR manifest sanity:
  - existing BAMs: 280
  - missing BAMs: 596
- gVCF sanity (sample map):
  - existing gVCFs: 922
  - missing gVCFs: 0

## Submitted SLURM Dependency Chain (Steps 06-10)

- Step 06 (`GenomicsDBImport`): Job `14996681`
- Step 07 (`GenotypeGVCFs`): Job `14996682` depends on `afterok:14996681`
- Step 08 (`GatherVcfs`): Job `14996683` depends on `afterok:14996682`
- Step 09 (`Filter SNPs`): Job `14996684` depends on `afterok:14996683`
- Step 10 (`Filter indels`): Job `14996685` depends on `afterok:14996683`

Interpretation:

- Steps 09 and 10 are waiting on Step 08 output:
  `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz`
- If Step 08 succeeds, both filters can proceed in parallel.

## Manuscript Execution Layer

Use the wrapper layer for clean, reproducible submission:

- `scripts/manuscript_resource/README.md`
- `workflows/00_overall_resource.Rmd`
- `workflows/00_execution_runbook.Rmd`

## Large Data Policy

Do not commit CRAM, FASTQ, BAM, gVCF, VCF, GenomicsDB workspaces, or reference
FASTA/index files. Keep only path references and metadata in Git.
