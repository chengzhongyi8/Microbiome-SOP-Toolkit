#!/usr/bin/env bash
# Purpose: assess refined MAGs, dereplicate passing bins, and assign GTDB taxonomy.
# Input: MAG_INPUT_DIR environment variable.
# Output: CheckM2, dRep dereplicated genomes, GTDB-Tk classification.
# Software/databases: CheckM2, dRep, GTDB-Tk.
# Resources: THREADS_PER_JOB CPUs; GTDB-Tk can require high memory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
: "${MAG_INPUT_DIR:?Set MAG_INPUT_DIR to the reviewed refined-bin directory}"
OUT="${PROJECT_DIR}/results/06_MAG/postprocess"; mkdir -p "${OUT}"
[[ -d "${CHECKM2_DB}" ]] || { echo "ERROR: configure CHECKM2_DB" >&2; exit 1; }
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_MAG_QC}" "${CHECKM2}"
CHECKM2DB="${CHECKM2_DB}" "${CHECKM2}" predict --threads "${THREADS_PER_JOB}" --input "${MAG_INPUT_DIR}" --output-directory "${OUT}/checkm2"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_MAG_DEREP}" "${DREP}"
"${DREP}" dereplicate "${OUT}/drep" -g "${MAG_INPUT_DIR}"/*.fa -p "${THREADS_PER_JOB}" \
  -comp "${MAG_MIN_COMPLETENESS}" -con "${MAG_MAX_CONTAMINATION}" \
  -pa "${DREP_PRIMARY_ANI}" -sa "${DREP_SECONDARY_ANI}"
export GTDBTK_DATA_PATH
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_MAG_TAXONOMY}" "${GTDBTK}"
"${GTDBTK}" classify_wf --genome_dir "${OUT}/drep/dereplicated_genomes" --out_dir "${OUT}/gtdbtk" \
  --extension fa --cpus "${THREADS_PER_JOB}"
