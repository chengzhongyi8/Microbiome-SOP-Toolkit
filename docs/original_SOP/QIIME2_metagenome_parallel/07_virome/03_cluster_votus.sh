#!/usr/bin/env bash
# Purpose: cluster reviewed viral sequences into species-rank operational units while retaining cluster membership.
# Input: VIRUS_FASTA after quality/evidence review.
# Output: representative vOTUs and cluster file.
# Software: CD-HIT-EST.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_CLUSTER_CDHIT}" "${CD_HIT_EST}"
: "${VIRUS_FASTA:?Set VIRUS_FASTA}"
OUT="${PROJECT_DIR}/results/07_virome/votu"; mkdir -p "${OUT}"
"${CD_HIT_EST}" -i "${VIRUS_FASTA}" -o "${OUT}/vOTU.fna" -c "${VOTU_IDENTITY}" \
  -aS "${VOTU_COVERAGE}" -G 1 -g 1 -T "${THREADS_PER_JOB}" -M 0
