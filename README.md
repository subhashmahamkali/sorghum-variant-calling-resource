# Sorghum Variant Calling Resource

This repository documents the sorghum WGS variant-calling work under
`/work/jyanglab/subhash` and related CRAM storage under `/mnt/nrdstor`.

The repository is intentionally lightweight. It stores code, manifests,
metadata, inventories, and QC summaries. It does not store large sequencing or
variant files such as CRAM, FASTQ, BAM, gVCF, VCF, GenomicsDB workspaces, or
reference FASTA files.

## Project Scope

- NEW CRAM-derived WGS samples
- SAP FASTQ-derived WGS samples
- EX-pvp SRA/FASTQ samples
- BQSR and HaplotypeCaller gVCF generation
- GenomicsDB import and genotyping
- Final SNP/INDEL filtering and QC

## Key Source Locations

- `/work/jyanglab/subhash/NEW`
- `/work/jyanglab/subhash/SAP`
- `/work/jyanglab/subhash/ex_pvp`
- `/work/jyanglab/subhash/BQSR`
- `/work/jyanglab/subhash/4.haplotypecaller`
- `/work/jyanglab/subhash/6.genomicsdb_5mb`
- `/work/jyanglab/subhash/variant_calling`
- `/work/jyanglab/subhash/known_sites`
- `/work/jyanglab/subhash/multiqc_reports`
- `/mnt/nrdstor/jyanglab/subhash/sorghum_WGS_JS`

## Current Audit Summary

The audit was read-only. Original project files were not modified.

| Item | Count / status |
| --- | ---: |
| NEW CRAM paths listed | 571 |
| NEW CRAM paths existing | 571 |
| NEW trimmed FASTQs | 571 |
| NEW alignment samples listed | 571 |
| NEW Picard dedup BAMs currently visible | 280 |
| SAP Picard dedup BAMs currently visible | 323 |
| EX-pvp samples | 46 |
| EX-pvp Picard dedup BAMs | 46 |
| HaplotypeCaller manifest samples | 971 |
| HaplotypeCaller NEW samples | 571 |
| HaplotypeCaller SAP samples | 400 |
| HaplotypeCaller manifest BAM paths currently existing | 603 |
| HaplotypeCaller manifest BAM paths missing or moved | 368 |
| BQSR gVCFs | 876 |
| EX-pvp BQSR gVCFs | 46 |
| GenomicsDB 5 Mb workspaces | 149 |
| Genotype/final VCF-like files | 176 |
| Final QC samples | 922 |
| Final QC variants | 33,498,194 |
| gVCF integrity OK | 713 |
| gVCF integrity FAIL | 157 |

## Important Notes

- Git does not track empty directories. Directory structure is represented by
  README files, `.gitkeep` placeholders, and inventory files.
- Some intermediate outputs are missing or moved, especially alignment BAMs and
  some manifest BAM paths. This repository records that status rather than
  hiding it.
- Large data files should remain on HPC storage and be referenced by absolute
  paths in the inventory tables.

## Repository Layout

- `docs/`: workflow notes and audit interpretation
- `workflows/`: R Markdown workflow skeletons for CRAM/FASTQ processing and variant calling
- `metadata/`: copied manifests and sample lists
- `metadata/curated/`: cleaned canonical sample lists and sample-source tables
- `inventories/`: path inventories for large files and directories
- `scripts/`: copied pipeline scripts, preserving source context
- `reports/`: selected lightweight QC reports and summaries
- `references/`: reference and known-sites path documentation
- `logs_index/`: log-file inventories, not full logs unless small and useful
- `project_tree/`: directory layout representation of the original project

## Curated Metadata

Use these files first when checking sample identity:

- `metadata/curated/bqsr_876_samples.txt`: canonical 876 WGS/BQSR samples
- `metadata/curated/expvp_46_samples.txt`: 46 EX-pvp/Wild samples
- `metadata/curated/final_922_samples.txt`: combined final joint-call sample list
- `metadata/curated/haplotypecaller_971_sample_sources.tsv`: HaplotypeCaller sample/source table

See `docs/metadata_guide.md` for how these counts relate to each other.
