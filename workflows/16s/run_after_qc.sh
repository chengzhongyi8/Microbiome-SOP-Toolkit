#!/usr/bin/env bash
# Stage-2 runner: cutadapt -> auto DADA2 params -> DADA2 -> taxonomy/filter ->
# phylogeny -> microeco export -> summary.
#
#   bash workflows/16s/run_after_qc.sh [--project-dir DIR] [--config FILE.yaml]
#
# Stage 1 (run_qc.sh) must have completed first.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) export PROJECT_DIR="${2:?missing --project-dir}"; shift 2 ;;
    --config)      CFG="${2:?missing --config}"; eval "$(python3 "${WORKFLOW_DIR}/../../bin/yaml2env.py" 16s "${CFG}")"; export PROJECT_DIR; shift 2 ;;
    *) echo "unknown option: $1 (use --project-dir DIR or --config FILE)" >&2; exit 1 ;;
  esac
done

bash "${SCRIPT_DIR}/steps/03_cutadapt_optional.sh"
bash "${SCRIPT_DIR}/steps/08_auto_dada2_params.sh"
bash "${SCRIPT_DIR}/steps/04_dada2.sh"
bash "${SCRIPT_DIR}/steps/05_taxonomy_filter.sh"
bash "${SCRIPT_DIR}/steps/06_phylogeny.sh"
bash "${SCRIPT_DIR}/steps/07_export_microeco.sh"
bash "${SCRIPT_DIR}/steps/09_summary.sh"
