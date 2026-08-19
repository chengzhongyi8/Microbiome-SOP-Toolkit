#!/usr/bin/env bash
# Worker: 单样本 MEGAHIT 组装（02_assembly 并行调用）
# Usage: 02_megahit.sh <sample>
# 环境变量: CLEAN_DIR ASSEMBLY_WORK THREADS 及 megahit 参数
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"

SAMPLE="$1"
OUTDIR="${ASSEMBLY_WORK}/per_sample/${SAMPLE}"
[[ -s "${OUTDIR}/final.contigs.fa" ]] && { echo "[skip] ${SAMPLE} 组装已存在" >&2; exit 0; }
# megahit 要求输出目录不存在；存在但无结果 = 残留，清掉
[[ -d "${OUTDIR}" ]] && rm -rf "${OUTDIR}"
echo "[run ] ${SAMPLE} megahit" >&2
megahit -1 "${CLEAN_DIR}/${SAMPLE}_1.fq.gz" -2 "${CLEAN_DIR}/${SAMPLE}_2.fq.gz" \
    -o "${OUTDIR}" -t "${THREADS}" \
    --k-min "${MEGAHIT_K_MIN}" --k-max "${MEGAHIT_K_MAX}" --k-step "${MEGAHIT_K_STEP}" \
    --min-contig-len "${MEGAHIT_MIN_CONTIG_LEN}"
# 清理 megahit 中间文件（保留 final.contigs.fa 与 log/options），避免大输入磁盘爆炸
# 中间文件形如 k21.contigs.fa / k29.contigs.fa（以 k 开头）与 intermediate_contigs/
if [[ -s "${OUTDIR}/final.contigs.fa" ]]; then
  rm -rf "${OUTDIR}/intermediate_contigs" "${OUTDIR}"/k*.contigs.fa 2>/dev/null || true
  echo "    已清理 megahit 中间文件: ${OUTDIR}" >&2
fi
