#!/bin/bash
#SBATCH --job-name=SRR34291455
#SBATCH --partition=jclarke,batch,guest
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=slurm_logs/SRR34291455.out
#SBATCH --error=slurm_logs/SRR34291455.err

set -euo pipefail
if [ -f /etc/profile.d/modules.sh ]; then
    source /etc/profile.d/modules.sh
elif [ -f /usr/share/Modules/init/bash ]; then
    source /usr/share/Modules/init/bash
elif [ -n "${MODULESHOME:-}" ] && [ -f "${MODULESHOME}/init/profile" ]; then
    source "${MODULESHOME}/init/profile"
fi
module load SRAtoolkit/2.11

RUN=SRR34291455
SAMPLE=ExPVP_PI601554
OUTDIR=fastq
TMPDIR=sra_tmp
MAXSIZE=200G
THREADS=$SLURM_CPUS_PER_TASK
FORCE=0
KEEP_SRA=0
KEEP_TEMP=0
NO_GZIP=0
SCRATCH="$TMPDIR/${RUN}_tmp"
SRA_FILE="$TMPDIR/${RUN}.sra"
R1_BASE="$OUTDIR/${RUN}_1.fastq"
R2_BASE="$OUTDIR/${RUN}_2.fastq"
TARGET_R1="$OUTDIR/${SAMPLE}_R1.fastq"
TARGET_R2="$OUTDIR/${SAMPLE}_R2.fastq"
FINAL_R1="$OUTDIR/${SAMPLE}_R1.fastq.gz"
FINAL_R2="$OUTDIR/${SAMPLE}_R2.fastq.gz"

mkdir -p "$OUTDIR" "$TMPDIR" "$SCRATCH"

COMPRESSOR="$(command -v pigz || command -v gzip || true)"
if [ "$NO_GZIP" -eq 0 ] && [ -z "$COMPRESSOR" ]; then
    echo "No pigz/gzip compressor found in PATH" >&2
    exit 1
fi

if [ "$FORCE" -eq 0 ] && [ -s "$FINAL_R1" ] && [ -s "$FINAL_R2" ]; then
    echo "[skip] $RUN -> $SAMPLE (existing FASTQs)"
    exit 0
fi

rm -f "$FINAL_R1" "$FINAL_R2" "$TARGET_R1" "$TARGET_R2" "$R1_BASE" "$R2_BASE"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

cleanup() {
    if [ "$KEEP_TEMP" -eq 0 ]; then
        rm -rf "$SCRATCH"
    fi
}
trap cleanup EXIT

if [ "$FORCE" -eq 0 ] && [ -s "$SRA_FILE" ]; then
    echo "[reuse] $RUN cache $SRA_FILE"
else
    rm -f "$SRA_FILE"
    prefetch --max-size "$MAXSIZE" --output-file "$SRA_FILE" "$RUN"
fi

fasterq-dump --split-files --threads "$THREADS" --temp "$SCRATCH" --outdir "$OUTDIR" "$SRA_FILE"

if [ ! -f "$R1_BASE" ] || [ ! -f "$R2_BASE" ]; then
    echo "Missing FASTQ output from fasterq-dump" >&2
    exit 1
fi

mv "$R1_BASE" "$TARGET_R1"
mv "$R2_BASE" "$TARGET_R2"

if [ "$NO_GZIP" -eq 0 ]; then
    "$COMPRESSOR" -f "$TARGET_R1"
    "$COMPRESSOR" -f "$TARGET_R2"
fi

if [ "$KEEP_TEMP" -eq 0 ]; then
    rm -rf "$SCRATCH"
fi
if [ "$KEEP_SRA" -eq 0 ]; then
    rm -f "$SRA_FILE"
fi

echo "[done] $RUN -> $SAMPLE"
