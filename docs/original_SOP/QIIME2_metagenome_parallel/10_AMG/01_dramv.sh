#!/usr/bin/env bash
# Purpose: annotate candidate viral genes with DRAM-v using VirSorter2 context files.
# Input: VIRAL_FASTA and AFFI_CONTIGS environment variables from --prep-for-dramv.
# Output: DRAM-v annotation and distillate candidates; not accepted final AMGs.
# Software/database: DRAM-v and configured DRAM database.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_DRAMV}" "${DRAMV}"
: "${VIRAL_FASTA:?Set VIRAL_FASTA from VirSorter2 for-dramv}"; : "${AFFI_CONTIGS:?Set AFFI_CONTIGS from VirSorter2 for-dramv}"
OUT="${PROJECT_DIR}/results/10_AMG/dramv"; mkdir -p "${OUT}/annotation" "${OUT}/distill"
"${DRAMV}" annotate -i "${VIRAL_FASTA}" -v "${AFFI_CONTIGS}" -o "${OUT}/annotation" --threads "${THREADS_PER_JOB}"
"${DRAMV}" distill -i "${OUT}/annotation/annotations.tsv" -o "${OUT}/distill"
