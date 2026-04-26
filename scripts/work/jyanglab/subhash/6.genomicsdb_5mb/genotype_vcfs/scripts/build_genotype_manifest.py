#!/usr/bin/env python3
"""Create GenotypeGVCFs manifest for the 5 Mb GenomicsDB workspaces."""
from __future__ import annotations
from pathlib import Path

BASE = Path('/work/jyanglab/subhash/6.genomicsdb_5mb')
WORKSPACE_ROOT = BASE / 'workspaces'
GENO_ROOT = BASE / 'genotype_vcfs'
SCRIPTS_DIR = GENO_ROOT / 'scripts'
VCF_DIR = GENO_ROOT / 'vcfs'
MANIFEST = SCRIPTS_DIR / 'genotype_5mb_manifest.tsv'

chrom_label = {str(i): f'Chr{i:02d}' for i in range(1, 11)}

def parse_workspace(path: Path):
    parts = path.name.split('_')
    if len(parts) != 3:
        return None
    chrom_raw, start_str, end_str = parts
    if chrom_raw not in chrom_label:
        return None
    try:
        start = int(start_str)
        end = int(end_str)
    except ValueError:
        return None
    interval = f"{chrom_label[chrom_raw]}:{start}-{end}"
    output_name = f"{chrom_label[chrom_raw]}_{start}_{end}.vcf.gz"
    return (int(chrom_raw), start, interval, str(path), str(VCF_DIR / output_name))

def main():
    entries = []
    for workspace in WORKSPACE_ROOT.glob('*_*_*'):
        if not workspace.is_dir():
            continue
        parsed = parse_workspace(workspace)
        if parsed:
            entries.append(parsed)
    if not entries:
        raise SystemExit('No GenomicsDB workspaces found.')
    entries.sort(key=lambda item: (item[0], item[1]))
    SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    VCF_DIR.mkdir(parents=True, exist_ok=True)
    with MANIFEST.open('w', encoding='ascii') as handle:
        for _, __, interval, workspace_path, output_path in entries:
            handle.write(f"{interval}\t{workspace_path}\t{output_path}\n")
    print(f"Wrote {len(entries)} intervals to {MANIFEST}")

if __name__ == '__main__':
    main()
