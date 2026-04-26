# Workflow Overview

## 1. NEW CRAM-Derived Samples

CRAM paths were listed in:

- `/work/jyanglab/subhash/NEW/1.fastq/piscbt_crams.list`

The listed CRAM files are stored under:

- `/mnt/nrdstor/jyanglab/subhash/sorghum_WGS_JS/426983-20250723_1818`

The NEW workflow includes CRAM-derived FASTQ processing, trimming with fastp,
alignment with bwa-mem2 and samtools, and duplicate removal with Picard.

## 2. SAP FASTQ-Derived Samples

SAP inputs and intermediate data are under:

- `/work/jyanglab/subhash/SAP/fastq`
- `/work/jyanglab/subhash/SAP/trimmed`
- `/work/jyanglab/subhash/SAP/alignment`
- `/work/jyanglab/subhash/SAP/picard`

The SAP Picard deduplication outputs are under:

- `/work/jyanglab/subhash/SAP/picard/dedup_trimmed`

## 3. EX-pvp Samples

EX-pvp data are under:

- `/work/jyanglab/subhash/ex_pvp`

The audit found 46 EX-pvp samples, with 46 Picard deduplicated BAMs and 46 BQSR
gVCFs.

## 4. BQSR and HaplotypeCaller

Primary HaplotypeCaller manifest:

- `/work/jyanglab/subhash/4.haplotypecaller/manifests/all_samples.tsv`

The manifest contains 971 samples:

- 571 NEW
- 400 SAP

The BQSR/gVCF output area is:

- `/work/jyanglab/subhash/BQSR/gvcf`

## 5. GenomicsDB and Joint Genotyping

GenomicsDB 5 Mb workflow is under:

- `/work/jyanglab/subhash/6.genomicsdb_5mb`

Important subdirectories:

- `intervals/`
- `sample_maps/`
- `workspaces/`
- `genotype_vcfs/`
- `genotype_vcfs/final_vcf/`

## 6. Final VCF and QC

Final VCF and QC outputs are under:

- `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf`

Important final files include filtered SNP and INDEL VCFs, sample QC tables,
heterozygosity/missingness tables, replicate concordance outputs, and WGS/RNA
concordance summaries.
