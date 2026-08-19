#!/usr/bin/env bash
# Worker: emapper.py --no_annot 单块比对（06_function 并行调用）
# Usage: 06_emapper.sh <chunk.faa>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"

# 若开启了 EGGNOG_SHM，worker 也必须用 /dev/shm 副本（模块 06 已复制好）
if [[ "${EGGNOG_SHM:-no}" == "yes" ]]; then
  EGGNOG_DATA_DIR="/dev/shm/eggnog_${USER:-user}"
fi

CHUNK="$1"
BASE="$(basename "${CHUNK}" .faa)"
FUNC_WORK="${WORK_DIR}/function"
OUTDIR="${FUNC_WORK}/emapper/${BASE}"
[[ -s "${OUTDIR}/${BASE}.emapper.seed_orthologs" ]] && exit 0
mkdir -p "${OUTDIR}"
# 每块 CPU = THREADS/CONCURRENT_JOBS（至少 1），避免 8 块 × 28 线程 = 224 线程超卖节点
EMAPPER_CPU=$(( THREADS / CONCURRENT_JOBS ))
[[ "${EMAPPER_CPU}" -lt 1 ]] && EMAPPER_CPU=1
( cd "${OUTDIR}" && \
  emapper.py -m diamond --no_annot --no_file_comments --override \
    --data_dir "${EGGNOG_DATA_DIR}" --cpu "${EMAPPER_CPU}" \
    -i "${CHUNK}" -o "${BASE}" > emapper.log 2>&1 )
