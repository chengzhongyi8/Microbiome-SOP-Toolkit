#!/usr/bin/env bash
# Worker: 单样本 coverM genome 丰度定量（08_mag_annotation 并行调用）
# Usage: 08_coverm.sh <sample>
# 环境变量: COVERM_BIN MAG_INPUT CLEAN_DIR ABUND_TMP THREADS
# 输出:    ${ABUND_TMP}/<sample>.tsv   (Genome, Contig, <sample>.coverage, <sample>.relative_abundance)
set -euo pipefail

S="$1"
R1="${CLEAN_DIR}/${S}_1.fq.gz"; R2="${CLEAN_DIR}/${S}_2.fq.gz"
OUT="${ABUND_TMP}/${S}.tsv"
[[ -s "${OUT}" ]] && { echo "[skip] coverM ${S}" >&2; exit 0; }
[[ -s "${R1}" && -s "${R2}" ]] || { echo "ERROR: ${S} clean reads 缺失" >&2; exit 1; }

echo "[run ] coverM: ${S}" >&2
# 用 --genome-fasta-files 显式列出全部 MAG（--genome-fasta-directory 默认只认 .fna，
# 会忽略 .fa/.fasta -> "none were found"）；三扩展名都收，过滤不存在的 glob 字面量。
MAG_FILES=()
for f in "${MAG_INPUT}"/*.fa "${MAG_INPUT}"/*.fasta "${MAG_INPUT}"/*.fna; do
  [[ -s "${f}" ]] && MAG_FILES+=("${f}")
done
[[ "${#MAG_FILES[@]}" -gt 0 ]] || { echo "ERROR: ${S} 未找到任何 MAG fasta（${MAG_INPUT}）" >&2; exit 1; }
# 不显式传 --methods：coverM 0.6.x 的 coverage 是默认聚合方法，显式传会报
# "'coverage' isn't a valid value for '--methods'"；默认输出即 coverage + relative_abundance 两列。
# 配置 MAG_QUANT_METHODS（如 "rpkm tpm"）时追加到 --methods（这些值 coverM 接受）。
COVERM_ARGS=(genome --genome-fasta-files "${MAG_FILES[@]}" --coupled "${R1}" "${R2}")
if [[ -n "${MAG_QUANT_METHODS:-}" ]]; then
  read -r -a METHODS_ARR <<< "${MAG_QUANT_METHODS}"
  COVERM_ARGS+=(--methods "${METHODS_ARR[@]}")
fi
COVERM_ARGS+=(-o "${OUT}" -t "${THREADS}")
"${COVERM_BIN}" "${COVERM_ARGS[@]}" \
    > "${ABUND_TMP}/${S}.coverm.log" 2>&1 \
    || { echo "ERROR: ${S} coverM 失败（见 ${ABUND_TMP}/${S}.coverm.log）" >&2; exit 1; }
echo "[done] coverM ${S}" >&2
