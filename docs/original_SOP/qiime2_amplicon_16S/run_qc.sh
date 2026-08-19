#!/usr/bin/env bash
# Purpose: stage 1 runner for validation, manifest, import, quality summary, then stop.
# Input: config.sh, FASTQ, metadata. Output: demux qza/qzv and read counts.
# Software: stage 1 dependencies. Resources: defined by component scripts.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/00_check_input.sh"
bash "${SCRIPT_DIR}/01_make_manifest.sh"
bash "${SCRIPT_DIR}/02_import_and_qc.sh"
