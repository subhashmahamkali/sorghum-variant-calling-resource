# Sorghum Variant Calling Resource

Publication-ready resource repository for sorghum variant calling with clear
sample accounting, stepwise pipeline scripts, HCC path manifests, and run
tracking.

## Project Guideline

See:

- `docs/PROJECT_GUIDELINE.md`
- `docs/COLLABORATION_WORKFLOW.md`

## Directory System

| Directory | Purpose |
| --- | --- |
| `scripts/` | Core step scripts (`01` to `10`) |
| `scripts/manuscript_resource/` | Orchestrated submit wrappers and environment setup |
| `workflows/` | R Markdown method/runbook documents |
| `metadata/` | Curated sample lists, path manifests, run tracking, accounting |
| `profiling/` | Code and manifest inventories for reproducibility/profiling |
| `data/` | Publication-facing data/supplementary index layer |
| `docs/` | Project guideline and collaboration conventions |
| `todo/` | Task tracking scaffold |

## Sample Accounting Summary

- NEW cohort: `576 -> 571 -> 553`
- SAP cohort: `400 -> 385 -> 323`
- Core cohort: `553 + 323 = 876`
- Final cohort: `876 + 46 (ExPVP) = 922`

Primary files:

- `metadata/curated/final_922_samples.txt`
- `metadata/curated/bqsr_876_samples.txt`
- `metadata/curated/expvp_46_samples.txt`
- `metadata/curated/sample_transition_audit.xlsx`

## Step-Organized Paths (CRAM to Final VCF)

Complete path registries:

- `metadata/locations/sample_paths_922_by_step.tsv`
  - full per-sample paths for all 922 IDs
  - includes CRAM, FASTQ, alignment BAM, Picard BAM, BQSR BAM, gVCF
- `metadata/locations/step_outputs_paths.tsv`
  - step-level output/manifests
  - includes RAW joint VCF and final SNP/indel VCF outputs

Additional path/run tracking:

- `metadata/locations/storage_locations.tsv`
- `metadata/locations/hcc_manifest_paths.tsv`
- `metadata/locations/sample_artifact_path_templates.tsv`
- `metadata/run_tracking/2026-04-28_hcc_status_snapshot.tsv`
- `metadata/run_tracking/2026-04-28_slurm_submission_chain_steps06_10.tsv`

## HCC Execution Notes

- HCC runtime paths are under `/work/jyanglab/subhash/...` and `/mnt/nrdstor/...`.
- Large intermediate/final files remain on HCC and are not committed to Git.

## Manuscript Workflow

Use:

- `workflows/00_overall_resource.Rmd`
- `workflows/00_execution_runbook.Rmd`
- `scripts/manuscript_resource/README.md`

## Large Data Policy

Do not commit CRAM/FASTQ/BAM/gVCF/VCF/GenomicsDB files. Commit only scripts,
metadata, path manifests, and documentation.
