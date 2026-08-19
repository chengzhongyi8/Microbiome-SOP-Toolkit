#!/usr/bin/env bash
# Worker: 单样本 reads 回比组装 contigs，计算每个 contig 的平均覆盖深度
# Usage: 04_contig_cov.sh <sample>
# 输入:  ${WORK_DIR}/qc/clean/<sample>_{1,2}.fq.gz
#        ${WORK_DIR}/contig_cov/assembly*.bt2(l)   (04_quant 已建索引)
# 输出:  ${WORK_DIR}/contig_cov/<sample>.depth.sum.tsv  contig<TAB>sum(depth)
#        ${WORK_DIR}/contig_cov/<sample>.length.tsv     contig<TAB>length
# 说明:  平均深度 = sum(depth)/contig_len（含未覆盖=0，口径同 MetaBAT2 totalAvgDepth）。
#        提取完深度后删除 BAM 省空间；BAM 不是 checkpoint，深度表才是。
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

BOWTIE2_BIN="$(resolve_tool BOWTIE2)"
SAMTOOLS_BIN="$(resolve_tool SAMTOOLS)"
SAMPLE="$1"
CLEAN_DIR="${WORK_DIR}/qc/clean"
CC_WORK="${WORK_DIR}/contig_cov"
mkdir -p "${CC_WORK}/bam"

[[ -s "${CC_WORK}/${SAMPLE}.length.tsv" && -s "${CC_WORK}/${SAMPLE}.depth.sum.tsv" ]] && { echo "[skip] ${SAMPLE}" >&2; exit 0; }
[[ -s "${CLEAN_DIR}/${SAMPLE}_1.fq.gz" && -s "${CLEAN_DIR}/${SAMPLE}_2.fq.gz" ]] || { echo "ERROR: ${SAMPLE} clean reads 不存在" >&2; exit 1; }
for f in "${CC_WORK}"/assembly.1.bt2 "${CC_WORK}"/assembly.1.bt2l; do
  [[ -e "${f}" ]] && { INDEX_OK="yes"; break; }
done
[[ "${INDEX_OK:-no}" == "yes" ]] || { echo "ERROR: contig 索引不存在 ${CC_WORK}/assembly（先建索引）" >&2; exit 1; }

bam="${CC_WORK}/bam/${SAMPLE}.bam"
"${BOWTIE2_BIN}" -x "${CC_WORK}/assembly" \
    -1 "${CLEAN_DIR}/${SAMPLE}_1.fq.gz" -2 "${CLEAN_DIR}/${SAMPLE}_2.fq.gz" \
    -p "${THREADS}" --very-sensitive -S - 2> "${CC_WORK}/${SAMPLE}.bowtie2.log" | \
  "${SAMTOOLS_BIN}" view -S -b -F 0x904 - | \
  "${SAMTOOLS_BIN}" sort -@ "${THREADS}" -o "${bam}"
"${SAMTOOLS_BIN}" index "${bam}"
"${SAMTOOLS_BIN}" idxstats "${bam}" | awk -F '\t' '!/^\*/{print $1"\t"$2}' > "${CC_WORK}/${SAMPLE}.length.tsv"
"${SAMTOOLS_BIN}" depth "${bam}" | awk '{sum[$1]+=$3} END{for(c in sum) print c"\t"sum[c]}' > "${CC_WORK}/${SAMPLE}.depth.sum.tsv"
# 深度已提取，删除 BAM/索引省空间
rm -f "${bam}" "${bam}.bai"
echo "[done] ${SAMPLE} contig depth"
