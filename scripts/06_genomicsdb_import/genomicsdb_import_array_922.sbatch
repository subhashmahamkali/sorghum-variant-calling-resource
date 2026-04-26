#!/bin/bash
#SBATCH --job-name=gdb_import_5mb_922
#SBATCH --partition=jclarke,batch,guest
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=80G
#SBATCH --time=72:00:00
#SBATCH --array=1-149
#SBATCH --output=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/genomicsdb_import_922_%A_%a.out
#SBATCH --error=/work/jyanglab/subhash/6.genomicsdb_5mb/logs/genomicsdb_import_922_%A_%a.err

set -euo pipefail

module purge
module load gatk4/4.4

export TILEDB_DISABLE_FILE_LOCKING=1

WORKDIR=/work/jyanglab/subhash/6.genomicsdb_5mb
SAMPLE_MAP=${SAMPLE_MAP:-${WORKDIR}/sample_maps/gdb_sample_map_922.tsv}
INTERVAL_LIST=${INTERVAL_LIST:-${WORKDIR}/intervals/intervals_5mb.list}
WORKSPACE_ROOT=${WORKDIR}/workspaces
SCRATCH_BASE=/scratch/${SLURM_JOB_ID}/genomicsdb

mkdir -p "${WORKSPACE_ROOT}"
mkdir -p "${SCRATCH_BASE}/tmp" "${SCRATCH_BASE}/workspace"
trap 'rm -rf "${SCRATCH_BASE}"' EXIT

TASK_ID=${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID not set}
INTERVAL=$(sed -n "${TASK_ID}p" "${INTERVAL_LIST}" )
if [[ -z "${INTERVAL}" ]]; then
    echo "Failed to fetch interval for task ${TASK_ID}" >&2
    exit 1
fi

INTERVAL_LABEL=$(echo "${INTERVAL}" | tr ':-' '__')
LOCAL_WORKSPACE=${SCRATCH_BASE}/workspace/${INTERVAL_LABEL}
FINAL_WORKSPACE=${WORKSPACE_ROOT}/${INTERVAL_LABEL}

mkdir -p "$(dirname "${LOCAL_WORKSPACE}")"
rm -rf "${LOCAL_WORKSPACE}"

TMPDIR=${SCRATCH_BASE}/tmp
export TMPDIR

gatk --java-options "-Djava.io.tmpdir=${TMPDIR} -Xms8g -Xmx70g -XX:ParallelGCThreads=2" GenomicsDBImport \
    --sample-name-map "${SAMPLE_MAP}" \
    --genomicsdb-workspace-path "${LOCAL_WORKSPACE}" \
    --intervals "${INTERVAL}" \
    --batch-size 50 \
    --reader-threads ${SLURM_CPUS_PER_TASK:-2} \
    --tmp-dir "${TMPDIR}" \
    --genomicsdb-shared-posixfs-optimizations true

mkdir -p "${FINAL_WORKSPACE}"
rsync -a --delete "${LOCAL_WORKSPACE}/" "${FINAL_WORKSPACE}/"

echo "Completed GenomicsDBImport for ${INTERVAL}"
