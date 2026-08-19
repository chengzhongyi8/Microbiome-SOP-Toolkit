#!/usr/bin/env bash
# Purpose: predict vOTU hosts with iPHoP and keep native confidence/evidence columns.
# Input: vOTU.fna and configured iPHoP database (optionally extended with reviewed MAGs beforehand).
# Output: native iPHoP output directory.
# Software/database: iPHoP.
# Resources: THREADS_PER_JOB CPUs; database-dependent memory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_IPHOP}" "${IPHOP}"
[[ -d "${IPHOP_DB}" ]] || { echo "ERROR: configure IPHOP_DB" >&2; exit 1; }
VOTU="${PROJECT_DIR}/results/07_virome/votu/vOTU.fna"; OUT="${PROJECT_DIR}/results/08_virus_host/iphop"
mkdir -p "${OUT}"
"${IPHOP}" predict --fa_file "${VOTU}" --db_dir "${IPHOP_DB}" --out_dir "${OUT}" -t "${THREADS_PER_JOB}"
