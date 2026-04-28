# Metadata Inventory

This folder tracks sample identity, sample accounting, and non-versioned storage
locations for the sorghum variant-calling pipeline.

## Curated Lists (`metadata/curated/`)

- `haplotypecaller_971_sample_sources.tsv`
  - master table of HaplotypeCaller inputs and source cohort labels (`NEW`/`SAP`)
- `bqsr_876_samples.txt`
  - canonical post-curation sample list used through BQSR pipeline steps
- `expvp_46_samples.txt`
  - ExPVP/Wild additions used to build final combined sample set
- `final_922_samples.txt`
  - final sample IDs expected in downstream combined VCF analyses

## Stats (`metadata/stats/`)

- `sample_accounting.tsv`
  - reproducible counts for key sample milestones and set-relationship checks

## Storage Locations (`metadata/locations/`)

- `storage_locations.tsv`
  - canonical path manifest for raw inputs, intermediate outputs, and final VCFs
  - this file stores path references only; large files remain outside Git
