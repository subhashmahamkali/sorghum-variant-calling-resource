# Known Gaps and Data Status

This file records known gaps from the read-only audit.

## Missing or Moved Intermediates

- `/work/jyanglab/subhash/NEW/2.alignment` currently contains the alignment
  sample list but no visible `.srt.bam` files from the read-only audit.
- `/work/jyanglab/subhash/NEW/2.alignment/logs` had no visible log files at
  audit time.
- The HaplotypeCaller manifest contains 971 BAM paths, but only 603 currently
  exist at those paths. The remaining 368 appear missing or moved.
- `/work/jyanglab/subhash/5.gvcf` did not contain the expected `.g.vcf` files
  at audit time. The main gVCF collection is under
  `/work/jyanglab/subhash/BQSR/gvcf`.

## gVCF Integrity

The GenomicsDB integrity report records:

- 713 OK gVCFs
- 157 failed gVCFs

Failure reasons include missing or empty indexes, position-order issues, and
malformed records with too few columns.

## Large Data Policy

Large data files are not committed to this repository. They are represented by
inventory files and absolute paths.
