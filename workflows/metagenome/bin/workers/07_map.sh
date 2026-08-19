#!/usr/bin/env bash
# Worker: 单样本 bowtie2 比对到组装（07_binning 并行调用；gz reads 原生读取）
# Usage: 07_map.sh <sample>
# 环境变量: ASM_ID(组装名) IDX(索引前缀) CLEAN_DIR BAM_DIR THREADS
#
# 采用"分段落盘 + 逐步校验"：bowtie2 -> SAM 落盘 -> samtools view -> BAM 落盘 -> sort -> index
# 任何一步产物无效都明确报错，避免管道静默产出空 BAM。
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

SAMPLE="$1"
R1="${CLEAN_DIR}/${SAMPLE}_1.fq.gz"
R2="${CLEAN_DIR}/${SAMPLE}_2.fq.gz"
BAM="${BAM_DIR}/${SAMPLE}.bam"

# 已有有效 BAM 则跳过；无效（空/坏）则重比对
if [[ -s "${BAM}" ]] && "${SAMTOOLS_BIN:-samtools}" quickcheck "${BAM}" 2>/dev/null; then
  echo "[skip] ${SAMPLE} bam 有效，已存在" >&2
  exit 0
fi
[[ -e "${BAM}" ]] && rm -f "${BAM}" "${BAM}.bai"

[[ -s "${R1}" && -s "${R2}" ]] || { echo "ERROR: ${SAMPLE} clean reads 缺失" >&2; exit 1; }
BOWTIE2_BIN="$(resolve_tool BOWTIE2)"
SAMTOOLS_BIN="$(resolve_tool SAMTOOLS)"

echo "[run ] ${SAMPLE} bowtie2 比对（gz）" >&2

# 1) bowtie2 -> SAM 落盘（校验非空且有 @SQ）
SAM="${BAM_DIR}/${SAMPLE}.sam"
"${BOWTIE2_BIN}" -x "${IDX}" -1 "${R1}" -2 "${R2}" -p "${THREADS}" \
    --very-sensitive -S "${SAM}" 2> "${BAM_DIR}/${SAMPLE}.bowtie2.log"
[[ -s "${SAM}" ]] || { echo "ERROR: ${SAMPLE} bowtie2 未产出 SAM（见 .bowtie2.log）" >&2; exit 1; }
if ! grep -q "^@SQ" "${SAM}"; then
  echo "ERROR: ${SAMPLE} SAM 无 @SQ 头（索引或输入异常）" >&2
  exit 1
fi

# 2) SAM -> BAM（过滤 secondary/supplementary/unmapped）
"${SAMTOOLS_BIN}" view -b -F 0x904 -o "${BAM_DIR}/${SAMPLE}.raw.bam" "${SAM}"
"${SAMTOOLS_BIN}" sort -@ "${THREADS}" -o "${BAM}" "${BAM_DIR}/${SAMPLE}.raw.bam"
rm -f "${BAM_DIR}/${SAMPLE}.raw.bam" "${SAM}"

# 3) 校验 BAM 有 reads
n_reads="$("${SAMTOOLS_BIN}" view -c "${BAM}" 2>/dev/null || echo 0)"
if [[ "${n_reads}" -le 0 ]]; then
  echo "WARNING: ${SAMPLE} BAM 比对到组装上的 reads 为 0（组装 contigs 太少或 reads 不匹配），仍继续" >&2
fi
"${SAMTOOLS_BIN}" index -@ "${THREADS}" "${BAM}"
echo "[done] ${SAMPLE} bam (${n_reads} reads)" >&2
