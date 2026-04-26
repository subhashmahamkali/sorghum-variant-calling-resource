#!/usr/bin/env python3
import argparse
import concurrent.futures
import shlex
import shutil
import subprocess
from pathlib import Path

def parse_args():
    parser = argparse.ArgumentParser(description="Download paired-end FASTQ files for a list of SRA runs.")
    parser.add_argument("--list", default="sra_samples.tsv", help="TSV file with two columns: SRR accession and sample name (default: sra_samples.tsv)")
    parser.add_argument("--output", default="fastq", help="Directory to write FASTQ files (default: fastq)")
    parser.add_argument("--tmp", default="sra_tmp", help="Directory for temporary SRA files and fasterq-dump scratch space (default: sra_tmp)")
    parser.add_argument("--jobs", type=int, default=4, help="Number of parallel downloads to run (default: 4)")
    parser.add_argument("--threads", type=int, default=8, help="Threads passed to fasterq-dump for each job (default: 8)")
    parser.add_argument("--max-size", default="200G", help="Maximum allowed download size per run passed to prefetch (default: 200G)")
    parser.add_argument("--no-gzip", action="store_true", help="Skip gzip compression of FASTQ outputs")
    parser.add_argument("--force", action="store_true", help="Re-download runs even if outputs already exist")
    parser.add_argument("--keep-sra", action="store_true", help="Keep downloaded .sra files instead of deleting them after conversion")
    parser.add_argument("--keep-temp", action="store_true", help="Keep fasterq-dump temporary directories for debugging")
    parser.add_argument("--dry-run", action="store_true", help="Print planned work without executing commands")
    return parser.parse_args()

def read_pairs(list_path):
    pairs = []
    with open(list_path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                raise ValueError(f"Expected two columns (SRR and sample name) in line: {line}")
            run, sample = parts[0], parts[1]
            pairs.append((run, sample))
    return pairs

def run_command(cmd):
    subprocess.run(cmd, check=True)

def download_one(run, sample, args, compressor):
    out_dir = Path(args.output)
    tmp_dir = Path(args.tmp)
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir.mkdir(parents=True, exist_ok=True)

    temp_work = tmp_dir / f"{run}_tmp"
    if args.force and temp_work.exists():
        shutil.rmtree(temp_work)
    temp_work.mkdir(parents=True, exist_ok=True)

    sra_path = tmp_dir / f"{run}.sra"
    if args.force and sra_path.exists():
        sra_path.unlink()

    fastq_r1 = out_dir / f"{run}_1.fastq"
    fastq_r2 = out_dir / f"{run}_2.fastq"

    target_r1 = out_dir / f"{sample}_R1.fastq"
    target_r2 = out_dir / f"{sample}_R2.fastq"
    final_r1 = target_r1 if args.no_gzip else target_r1.with_suffix(target_r1.suffix + ".gz")
    final_r2 = target_r2 if args.no_gzip else target_r2.with_suffix(target_r2.suffix + ".gz")

    if not args.force and final_r1.exists() and final_r2.exists():
        print(f"[skip] {run} -> {sample} (outputs present)")
        return

    if args.force:
        for path in (final_r1, final_r2, target_r1, target_r2, fastq_r1, fastq_r2):
            if path.exists():
                if path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink()

    if not args.force and sra_path.exists():
        print(f"[reuse] {run}: using cached {sra_path}")
    else:
        if args.dry_run:
            print(f"prefetch --max-size {args.max_size} --output-file {sra_path} {run}")
        else:
            run_command([
                "prefetch",
                "--max-size", args.max_size,
                "--output-file", str(sra_path),
                run,
            ])

    fasterq_cmd = [
        "fasterq-dump",
        "--split-files",
        "--threads", str(args.threads),
        "--temp", str(temp_work),
        "--outdir", str(out_dir),
        str(sra_path),
    ]

    if args.dry_run:
        print(" ".join(shlex.quote(tok) for tok in fasterq_cmd))
    else:
        run_command(fasterq_cmd)

    if args.dry_run:
        return

    if fastq_r1.exists():
        fastq_r1.rename(target_r1)
    else:
        raise FileNotFoundError(f"Expected {fastq_r1} after fasterq-dump")

    if fastq_r2.exists():
        fastq_r2.rename(target_r2)
    else:
        raise FileNotFoundError(f"Expected {fastq_r2} after fasterq-dump")

    if not args.no_gzip:
        cmd = [compressor, "-f", str(target_r1)]
        run_command(cmd)
        cmd = [compressor, "-f", str(target_r2)]
        run_command(cmd)

    if not args.keep_sra and sra_path.exists():
        sra_path.unlink()
    if not args.keep_temp and temp_work.exists():
        shutil.rmtree(temp_work)

    print(f"[done] {run} -> {sample}")

def main():
    args = parse_args()
    pairs = read_pairs(args.list)

    if not pairs:
        print(f"No runs found in {args.list}")
        return

    compressor = "cat" if args.no_gzip else shutil.which("pigz") or shutil.which("gzip")
    if not args.no_gzip and compressor in (None, "cat"):
        raise RuntimeError("gzip or pigz not found in PATH; re-run with --no-gzip or install a compressor")

    if args.dry_run:
        print(f"Planning downloads for {len(pairs)} runs...")

    if args.dry_run:
        for run, sample in pairs:
            download_one(run, sample, args, compressor)
        return

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        future_to_run = {
            executor.submit(download_one, run, sample, args, compressor): (run, sample)
            for run, sample in pairs
        }
        first_error = None
        for future in concurrent.futures.as_completed(future_to_run):
            run, sample = future_to_run[future]
            try:
                future.result()
            except Exception as exc:  # pylint: disable=broad-except
                print(f"[error] {run} -> {sample}: {exc}")
                if first_error is None:
                    first_error = exc
        if first_error:
            raise SystemExit(1)

if __name__ == "__main__":
    main()
