#!/bin/bash
#SBATCH --job-name=gdb_import_small
#SBATCH --account=jyanglab
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=3G
#SBATCH --time=02:00:00
#SBATCH --array=1-3%3
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/genomicsdb_import_small_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/genomicsdb_import_small_%A_%a.err

set -euo pipefail

#module purge
module load gatk4/4.4
export TILEDB_DISABLE_FILE_LOCKING=1

WORKDIR=/work/jyanglab/subhash/6.genomicsdb_5mb
mkdir -p "${WORKDIR}/logs"

SAMPLE_MAP=${SAMPLE_MAP:-${WORKDIR}/sample_maps/test_sample_map_10.tsv}
INTERVAL_LIST=${INTERVAL_LIST:-${WORKDIR}/intervals/test_interval_1kb.list}
WORKSPACE_ROOT=${WORKDIR}/workspaces_small_test
SCRATCH_BASE=/scratch/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}/genomicsdb

# quick input sanity
[[ -s "${SAMPLE_MAP}" ]] || { echo "Missing SAMPLE_MAP: ${SAMPLE_MAP}" >&2; exit 1; }
[[ -s "${INTERVAL_LIST}" ]] || { echo "Missing INTERVAL_LIST: ${INTERVAL_LIST}" >&2; exit 1; }

# prep dirs
mkdir -p "${WORKSPACE_ROOT}" "${SCRATCH_BASE}/tmp" "${SCRATCH_BASE}/workspace"
trap 'rm -rf "${SCRATCH_BASE}"' EXIT

# helpful for file-heavy tools
ulimit -n 4096 || true

TASK_ID=${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID not set}
INTERVAL=$(sed -n "${TASK_ID}p" "${INTERVAL_LIST}" || true)
if [[ -z "${INTERVAL}" ]]; then
  echo "Failed to fetch interval for task ${TASK_ID}" >&2
  exit 1
fi

INTERVAL_LABEL=$(echo "${INTERVAL}" | tr ':-' '__')
LOCAL_WORKSPACE=${SCRATCH_BASE}/workspace/${INTERVAL_LABEL}
FINAL_WORKSPACE=${WORKSPACE_ROOT}/${INTERVAL_LABEL}

# log what we're doing (useful for HCC review)
echo "TASK_ID=${TASK_ID}"
echo "INTERVAL=${INTERVAL}"
echo "LOCAL_WORKSPACE=${LOCAL_WORKSPACE}"
echo "FINAL_WORKSPACE=${FINAL_WORKSPACE}"
echo "TMPDIR=${SCRATCH_BASE}/tmp"

mkdir -p "$(dirname "${LOCAL_WORKSPACE}")"
rm -rf "${LOCAL_WORKSPACE}"

TMPDIR=${SCRATCH_BASE}/tmp
export TMPDIR

gatk --java-options "-Djava.io.tmpdir=${TMPDIR} -Xms256m -Xmx2G -XX:ParallelGCThreads=1" GenomicsDBImport \
  --sample-name-map "${SAMPLE_MAP}" \
  --genomicsdb-workspace-path "${LOCAL_WORKSPACE}" \
  --intervals "${INTERVAL}" \
  --batch-size 20 \
  --reader-threads ${SLURM_CPUS_PER_TASK:-1} \
  --tmp-dir "${TMPDIR}" \
  --genomicsdb-shared-posixfs-optimizations true

mkdir -p "${FINAL_WORKSPACE}"
rsync -a --delete "${LOCAL_WORKSPACE}/" "${FINAL_WORKSPACE}/"

echo "Completed small GenomicsDBImport for ${INTERVAL}"
 
