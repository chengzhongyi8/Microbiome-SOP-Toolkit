#!/usr/bin/env bash
# Purpose: extract only manually accepted AMG nucleotide sequences for abundance/activity analysis.
# Input: curated ledger and ALL_VIRAL_GENES_FASTA environment variable.
# Output: accepted_AMG.fna and accepted_AMG.metadata.tsv.
# Software: seqkit.
# Resources: 1 CPU.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_SEQKIT}" "${SEQKIT}"
: "${ALL_VIRAL_GENES_FASTA:?Set ALL_VIRAL_GENES_FASTA}"
LEDGER="${PROJECT_DIR}/results/10_AMG/curation/amg_curation.tsv"; OUT="${PROJECT_DIR}/results/10_AMG/final"; mkdir -p "${OUT}"
awk -F '\t' 'NR>1 && tolower($16)=="accept" {print $1}' "${LEDGER}" > "${OUT}/accepted.ids"
[[ -s "${OUT}/accepted.ids" ]] || { echo "ERROR: no manually accepted AMG rows" >&2; exit 1; }
"${SEQKIT}" grep -f "${OUT}/accepted.ids" "${ALL_VIRAL_GENES_FASTA}" -o "${OUT}/accepted_AMG.fna"
awk -F '\t' 'NR==1 || tolower($16)=="accept"' "${LEDGER}" > "${OUT}/accepted_AMG.metadata.tsv"
