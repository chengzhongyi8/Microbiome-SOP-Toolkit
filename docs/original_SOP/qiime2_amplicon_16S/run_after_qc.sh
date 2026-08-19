#!/usr/bin/env bash
# Purpose: stage 2 runner from optional cutadapt through file2meco export and summary.
# Input: stage 1 output and DADA2 parameters (manual or auto-estimated).
# Output: final ASV/microeco files plus results/summary.
# Software: QIIME2, BIOM, optional R. Resources: defined by component scripts.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/03_cutadapt_optional.sh"
bash "${SCRIPT_DIR}/08_auto_dada2_params.sh"
bash "${SCRIPT_DIR}/04_dada2.sh"
bash "${SCRIPT_DIR}/05_taxonomy_filter.sh"
bash "${SCRIPT_DIR}/06_phylogeny.sh"
bash "${SCRIPT_DIR}/07_export_microeco.sh"
bash "${SCRIPT_DIR}/09_summary.sh"
