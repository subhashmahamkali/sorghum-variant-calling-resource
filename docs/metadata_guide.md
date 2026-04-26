# Metadata Guide

The repository has two classes of metadata:

- `metadata/work/...`: source metadata copied from the project tree, preserving
  original paths.
- `metadata/curated/`: cleaned, human-facing tables for the GitHub resource.

## Curated Sample Files

| File | Meaning | Rows |
| --- | --- | ---: |
| `metadata/curated/bqsr_876_samples.txt` | Canonical WGS/BQSR sample list, excluding EX-pvp and Wild sample names | 876 |
| `metadata/curated/expvp_46_samples.txt` | EX-pvp plus Wild sample names from the final joint call set | 46 |
| `metadata/curated/final_922_samples.txt` | Final joint-call sample list used for QC | 922 |
| `metadata/curated/haplotypecaller_971_sample_sources.tsv` | HaplotypeCaller manifest sample and source columns | 971 data rows plus header |

## Why There Are Multiple Counts

The pasted canonical sample list corresponds to the 876 WGS/BQSR samples. The
final joint-call sample list contains 922 samples because it includes 46
additional EX-pvp/Wild samples.

The HaplotypeCaller manifest has 971 entries because it records the broader
NEW/SAP calling manifest:

- 571 NEW
- 400 SAP

This is separate from the final 922-sample joint-call/QC set.

## Source Files

The curated files were derived from:

- `metadata/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/qc_stats/samples.list`
- `metadata/work/jyanglab/subhash/4.haplotypecaller/manifests/all_samples.tsv`
- `metadata/work/jyanglab/subhash/BQSR/samples.tsv`
- `metadata/work/jyanglab/subhash/ex_pvp/BQSR_ex_pvp/samples.tsv`

## Interpretation

Use `bqsr_876_samples.txt` when referring to the main non-EX-pvp WGS sample
panel. Use `final_922_samples.txt` when referring to the final combined
joint-call VCF/QC panel.
