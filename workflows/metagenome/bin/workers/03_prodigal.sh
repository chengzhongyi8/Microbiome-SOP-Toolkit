#!/usr/bin/env bash
# Worker: prodigal 单块基因预测（03_gene_catalog 并行调用）
# Usage: 03_prodigal.sh <chunk.fa>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"

CHUNK="$1"
BASE="$(basename "${CHUNK}" .fa)"
PRED_WORK="${WORK_DIR}/gene_catalog"
[[ -s "${PRED_WORK}/split/${BASE}.fna" && -s "${PRED_WORK}/split/${BASE}.faa" ]] && exit 0
prodigal -i "${CHUNK}" -p meta -f gff \
    -o "${PRED_WORK}/split/${BASE}.gff" \
    -d "${PRED_WORK}/split/${BASE}.fna" \
    -a "${PRED_WORK}/split/${BASE}.faa" \
    > "${PRED_WORK}/split/${BASE}.log" 2>&1
