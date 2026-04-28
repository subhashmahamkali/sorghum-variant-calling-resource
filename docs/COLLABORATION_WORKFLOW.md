# Collaboration Workflow

## Branching and Commits

- Keep small, topical commits (paths, metadata, scripts, docs).
- Use descriptive commit messages with cohort/stage context.

## Required Updates per Run

For each major HCC run:

1. Append or add a snapshot file in `metadata/run_tracking/`.
2. Confirm manifests and counts in `metadata/locations/hcc_manifest_paths.tsv`.
3. If directory/pipeline expectations change, update `README.md` and
   `workflows/00_execution_runbook.Rmd`.

## Quality Checks

- `git status --short` should reflect only intended changes.
- No raw CRAM/FASTQ/BAM/VCF files should be committed.
- New metadata tables should include headers and notes columns where needed.
