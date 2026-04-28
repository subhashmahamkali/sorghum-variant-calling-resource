file# Sorghum Variant Calling Pipeline

This repository documents the variant-calling workflow and metadata for a
large sorghum WGS callset curated to a final **922** samples.

Only scripts, step-level workflow notebooks, and curated metadata are kept in
Git. Raw/intermediate sequencing files stay on HPC storage and are referenced
by path.

## Repository Scope

- Pipeline code: Slurm/Bash scripts in `scripts/`
- Step documentation: one R Markdown notebook per stage in `workflows/`
- Sample metadata and accounting: `metadata/`
- Storage path manifest for large files: `metadata/locations/storage_locations.tsv`

## Step Order

| Step | Script directory | R Markdown |
| ---: | --- | --- |
| 01 | `scripts/01_cram_to_fastq/` | `workflows/01_cram_to_fastq.Rmd` |
| 02 | `scripts/02_fastp_trim/` | `workflows/02_fastp_trim.Rmd` |
| 03 | `scripts/03_bwa_mem2_alignment/` | `workflows/03_bwa_mem2_alignment.Rmd` |
| 04 | `scripts/04_picard_markduplicates/` | `workflows/04_picard_markduplicates.Rmd` |
| 05 | `scripts/05_bqsr_haplotypecaller/` | `workflows/05_bqsr_haplotypecaller.Rmd` |
| 06 | `scripts/06_genomicsdb_import/` | `workflows/06_genomicsdb_import.Rmd` |
| 07 | `scripts/07_genotype_gvcfs/` | `workflows/07_genotype_gvcfs.Rmd` |
| 08 | `scripts/08_gather_raw_vcf/` | `workflows/08_gather_raw_vcf.Rmd` |
| 09 | `scripts/09_filter_snps/` | `workflows/09_filter_snps.Rmd` |
| 10 | `scripts/10_filter_indels/` | `workflows/10_filter_indels.Rmd` |

## Sample Milestones

- `metadata/curated/haplotypecaller_971_sample_sources.tsv`: 971 source rows
- `metadata/curated/bqsr_876_samples.txt`: 876 curated core samples
- `metadata/curated/expvp_46_samples.txt`: 46 ExPVP/Wild additions
- `metadata/curated/final_922_samples.txt`: final combined sample set
- `metadata/stats/sample_accounting.tsv`: count and set-consistency checks
- `metadata/curated/sample_transition_audit.xlsx`: detailed transition workbook

## Detailed Sample Accounting

### NEW run: `576 -> 571 -> 553`

- Raw NEW sequencing summary has **576** entries.
- **5 unknown** labels are excluded first, leaving **571** known NEW IDs.
- From those 571, **18 low-read** samples are removed.
- Final retained NEW set is **553**.

Arithmetic:
- `576 - 5 = 571`
- `571 - 18 = 553`

### SAP set: `400 -> 385 -> 323`

- Initial SAP list contains **400** IDs.
- Curation/archival/rename decisions reduce this to **385** SAP IDs.
- Overlap between `SAP_385` and `NEW_553` is **62** (duplicates between sets).
- Unique SAP contribution becomes **323**.

Arithmetic:
- `400 - 15 = 385`
- `385 - 62 = 323`

### Final composition

- Core set: `NEW_553 + SAP_323 = 876`
- Add ExPVP: `876 + 46 = 922`

## Source Files Used for Curation

External source files (not stored in this repo) used to build the accounting:

- `/Users/subhashmahamkali/Downloads/pf_barcode_reads_summary_v2.csv`
  - raw NEW run table (576 rows) with reads and median read length
- `/Users/subhashmahamkali/Documents/variant_calling/Book1.xlsx`
  - `NEW_571` sheet: `DirName`, `18_low_read_removal`, `553_after_removal`
  - `SAP_400` sheet: `SM`, curated `sample` (385), and duplicate tracking
  - `final_meta` sheet: `62_duplicates`

Tracked files in this repo used for final integration:

- `metadata/curated/expvp_46_samples.txt`
- `metadata/curated/bqsr_876_samples.txt`
- `metadata/curated/final_922_samples.txt`
- `metadata/curated/sample_transition_audit.xlsx`

## Large Data Policy

Do not commit CRAM, FASTQ, BAM, gVCF, VCF, GenomicsDB workspaces, or reference
FASTA/index files. Those files remain on HPC storage and should be tracked only
as path references in `metadata/locations/storage_locations.tsv`.
