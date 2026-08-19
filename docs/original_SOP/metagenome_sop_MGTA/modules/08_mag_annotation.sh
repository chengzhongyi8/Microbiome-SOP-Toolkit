#!/usr/bin/env bash
# ============================================================================
# 08_mag_annotation.sh — MAG 下游：coverM 丰度定量 + GTDB-Tk 物种注释 + Prodigal 基因预测 + KofamScan 功能注释
#
# 输入:  ${RESULT_DIR}/mags/drep/dereplicated_genomes/*.fa   (07 去冗余后的 MAG)
#        ${WORK_DIR}/qc/clean/*_{1,2}.fq.gz                  (clean reads，回比算丰度)
# 输出:
#   ${RESULT_DIR}/mags/abundance/MAG_abundance.tsv          (coverM: MAG×样本 丰度矩阵)
#   ${RESULT_DIR}/mags/annotations/gtdb/tax.bac120.summary.tsv|tax.ar53.summary.tsv  (GTDB-Tk)
#   ${RESULT_DIR}/mags/annotations/prodigal/proteins|genes|gff/    (每 MAG 基因预测)
#   ${RESULT_DIR}/mags/annotations/kofam/detail|final/             (KofamScan KO 注释)
#   ${RESULT_DIR}/mags/annotations/kofam_summary.tsv               (Bin|蛋白数|KO数 汇总)
#
# 逻辑:
#   coverM genome(丰度) -> GTDB-Tk classify_wf(物种) -> Prodigal -p single(每个 MAG 独立训练)
#   -> KofamScan(KO) -> 汇总表
#   开关: --mag-quant yes 只跑丰度；--mag-annotate yes 只跑注释；两者都开则全跑
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

MAG_INPUT="${RESULT_DIR}/mags/drep/dereplicated_genomes"
# 若 07 做了质量筛选（--mag-filter yes），优先用筛选后的 MAG 集
if [[ -d "${RESULT_DIR}/mags/filtered_genomes" ]] \
   && [[ -n "$(ls "${RESULT_DIR}/mags/filtered_genomes"/*.fa 2>/dev/null)" ]]; then
  MAG_INPUT="${RESULT_DIR}/mags/filtered_genomes"
  echo "==> 使用质量筛选后的 MAG 集: ${MAG_INPUT}"
fi
ABUND="${RESULT_DIR}/mags/abundance"
ANN="${RESULT_DIR}/mags/annotations"
GTDB_OUT="${ANN}/gtdb"
PRODIGAL_DIR="${ANN}/prodigal"
PROTEIN_DIR="${PRODIGAL_DIR}/proteins"
GENE_DIR="${PRODIGAL_DIR}/genes"
GFF_DIR="${PRODIGAL_DIR}/gff"
PRODIGAL_LOG_DIR="${PRODIGAL_DIR}/logs"
KOFAM_DIR="${ANN}/kofam"
KOFAM_DETAIL_DIR="${KOFAM_DIR}/detail"
KOFAM_FINAL_DIR="${KOFAM_DIR}/final"
KOFAM_TMP_DIR="${KOFAM_DIR}/tmp"
KOFAM_LOG_DIR="${KOFAM_DIR}/logs"

