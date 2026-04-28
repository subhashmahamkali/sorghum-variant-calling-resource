# Project Guideline

## Goal

This repository is a publication-ready resource for sorghum variant calling:

- reproducible pipeline scripts
- clear sample accounting
- explicit HCC runtime paths
- auditable run tracking

## Directory System

The project keeps execution code, metadata, and documentation separated.

- `scripts/`
  - canonical step scripts (`01` to `10`)
  - manuscript-level wrappers in `scripts/manuscript_resource/`
- `workflows/`
  - step notebooks and overall runbooks
- `metadata/`
  - curated sample lists, path manifests, run snapshots, and accounting
- `profiling/`
  - code inventory and profiling-oriented indices
- `data/`
  - data-index layer for supplementary outputs (no large raw/intermediate files)
- `docs/`
  - project guidelines and collaboration conventions
- `todo/`
  - active action items and planning notes

## Collaboration Workflow

1. Update curated sample/accounting files first.
2. Update path manifests and run-tracking snapshots next.
3. Keep scripts reproducible and parameterized.
4. Keep large files on HCC; commit only metadata/index files.
5. Document every major run in `metadata/run_tracking/`.

## Publication Readiness Rules

- Every figure/table should be traceable to scripts and metadata.
- Every sample cohort count should be reproducible from committed files.
- Every HCC output path used in manuscript text should be listed in
  `metadata/locations/`.
