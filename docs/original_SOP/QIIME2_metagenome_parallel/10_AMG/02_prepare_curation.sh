#!/usr/bin/env bash
# Purpose: initialize the mandatory AMG manual-curation ledger.
# Input: DRAM-v/VIBRANT candidate tables plus CheckV and gene-context outputs, reviewed manually.
# Output: results/10_AMG/curation/amg_curation.tsv.
# Software: cp only; this step deliberately does not auto-accept candidates.
# Resources: negligible.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
for required_cmd in mkdir cp; do
  command -v "${required_cmd}" >/dev/null 2>&1 || { echo "ERROR: required command not found: ${required_cmd}" >&2; exit 1; }
done
OUT="${PROJECT_DIR}/results/10_AMG/curation"; mkdir -p "${OUT}"
cp "${SCRIPT_DIR}/amg_curation_template.tsv" "${OUT}/amg_curation.tsv"
cat <<'MSG'
Populate one row per candidate. Accept only after checking gene coordinates/contig ends,
CheckV quality and host contamination, neighboring viral hallmark genes, metabolic identity,
and host-like contamination. Keep rejected and uncertain rows for provenance.
MSG
