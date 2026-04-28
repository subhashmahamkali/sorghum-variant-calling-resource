# Sorghum Variant Calling Resource

Publication-ready repository for sorghum variant calling on HCC, from raw CRAM
files to final filtered VCF outputs.

This repo stores scripts, metadata, path manifests, and documentation.
Large raw/intermediate outputs stay on HCC storage.

## HCC Base Paths

- Repo (HCC): `/home/jyanglab/subhash/sorghum-variant-calling-resource`
- Raw CRAM root: `/mnt/nrdstor/jyanglab/subhash/sorghum_WGS_JS`
- NEW processing root: `/work/jyanglab/subhash/NEW`
- BQSR root: `/work/jyanglab/subhash/BQSR`
- Joint-calling root: `/work/jyanglab/subhash/6.genomicsdb_5mb`
- Reference FASTA:
  `/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa`
- Known sites VCF:
  `/work/jyanglab/subhash/known_sites/known_sites_merged.num.renamed.vcf.gz`

## Cohorts and Sample Accounting

- NEW: `576 -> 571 -> 553`
- SAP: `400 -> 385 -> 323`
- Core: `553 + 323 = 876`
- Final: `876 + 46 (ExPVP) = 922`

Key files:

- `metadata/curated/final_922_samples.txt`
- `metadata/curated/bqsr_876_samples.txt`
- `metadata/curated/expvp_46_samples.txt`
- `metadata/curated/sample_transition_audit.xlsx`

## End-to-End Workflow (CRAM to VCF)

### Step 01: CRAM -> FASTQ

- Script(s):
  - `scripts/01_cram_to_fastq/01_prepare_cram_list_and_submit.sh`
  - `scripts/01_cram_to_fastq/02_cram_to_fastq_array.sh`
- Tools: `samtools`, `pigz/gzip`
- What happens:
  - Find CRAMs under `/mnt/nrdstor/...`
  - Convert per sample to `R1`, `R2`, `unpaired`, `single` FASTQ
- Output path pattern:
  - `/work/jyanglab/subhash/NEW/1.fastq/<sample>/`

### Step 02: fastp trimming (unpaired)

- Script(s):
  - `scripts/02_fastp_trim/prepare_fastp_unpaired_array.sh`
  - `scripts/02_fastp_trim/fastp_unpaired_array.sh`
- Tool: `fastp`
- What happens:
  - Build list of `*_unpaired.fq.gz`
  - Trim each input and produce report files
- Output path pattern:
  - Trimmed FASTQ: `/work/jyanglab/subhash/NEW/1.fastq/trim/<sample>_fastp.fq.gz`
  - Reports: `/work/jyanglab/subhash/NEW/1.fastq/trim/reports/`

### Step 03: Alignment and sorting

- Script: `scripts/03_bwa_mem2_alignment/alignment_unpaired_array.sh`
- Tools: `bwa-mem2`, `samtools`
- What happens:
  - `bwa-mem2 mem` alignment
  - Stream to `samtools view` with `-q 30 -F 4` (keep mapped reads, MAPQ >= 30)
  - Sort and index BAM
- Output path pattern:
  - `/work/jyanglab/subhash/NEW/2.alignment/<sample>/<sample>.srt.bam`
  - `/work/jyanglab/subhash/NEW/2.alignment/<sample>/<sample>.flagstat.txt`

### Step 04: MarkDuplicates (Picard)

- Script: `scripts/04_picard_markduplicates/picard_markduplicates_array.sh`
- Tool: `picard MarkDuplicates`
- Parameters used:
  - `CREATE_INDEX=true`
  - `REMOVE_DUPLICATES=true`
  - `ASSUME_SORTED=true`
- Output path pattern:
  - `/work/jyanglab/subhash/NEW/picard/<sample>/<sample>_picard_dedup.bam`
  - `/work/jyanglab/subhash/NEW/picard/<sample>/<sample>_picard_metrics.txt`

### Step 05: BQSR + HaplotypeCaller

- Script: `scripts/05_bqsr_haplotypecaller/BQSR_array.sh`
- Tools: `gatk4`, `samtools`
- What happens:
  - `BaseRecalibrator`
  - `ApplyBQSR`
  - `HaplotypeCaller -ERC GVCF`
- Inputs:
  - Manifest: `/work/jyanglab/subhash/BQSR/samples.tsv`
  - Reference FASTA + known sites VCF
- Output path pattern:
  - Table: `/work/jyanglab/subhash/BQSR/tables/<sample>.recal_data.table`
  - BAM: `/work/jyanglab/subhash/BQSR/bam/<sample>.BQSR.bam`
  - gVCF: `/work/jyanglab/subhash/BQSR/gvcf/<sample>.g.vcf.gz`

