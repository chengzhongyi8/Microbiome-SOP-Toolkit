#!/usr/bin/env bash
# Worker: salmon 单样本定量（04_quant 并行调用）
# Usage: 04_salmon.sh <sample>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

SALMON_BIN="$(resolve_tool SALMON)"
SAMPLE="$1"
QUANT_WORK="${WORK_DIR}/quant"
CLEAN_DIR="${WORK_DIR}/qc/clean"
mkdir -p "${QUANT_WORK}/salmon/quant"
[[ -s "${QUANT_WORK}/salmon/quant/${SAMPLE}/quant.sf" ]] && { echo "[skip] ${SAMPLE}" >&2; exit 0; }
# salmon 要求输出目录不存在；存在但无结果 = 残留，清掉
[[ -d "${QUANT_WORK}/salmon/quant/${SAMPLE}" ]] && rm -rf "${QUANT_WORK}/salmon/quant/${SAMPLE}"
"${SALMON_BIN}" quant -i "${QUANT_WORK}/salmon/index" -l A --meta --validateMappings \
    -1 "${CLEAN_DIR}/${SAMPLE}_1.fq.gz" -2 "${CLEAN_DIR}/${SAMPLE}_2.fq.gz" \
    -p "${THREADS}" -o "${QUANT_WORK}/salmon/quant/${SAMPLE}"