[[ "${MAG_QUANT:-no}" == "yes" || "${MAG_ANNOTATE:-no}" == "yes" ]] || { echo "MAG 下游分析已跳过 (--mag-quant/--mag-annotate 均 no)"; exit 0; }
[[ -d "${MAG_INPUT}" ]] || { echo "ERROR: ${MAG_INPUT} 不存在（先运行 07 binning）" >&2; exit 1; }
MAG_NUM=$(ls "${MAG_INPUT}"/*.fa 2>/dev/null | wc -l | tr -d ' ')
[[ "${MAG_NUM}" -gt 0 ]] || { echo "ERROR: ${MAG_INPUT} 中没有 MAG" >&2; exit 1; }
echo "==> 检测到 ${MAG_NUM} 个 MAG"

# ---- 1. coverM 丰度定量（可选，--mag-quant yes）-------------------------------
if [[ "${MAG_QUANT:-no}" == "yes" ]]; then
  echo "==> coverM genome 丰度定量（${MAG_NUM} 个 MAG × 全部 clean reads）"
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_COVERM}" coverm
  COVERM_BIN="$(resolve_tool COVERM)"
  CLEAN_DIR="${WORK_DIR}/qc/clean"
  ABUND_TMP="${ABUND}/by_sample"
  mkdir -p "${ABUND_TMP}"
  # 样本清单来自 samples.tsv（与全流程一致，保证每个样本都定量）
  SAMPLES_FILE="${WORK_DIR}/samples.tsv"
  SAMPLES=()
  while IFS=$'\t' read -r _s _rest; do
    [[ -n "${_s}" && "${_s}" != "sample_id" ]] && SAMPLES+=("${_s}")
  done < "${SAMPLES_FILE}"
  [[ "${#SAMPLES[@]}" -gt 0 ]] || { echo "ERROR: 没有可定量的样本（samples.tsv 为空）" >&2; exit 1; }

  export COVERM_BIN MAG_INPUT CLEAN_DIR ABUND_TMP THREADS MAG_QUANT_METHODS
  run_pool "${CONCURRENT_JOBS:-${THREADS}}" "${PIPELINE_DIR}/bin/workers/08_coverm.sh" "${SAMPLES[@]}"
  # 合并为 MAG×样本 矩阵
  python3 "${PIPELINE_DIR}/bin/merge_coverm.py" \
      "${ABUND_TMP}" "${SAMPLES[@]}" > "${ABUND}/MAG_abundance.tsv"
  echo "  -> MAG_abundance.tsv（$(wc -l < "${ABUND}/MAG_abundance.tsv") 行）"
fi

# ---- 2. GTDB-Tk 物种注释（可选，--mag-annotate yes）---------------------------
if [[ "${MAG_ANNOTATE:-no}" == "yes" ]]; then
mkdir -p "${PROTEIN_DIR}" "${GENE_DIR}" "${GFF_DIR}" "${PRODIGAL_LOG_DIR}" \
         "${KOFAM_DETAIL_DIR}" "${KOFAM_FINAL_DIR}" "${KOFAM_TMP_DIR}" "${KOFAM_LOG_DIR}"

if [[ -s "${GTDB_OUT}/tax.bac120.summary.tsv" || -s "${GTDB_OUT}/tax.ar53.summary.tsv" ]]; then
  echo "[skip] GTDB-Tk 结果已存在"
else
  echo "==> GTDB-Tk classify_wf（${MAG_NUM} 个 MAG，耗时较长）"
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_GTDBTK}" gtdbtk
  [[ -d "${GTDBTK_DATA_PATH:-}" ]] || { echo "ERROR: GTDBTK_DATA_PATH 不存在: ${GTDBTK_DATA_PATH}" >&2; exit 1; }
  export GTDBTK_DATA_PATH
  rm -rf "${GTDB_OUT}"
  gtdbtk classify_wf \
      --genome_dir "${MAG_INPUT}" \
      --out_dir "${GTDB_OUT}" \
      --extension fa --prefix tax \
      --cpus "${THREADS}" \
      --pplacer_cpus "${GTDBTK_PPLACER_CPUS:-1}"
fi

# ---- 3. Prodigal 基因预测（-p single：每个较完整 MAG 训练自身模型）----------
echo "==> Prodigal 基因预测（-p single）"
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_MAG_PRODIGAL}" prodigal
for fa_file in "${MAG_INPUT}"/*.fa; do
  base_name="$(basename "${fa_file}" .fa)"
  protein_file="${PROTEIN_DIR}/${base_name}.faa"
  gene_file="${GENE_DIR}/${base_name}.fna"
  gff_file="${GFF_DIR}/${base_name}.gff"
  log_file="${PRODIGAL_LOG_DIR}/${base_name}.prodigal.log"
  if [[ -s "${protein_file}" && -s "${gene_file}" && -s "${gff_file}" ]]; then
    echo "[skip] ${base_name}"
    continue
  fi
  echo "[run ] Prodigal: ${base_name}"
  prodigal -i "${fa_file}" -a "${protein_file}" -d "${gene_file}" \
      -o "${gff_file}" -p single -f gff 2> "${log_file}"
done

# ---- 4. KofamScan 功能注释 ---------------------------------------------------
echo "==> KofamScan（KEGG KO 注释）"
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_KOFAM}" exec_annotation
[[ -d "${KOFAM_PROFILE}" ]] || { echo "ERROR: KOFAM_PROFILE 不存在: ${KOFAM_PROFILE}" >&2; exit 1; }
[[ -s "${KOFAM_KO_LIST}" ]] || { echo "ERROR: KOFAM_KO_LIST 不存在: ${KOFAM_KO_LIST}" >&2; exit 1; }
for protein_file in "${PROTEIN_DIR}"/*.faa; do
  base_name="$(basename "${protein_file}" .faa)"
  detail_file="${KOFAM_DETAIL_DIR}/${base_name}.kofam.detail.tsv"
  final_file="${KOFAM_FINAL_DIR}/${base_name}.kofam.final.tsv"
  tmp_dir="${KOFAM_TMP_DIR}/${base_name}"
  log_file="${KOFAM_LOG_DIR}/${base_name}.kofam.log"
  if [[ -s "${detail_file}" ]]; then
    echo "[skip] KofamScan: ${base_name}"
  else
    echo "[run ] KofamScan: ${base_name}"
    rm -rf "${tmp_dir}"; mkdir -p "${tmp_dir}"
    exec_annotation -f detail-tsv -o "${detail_file}" \
        -p "${KOFAM_PROFILE}" -k "${KOFAM_KO_LIST}" \
        -E 1e-5 --cpu "${THREADS}" --tmp-dir "${tmp_dir}" \
        "${protein_file}" > "${log_file}" 2>&1
  fi
  # detail-tsv 中行首为 * 的记录通过 KOfam score threshold
  awk -F '\t' '$1 == "*"' "${detail_file}" > "${final_file}"
done

# ---- 5. 汇总 -----------------------------------------------------------------
echo "==> 汇总（Bin | 蛋白数 | KO 数）"
SUMMARY_FILE="${ANN}/kofam_summary.tsv"
printf 'Bin\tProtein_number\tKO_assignment_number\n' > "${SUMMARY_FILE}"
for protein_file in "${PROTEIN_DIR}"/*.faa; do
  base_name="$(basename "${protein_file}" .faa)"
  final_file="${KOFAM_FINAL_DIR}/${base_name}.kofam.final.tsv"
  protein_num="$(grep -c '^>' "${protein_file}" || true)"
  if [[ -f "${final_file}" ]]; then ko_num="$(wc -l < "${final_file}")"; else ko_num=0; fi
  printf '%s\t%s\t%s\n' "${base_name}" "${protein_num}" "${ko_num}" >> "${SUMMARY_FILE}"
done

# ---- 5b. 合并所有 bin 的 KofamScan 注释 -------------------------------------
# 长表 + KO×Bin 计数矩阵 + best-hit 矩阵（见 bin/merge_kofam.py 说明）
if [[ -n "$(ls "${KOFAM_FINAL_DIR}"/*.kofam.final.tsv 2>/dev/null)" ]]; then
  echo "==> 合并 KofamScan 注释（长表 + KO×Bin 矩阵）"
  python3 "${PIPELINE_DIR}/bin/merge_kofam.py" "${KOFAM_FINAL_DIR}" \
      -o "${KOFAM_DIR}/kofam_merged" \
      || echo "WARN: KofamScan 合并失败（不影响已产出的逐 bin 注释）" >&2
fi
fi  # MAG_ANNOTATE == yes

echo "08_mag_annotation.sh 完成：${ABUND} ${ANN}"
[[ "${MAG_QUANT:-no}" == "yes" ]] && echo "  coverM 丰度: ${ABUND}/MAG_abundance.tsv"
[[ "${MAG_ANNOTATE:-no}" == "yes" ]] && echo "  GTDB-Tk: ${GTDB_OUT}" && echo "  KofamScan 汇总: ${SUMMARY_FILE}"
