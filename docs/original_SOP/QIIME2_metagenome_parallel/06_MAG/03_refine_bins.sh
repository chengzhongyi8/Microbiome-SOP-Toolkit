#!/usr/bin/env bash
# Purpose: refine two or three independent binner outputs without hiding their original bins.
# Input: populated binning/metabat2, maxbin2, concoct directories.
# Output: results/06_MAG/refinement.
# Software: metaWRAP bin_refinement (legacy-compatible) or replace with DAS Tool after review.
# Resources: THREADS_PER_JOB CPUs, MEMORY_GB.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_BINNING}" metawrap
BIN="${PROJECT_DIR}/results/06_MAG/binning"; OUT="${PROJECT_DIR}/results/06_MAG/refinement"; mkdir -p "${OUT}"
args=()
[[ -d "${BIN}/metabat2" ]] && args+=(-A "${BIN}/metabat2")
[[ -d "${BIN}/maxbin2" ]] && args+=(-B "${BIN}/maxbin2")
[[ -d "${BIN}/concoct" ]] && args+=(-C "${BIN}/concoct")
[[ "${#args[@]}" -ge 4 ]] || { echo "ERROR: at least two populated binner directories are required" >&2; exit 1; }
metawrap bin_refinement -o "${OUT}" -t "${THREADS_PER_JOB}" -m "${MEMORY_GB}" \
  "${args[@]}" -c "${MAG_MIN_COMPLETENESS}" -x "${MAG_MAX_CONTAMINATION}"
