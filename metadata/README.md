# Metadata Inventory

This folder tracks sample identity, sample accounting, non-versioned storage
locations, and HCC run-status snapshots for the sorghum variant-calling
pipeline.

## Curated Lists (`metadata/curated/`)

- `haplotypecaller_971_sample_sources.tsv`
  - master table of HaplotypeCaller inputs and source cohort labels (`NEW`/`SAP`)
- `bqsr_876_samples.txt`
  - canonical post-curation sample list used through BQSR pipeline steps
- `expvp_46_samples.txt`
  - ExPVP/Wild additions used to build final combined sample set
- `final_922_samples.txt`
  - final sample IDs expected in downstream combined VCF analyses
- `sample_transition_audit.xlsx`
  - consolidated transition workbook (`576->571->553`, `400->385->323`, `+46`)
- `sample_ids_included.xlsx`
  - included IDs by transition stage
- `sample_ids_removed.xlsx`
  - removed IDs by transition stage

## Stats (`metadata/stats/`)

- `sample_accounting.tsv`
  - reproducible counts for key sample milestones and set-relationship checks

## Storage Locations (`metadata/locations/`)

- `storage_locations.tsv`
  - canonical path manifest for raw inputs, intermediate outputs, and final VCFs
- `hcc_manifest_paths.tsv`
  - explicit manifest/output file paths and observed row counts on HCC
- `sample_artifact_path_templates.tsv`
  - per-step artifact path templates for sample-level and interval-level outputs
- `sample_paths_922_by_step.tsv`
  - fully expanded per-sample path table (922 rows) from CRAM through GATK gVCF outputs
- `step_outputs_paths.tsv`
  - clean step-level path registry including RAW VCF and final SNP/indel VCF outputs

## Run Tracking (`metadata/run_tracking/`)

- `2026-04-28_hcc_status_snapshot.tsv`
  - captured HCC counts and sanity-check summary
- `2026-04-28_slurm_submission_chain_steps06_10.tsv`
  - submitted job IDs and dependency chain for Steps 06-10
