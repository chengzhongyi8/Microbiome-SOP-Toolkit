#!/usr/bin/env bash
# ============================================================================
# 06_function.sh — 功能注释（eggNOG-mapper, diamond 模式）
#
# 输入:  ${RESULT_DIR}/gene_catalog/catalog/gene_catalog.faa
#        ${RESULT_DIR}/quant/gene.TPM.tsv
# 输出:
#   ${RESULT_DIR}/function/eggnog.annotations.tsv
#   ${RESULT_DIR}/function/gene_annotation.tsv   (基因 -> KO/CAZy/COG/描述)
#   ${RESULT_DIR}/function/KO.tsv / CAZy.tsv / COG.tsv   (功能丰度表)
#   ${RESULT_DIR}/function/KEGG_module_completeness.tsv    (模块完整度, 需 module.ko)
#   ${RESULT_DIR}/function/KEGG_pathway_completeness.tsv   (通路完整度, 需 ko00001.keg)
#   （未配定义文件时输出 KEGG_module_detected.tsv / KEGG_pathway_detected.tsv）
#
# 逻辑:
#   单行化 + 按长度过滤 -> seqkit split2 安全拆块 -> 并行 emapper --no_annot
#   -> 合并 seed_orthologs -> --annotate_hits_table 注释 -> python 汇总
#   -> KEGG Pathway/Module 完整度（bin/kegg_completeness.py）
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

PROT_FA="${RESULT_DIR}/gene_catalog/catalog/gene_catalog.faa"
# 丰度文件按定量工具选：salmon->TPM，bwa->FPKM
if [[ "${QUANT_TOOL:-salmon}" == "bwa" ]]; then
  ABUNDANCE="${RESULT_DIR}/quant/gene.FPKM.tsv"
else
  ABUNDANCE="${RESULT_DIR}/quant/gene.TPM.tsv"
fi
FUNC_WORK="${WORK_DIR}/function"
FUNC_RESULT="${RESULT_DIR}/function"

[[ "${FUNCTION_TOOL:-eggnog}" == "none" ]] && { echo "功能注释已跳过 (--function none)"; exit 0; }
[[ -s "${PROT_FA}" ]] || { echo "ERROR: ${PROT_FA} 不存在（先运行 03_gene_catalog）" >&2; exit 1; }
[[ -s "${ABUNDANCE}" ]] || { echo "ERROR: 丰度文件不存在: ${ABUNDANCE}（先运行 04_quant）" >&2; exit 1; }
[[ -d "${EGGNOG_DATA_DIR}" ]] || { echo "ERROR: eggNOG 数据库目录不存在: ${EGGNOG_DATA_DIR}" >&2; exit 1; }
# KEGG 定义文件（可选）：填了路径但不存在则明确报错
for v in KEGG_MODULE_DEF KEGG_MODULE_NAME KEGG_PATHWAY_DEF; do
  val="${!v:-}"
  [[ -z "${val}" || -f "${val}" ]] || {
    echo "ERROR: ${v} 文件不存在: ${val}（不需要完整度可清空该参数）" >&2; exit 1; }
done
mkdir -p "${FUNC_RESULT}"

# ---- 0. 可选：把 eggNOG 数据库复制到 /dev/shm（内存盘）加速 -------------------
EGGNOG_SHM_DIR="/dev/shm/eggnog_${USER:-user}"
if [[ "${EGGNOG_SHM:-no}" == "yes" ]]; then
  [[ -d "/dev/shm" ]] || { echo "ERROR: /dev/shm 不存在（此节点不支持）" >&2; exit 1; }
  echo "==> 复制 eggNOG 数据库到 /dev/shm（${EGGNOG_DATA_DIR} -> ${EGGNOG_SHM_DIR}）"
  db_mb="$(du -sm "${EGGNOG_DATA_DIR}" 2>/dev/null | awk '{print $1}')"
  shm_mb="$(df -Pm /dev/shm | awk 'NR==2{print $4}')"
  echo "    数据库大小: ${db_mb} MB；/dev/shm 可用: ${shm_mb} MB"
  if [[ -n "${db_mb}" && -n "${shm_mb}" && "${db_mb}" -ge "${shm_mb}" ]]; then
    echo "ERROR: /dev/shm 空间不足（需要 ${db_mb}MB，可用 ${shm_mb}MB），请关闭 --eggnog-shm 或换大内存节点" >&2
    exit 1
  fi
  if [[ ! -f "${EGGNOG_SHM_DIR}/.complete" ]]; then
    rm -rf "${EGGNOG_SHM_DIR}"
    cp -r "${EGGNOG_DATA_DIR}" "${EGGNOG_SHM_DIR}"
    touch "${EGGNOG_SHM_DIR}/.complete"
  fi
  EGGNOG_DATA_DIR="${EGGNOG_SHM_DIR}"
