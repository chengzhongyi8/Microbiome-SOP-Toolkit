#!/usr/bin/env bash
# Purpose: write a per-project config.local.sh without running the pipeline.
# Usage: bash setup_project.sh [same options as run_all.sh]
#   e.g. bash setup_project.sh --fastq-dir /data/fastq --region 16S_V4 \
#            --classifier /db/silva-138-99-515-806-nb-classifier.qza
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/run_all.sh" --init-only "$@"
