#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path

SCRIPT_TEMPLATE = """#!/bin/bash
#SBATCH --job-name={run}
#SBATCH --partition={partition}
#SBATCH --cpus-per-task={cpus}
#SBATCH --mem={mem}
#SBATCH --time={time}
#SBATCH --output={log_dir}/{run}.out
#SBATCH --error={log_dir}/{run}.err

set -euo pipefail
if [ -f /etc/profile.d/modules.sh ]; then
    source /etc/profile.d/modules.sh
elif [ -f /usr/share/Modules/init/bash ]; then
    source /usr/share/Modules/init/bash
elif [ -n "${{MODULESHOME:-}}" ] && [ -f "${{MODULESHOME}}/init/profile" ]; then
    source "${{MODULESHOME}}/init/profile"
fi
module load SRAtoolkit/2.11

RUN={run}
SAMPLE={sample}
OUTDIR={out_dir}
TMPDIR={tmp_dir}
MAXSIZE={max_size}
THREADS=$SLURM_CPUS_PER_TASK
FORCE={force}
KEEP_SRA={keep_sra}
KEEP_TEMP={keep_temp}
NO_GZIP={no_gzip}
SCRATCH="$TMPDIR/${{RUN}}_tmp"
SRA_FILE="$TMPDIR/${{RUN}}.sra"
R1_BASE="$OUTDIR/${{RUN}}_1.fastq"
R2_BASE="$OUTDIR/${{RUN}}_2.fastq"
TARGET_R1="$OUTDIR/${{SAMPLE}}_R1.fastq"
TARGET_R2="$OUTDIR/${{SAMPLE}}_R2.fastq"
FINAL_R1="$OUTDIR/${{SAMPLE}}_R1.fastq{gz_suffix}"
FINAL_R2="$OUTDIR/${{SAMPLE}}_R2.fastq{gz_suffix}"

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

cleanup() {{
    if [ "$KEEP_TEMP" -eq 0 ]; then
        rm -rf "$SCRATCH"
    fi
}}
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
"""

def parse_args():
    parser = argparse.ArgumentParser(description="Submit one Slurm job per SRA run to download paired FASTQs.")
    parser.add_argument("--list", default="sra_samples.tsv", help="Path to TSV with SRR accession and sample name")
    parser.add_argument("--jobs-dir", default="slurm_jobs", help="Directory where sbatch scripts will be written")
    parser.add_argument("--log-dir", default="slurm_logs", help="Directory for Slurm stdout/stderr files")
    parser.add_argument("--partition", default="batch", help="Slurm partition to use (e.g. batch, jclarke, guest)")
    parser.add_argument("--cpus", type=int, default=8, help="CPUs per task passed to Slurm and fasterq-dump")
    parser.add_argument("--mem", default="32G", help="Memory per job (Slurm format, e.g. 32G)")
    parser.add_argument("--time", default="24:00:00", help="Walltime per job (HH:MM:SS)")
    parser.add_argument("--out-dir", default="fastq", help="Output directory for FASTQ files")
    parser.add_argument("--tmp-dir", default="sra_tmp", help="Temporary directory shared across jobs")
    parser.add_argument("--max-size", default="200G", help="Maximum download size passed to prefetch")
    parser.add_argument("--no-gzip", action="store_true", help="Disable gzip compression of FASTQs")
    parser.add_argument("--keep-sra", action="store_true", help="Keep .sra cache files after conversion")
    parser.add_argument("--keep-temp", action="store_true", help="Keep fasterq-dump temporary directories")
    parser.add_argument("--force", action="store_true", help="Force re-download even if outputs exist")
    parser.add_argument("--no-submit", action="store_true", help="Write sbatch scripts without submitting them")
    return parser.parse_args()


def read_pairs(list_path: Path):
    pairs = []
    with list_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                raise ValueError(f"Expected two columns in line: {line}")
            pairs.append((parts[0], parts[1]))
    return pairs


def write_job(run: str, sample: str, args, jobs_dir: Path, log_dir: Path):
    script_path = jobs_dir / f"{run}.sbatch"
    content = SCRIPT_TEMPLATE.format(
        run=run,
        sample=sample,
        partition=args.partition,
        cpus=args.cpus,
        mem=args.mem,
        time=args.time,
        log_dir=log_dir,
        out_dir=Path(args.out_dir),
        tmp_dir=Path(args.tmp_dir),
        max_size=args.max_size,
        gz_suffix="" if args.no_gzip else ".gz",
        force=1 if args.force else 0,
        keep_sra=1 if args.keep_sra else 0,
        keep_temp=1 if args.keep_temp else 0,
        no_gzip=1 if args.no_gzip else 0,
    )
    script_path.write_text(content, encoding="utf-8")
    return script_path


def submit_job(script_path: Path):
    subprocess.run(["sbatch", str(script_path)], check=True)


def main():
    args = parse_args()
    list_path = Path(args.list)
    jobs_dir = Path(args.jobs_dir)
    log_dir = Path(args.log_dir)

    jobs_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    Path(args.out_dir).mkdir(parents=True, exist_ok=True)
    Path(args.tmp_dir).mkdir(parents=True, exist_ok=True)

    pairs = read_pairs(list_path)
    if not pairs:
        print(f"No runs found in {list_path}")
        return

    for run, sample in pairs:
        script_path = write_job(run, sample, args, jobs_dir, log_dir)
        if args.no_submit:
            print(f"[write] {script_path}")
            continue
        submit_job(script_path)
        print(f"[submit] {script_path}")


if __name__ == "__main__":
    main()