fi

# ---- 1. 单行化 + 长度过滤 ----------------------------------------------------
echo "==> 准备蛋白序列 (单行化 + 长度 >= ${EGGNOG_PROT_MIN_LEN})"
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_GENE}" seqkit
mkdir -p "${FUNC_WORK}/split"
if [[ ! -s "${FUNC_WORK}/protein.single.faa" ]]; then
  seqkit seq -w 0 -m "${EGGNOG_PROT_MIN_LEN}" "${PROT_FA}" > "${FUNC_WORK}/protein.single.faa"
fi

# ---- 2. 拆块（安全：按完整 record）------------------------------------------
if [[ -z "$(ls -A "${FUNC_WORK}/split" 2>/dev/null)" ]]; then
  seqkit split2 -s "${EGGNOG_SPLIT_SEQS}" --out-dir "${FUNC_WORK}/split" "${FUNC_WORK}/protein.single.faa"
fi
CHUNKS=(); while IFS= read -r l; do CHUNKS+=("$l"); done < <(ls "${FUNC_WORK}/split"/*.faa 2>/dev/null | sort)
[[ "${#CHUNKS[@]}" -gt 0 ]] || { echo "ERROR: eggNOG 拆块失败" >&2; exit 1; }

# ---- 3. 并行 diamond 比对（--no_annot）---------------------------------------
echo "==> emapper.py -m diamond --no_annot (${#CHUNKS[@]} 块, 并行 ${CONCURRENT_JOBS})"
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_EGGNOG}" emapper.py
run_pool "${CONCURRENT_JOBS}" "${PIPELINE_DIR}/bin/workers/06_emapper.sh" "${CHUNKS[@]}"

# ---- 4. 合并 seed_orthologs + 注释 -------------------------------------------
echo "==> 合并 seed_orthologs 并注释"
mkdir -p "${FUNC_WORK}/annotate"
cat "${FUNC_WORK}"/emapper/*/*.emapper.seed_orthologs > "${FUNC_WORK}/annotate/merged.seed_orthologs"
if [[ ! -s "${FUNC_WORK}/annotate/output.emapper.annotations" ]]; then
  ( cd "${FUNC_WORK}/annotate" && \
    emapper.py --annotate_hits_table merged.seed_orthologs \
      --no_file_comments --override \
      --data_dir "${EGGNOG_DATA_DIR}" --cpu "${THREADS}" \
      -o output > annotate.log 2>&1 )
fi
[[ -s "${FUNC_WORK}/annotate/output.emapper.annotations" ]] || {
  echo "ERROR: eggNOG 注释失败，见 ${FUNC_WORK}/annotate/annotate.log" >&2; exit 1; }
cp -f "${FUNC_WORK}/annotate/output.emapper.annotations" "${FUNC_RESULT}/eggnog.annotations.tsv"

# ---- 5. 汇总功能丰度表 --------------------------------------------------------
echo "==> 汇总 KO/CAZy/COG 丰度表"
run_py3 "${PIPELINE_DIR}/bin/summarize_eggnog.py" \
    --abundance "${ABUNDANCE}" \
    --annotations "${FUNC_RESULT}/eggnog.annotations.tsv" \
    --outdir "${FUNC_RESULT}"

# ---- 6. KEGG Pathway/Module 完整度 --------------------------------------------
# 有 module.ko / ko00001.keg 定义文件 -> 输出完整度矩阵；
# 没有 -> 退化为检测表（只用 emapper 的 KEGG_Module / KEGG_Pathway 列）。
echo "==> KEGG Pathway/Module 完整度"
run_py3 "${PIPELINE_DIR}/bin/kegg_completeness.py" \
    --abundance "${ABUNDANCE}" \
    --annotations "${FUNC_RESULT}/eggnog.annotations.tsv" \
    --outdir "${FUNC_RESULT}" \
    --module-def "${KEGG_MODULE_DEF:-}" \
    --module-name "${KEGG_MODULE_NAME:-}" \
    --pathway-def "${KEGG_PATHWAY_DEF:-}" \
    --threshold "${KEGG_COMPLETE_THRESHOLD:-1.0}"

if [[ "${EGGNOG_SHM:-no}" == "yes" ]]; then
  echo "==> 清理 /dev/shm 副本 ${EGGNOG_SHM_DIR}"
  rm -rf "${EGGNOG_SHM_DIR}"
fi

echo "06_function.sh 完成：${FUNC_RESULT}"
