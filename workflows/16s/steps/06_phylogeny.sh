#!/usr/bin/env bash
# Purpose: build alignment, masked alignment, unrooted and midpoint-rooted trees from final ASVs.
# Input: results/final/rep-seqs.qza.
# Output: four phylogeny artifacts including rooted-tree.qza.
# Software: QIIME2 q2-phylogeny (MAFFT and FastTree).
# Resources: PHYLOGENY_THREADS CPUs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${WORKFLOW_DIR}/config.sh"
[[ -f "${WORKFLOW_DIR}/config.local.sh" ]] && source "${WORKFLOW_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR:-}/work/config.local.sh" ]] && source "${PROJECT_DIR}/work/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${WORKFLOW_DIR}/activate_qiime2.sh"
FINAL_DIR="${PROJECT_DIR}/results/final"

qiime phylogeny align-to-tree-mafft-fasttree --i-sequences "${FINAL_DIR}/rep-seqs.qza" \
  --p-n-threads "${PHYLOGENY_THREADS}" --o-alignment "${FINAL_DIR}/aligned-rep-seqs.qza" \
  --o-masked-alignment "${FINAL_DIR}/masked-aligned-rep-seqs.qza" \
  --o-tree "${FINAL_DIR}/unrooted-tree.qza" --o-rooted-tree "${FINAL_DIR}/rooted-tree.qza"
