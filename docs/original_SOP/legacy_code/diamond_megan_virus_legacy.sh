#!/usr/bin/env bash
# HISTORICAL ONLY: old DIAMOND + MEGAN virus annotation was reported as unsatisfactory.
set -euo pipefail
echo "DISABLED: historical DIAMOND + MEGAN virus annotation; use geNomad/ICTV-aware outputs as the current default." >&2
exit 1

# Original outline retained in the Notion markdown copy:
# diamond blastp ... --max-target-seqs 5 --evalue 0.0001 --outfmt 6 ...
# blast2lca ... -f BlastTab -ms 50 -me 0.00001 ...

