#!/usr/bin/env bash
# Purpose: assess viral contig completeness, terminal repeats, provirus boundaries, and host contamination.
# Input: VIRUS_FASTA environment variable (reviewed candidates).
# Output: complete CheckV end_to_end output; no quality tier is automatically deleted.
# Software/database: CheckV.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_CHECKV}" "${CHECKV}"
: "${VIRUS_FASTA:?Set VIRUS_FASTA to reviewed candidate viral contigs}"
[[ -d "${CHECKV_DB}" ]] || { echo "ERROR: configure CHECKV_DB" >&2; exit 1; }
OUT="${PROJECT_DIR}/results/07_virome/checkv"; mkdir -p "${OUT}"
"${CHECKV}" end_to_end "${VIRUS_FASTA}" "${OUT}" -d "${CHECKV_DB}" -t "${THREADS_PER_JOB}"
cp "${OUT}/quality_summary.tsv" "${OUT}/quality_summary.keep_all_tiers.tsv"
echo "Not-determined entries are retained. Filter only with documented length, viral evidence, and study-specific rules."
