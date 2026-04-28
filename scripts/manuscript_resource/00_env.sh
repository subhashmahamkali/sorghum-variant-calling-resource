#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PIPELINE_SCRIPTS_ROOT="${REPO_ROOT}/scripts"

SAMPLE_LIST_922="${SAMPLE_LIST_922:-${REPO_ROOT}/metadata/curated/final_922_samples.txt}"
SAMPLE_LIST_876="${SAMPLE_LIST_876:-${REPO_ROOT}/metadata/curated/bqsr_876_samples.txt}"
SAMPLE_LIST_EXPVP_46="${SAMPLE_LIST_EXPVP_46:-${REPO_ROOT}/metadata/curated/expvp_46_samples.txt}"

RAW_CRAM_ROOT="${RAW_CRAM_ROOT:-/mnt/nrdstor/jyanglab/subhash/sorghum_WGS_JS}"
NEW_ROOT="${NEW_ROOT:-/work/jyanglab/subhash/NEW}"
BQSR_ROOT="${BQSR_ROOT:-/work/jyanglab/subhash/BQSR}"
GDB_ROOT="${GDB_ROOT:-/work/jyanglab/subhash/6.genomicsdb_5mb}"

REF_FASTA="${REF_FASTA:-/work/jyanglab/subhash/variant_calling/2.refrence/Phytozome/PhytozomeV13/Sbicolor/v5.1/assembly/sorghum_v5.1.fa}"
KNOWN_SITES_VCF="${KNOWN_SITES_VCF:-/work/jyanglab/subhash/known_sites/known_sites_merged.num.renamed.vcf.gz}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_file() {
  local p="$1"
  [[ -s "$p" ]] || {
    echo "Required file not found or empty: $p" >&2
    exit 1
  }
}

line_count() {
  local p="$1"
  wc -l < "$p" | tr -d ' '
}