### Step 06: GenomicsDBImport (5 Mb intervals)

- Script: `scripts/06_genomicsdb_import/genomicsdb_import_array_922.sbatch`
- Tool: `gatk GenomicsDBImport`
- Inputs:
  - Sample map: `/work/jyanglab/subhash/6.genomicsdb_5mb/sample_maps/gdb_sample_map_922.tsv`
  - Intervals: `/work/jyanglab/subhash/6.genomicsdb_5mb/intervals/intervals_5mb.list`
- Output path pattern:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/workspaces/<interval_label>/`

### Step 07: GenotypeGVCFs

- Script: `scripts/07_genotype_gvcfs/genotype_from_gdb_array.sbatch`
- Tool: `gatk GenotypeGVCFs`
- Inputs:
  - Manifest: `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/scripts/genotype_5mb_manifest.tsv`
- Output path pattern:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/vcfs/<interval_label>.vcf.gz`

### Step 08: Gather interval VCFs

- Script: `scripts/08_gather_raw_vcf/gather_raw_vcf.sbatch`
- Tool: `gatk GatherVcfs`
- Inputs:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/scripts/vcf_list_manifest_order.txt`
- Output:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/RAW_vcf/RAW_SAP_BQSR.vcf.gz`

### Step 09: Final SNP filtering

- Script: `scripts/09_filter_snps/filter_snps.sbatch`
- Tools: `gatk SelectVariants`, `gatk VariantFiltration`
- SNP hard-filter expression:
  - `MQ < 20.0 || QD < 2.0 || FS > 60.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0 || QUAL < 30.0`
- Genotype filter:
  - `DP < 3` (`--set-filtered-genotype-to-no-call`)
- Keeps only PASS sites.
- Output:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_snps.vcf.gz`

### Step 10: Final indel filtering

- Script: `scripts/10_filter_indels/filter_indels.sbatch`
- Tools: `gatk SelectVariants`, `gatk VariantFiltration`
- Includes `INDEL` and `MIXED` records.
- Indel hard-filter expression:
  - `QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0 || SOR > 10.0 || QUAL < 30.0`
- Genotype filter:
  - `DP < 3` (`--set-filtered-genotype-to-no-call`)
- Keeps only PASS sites.
- Output:
  - `/work/jyanglab/subhash/6.genomicsdb_5mb/genotype_vcfs/final_vcf/results/SAP_BQSR_filtered_indels.vcf.gz`

## Example HCC Execution (Orchestrated)

Use manuscript wrapper scripts:

```bash
cd /home/jyanglab/subhash/sorghum-variant-calling-resource/scripts/manuscript_resource

# one-time directory prep + manifests
bash 01_prepare_hcc_directories.sh
bash 02_build_manifests.sh

# submit steps
bash 03_step01_cram_to_fastq_submit.sh
bash 04_step02_fastp_submit.sh
bash 05_step03_alignment_submit.sh
bash 06_step04_picard_submit.sh
bash 07_step05_bqsr_haplotypecaller_submit.sh
bash 08_step06_genomicsdb_import_submit.sh
bash 09_step07_genotype_gvcfs_submit.sh
bash 10_step08_gather_raw_vcf_submit.sh
bash 11_step09_filter_snps_submit.sh
bash 12_step10_filter_indels_submit.sh
```

## Current Submitted Chain Example (Steps 06-10)

Recorded in:

- `metadata/run_tracking/2026-04-28_slurm_submission_chain_steps06_10.tsv`

Example job chain:

- Step 06: `14996681`
- Step 07: `14996682` (`afterok:14996681`)
- Step 08: `14996683` (`afterok:14996682`)
- Step 09: `14996684` (`afterok:14996683`)
- Step 10: `14996685` (`afterok:14996683`)

## Where Path Details Live

- Expanded per-sample paths (all 922 IDs):
  - `metadata/locations/sample_paths_922_by_step.tsv`
- Step-level output/manifests:
  - `metadata/locations/step_outputs_paths.tsv`
- Runtime manifests and checks:
  - `metadata/locations/hcc_manifest_paths.tsv`
  - `metadata/run_tracking/2026-04-28_hcc_status_snapshot.tsv`

## Repository Layout

- `scripts/` core step scripts
- `scripts/manuscript_resource/` orchestrated wrappers
- `workflows/` R Markdown methods/runbook
- `metadata/` sample lists, manifests, run tracking
- `profiling/` code/manifest inventories
- `docs/` project guideline + collaboration conventions
- `data/` supplementary/data index scaffold

## Large Data Policy

Do not commit CRAM/FASTQ/BAM/gVCF/VCF/GenomicsDB files.
Commit only scripts, metadata tables, manifests, and documentation.
