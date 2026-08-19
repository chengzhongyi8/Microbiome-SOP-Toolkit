#!/usr/bin/env bash
# Stage-1 runner: validation -> manifest -> import -> quality summary, then stop.
#
#   bash workflows/16s/run_qc.sh [--project-dir DIR] [--config FILE.yaml]
#
# After this stops, inspect results/qc/demux.qzv, then run run_after_qc.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# forward --project-dir / --config into the environment for the step scripts
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) export PROJECT_DIR="${2:?missing --project-dir}"; shift 2 ;;
    --config)      CFG="${2:?missing --config}"; eval "$(python3 "${WORKFLOW_DIR}/../../bin/yaml2env.py" 16s "${CFG}")"; export PROJECT_DIR; shift 2 ;;
    *) echo "unknown option: $1 (use --project-dir DIR or --config FILE)" >&2; exit 1 ;;
  esac
done

bash "${SCRIPT_DIR}/steps/00_check_input.sh"
bash "${SCRIPT_DIR}/steps/01_make_manifest.sh"
bash "${SCRIPT_DIR}/steps/02_import_and_qc.sh"
