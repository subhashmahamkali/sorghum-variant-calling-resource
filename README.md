# Sorghum Variant Calling Pipeline

This repository is organized as a clean, ordered workflow from CRAM files to
final filtered VCF files.

Only the pipeline scripts, one R Markdown notebook per step, and curated sample
metadata are kept here. Large data files are not stored in Git.

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

## Metadata

Curated sample lists are in `metadata/curated/`.

- `bqsr_876_samples.txt`: canonical WGS/BQSR sample list
- `expvp_46_samples.txt`: EX-pvp/Wild samples
- `final_922_samples.txt`: final combined VCF sample list
- `haplotypecaller_971_sample_sources.tsv`: HaplotypeCaller sample/source table

## Large Data Policy

Do not commit CRAM, FASTQ, BAM, gVCF, VCF, GenomicsDB workspaces, or reference
FASTA/index files. These remain on HPC storage and are referenced in the
scripts and R Markdown files.
