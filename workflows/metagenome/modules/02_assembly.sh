#!/usr/bin/env bash
# ============================================================================
# 02_assembly.sh — 组装（MEGAHIT）
#
# 输入:
#   ${WORK_DIR}/samples.tsv, ${WORK_DIR}/qc/clean/<sample>_{1,2}.fq.gz
# 输出:
#   ${WORK_DIR}/assembly/per_sample/<sample>/final.contigs.fa   单样本组装
#   ${WORK_DIR}/assembly/coassembly/<asm_id>/final.contigs.fa   共组装(按组或全部)
#   ${RESULT_DIR}/assembly/<asm_id>.contigs.fa   过滤(>=GENE_MIN_CONTIG_LEN)+重命名
#   ${RESULT_DIR}/assembly/assembly.fa            合并后的全部 contigs(基因预测用)
#   ${WORK_DIR}/binning/<asm_id>.fa               过滤(>=BIN_MIN_CONTIG_LEN)供 binning
#   ${RESULT_DIR}/assembly/assembly.stats.tsv     各组装统计(seqkit)
#
# 逻辑:
#   ASSEMBLY_MODE=per-sample | co-assembly | both
#   提供 --group-file 时共组装按 group 分组；否则全部样本合并
#   contig 头统一重命名为 <asm_id>|原始头，保证跨组装唯一
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

SAMPLES_TSV="${WORK_DIR}/samples.tsv"
CLEAN_DIR="${WORK_DIR}/qc/clean"
ASSEMBLY_WORK="${WORK_DIR}/assembly"
RESULT_ASSEMBLY="${RESULT_DIR}/assembly"
BINNING_CONTIGS="${WORK_DIR}/binning"

[[ -s "${SAMPLES_TSV}" ]] || { echo "ERROR: ${SAMPLES_TSV} 不存在" >&2; exit 1; }
mkdir -p "${ASSEMBLY_WORK}/per_sample" "${ASSEMBLY_WORK}/coassembly" "${RESULT_ASSEMBLY}" "${BINNING_CONTIGS}"

source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_ASSEMBLY}" megahit seqkit

# ---- 读取样品 --------------------------------------------------------------
read_col() { awk -F '\t' -v c="$1" '!/^#/ && $1!="sample_id" && $1!="" {print $c}' "$2"; }
SAMPLES=(); while IFS= read -r l; do SAMPLES+=("$l"); done < <(read_col 1 "${SAMPLES_TSV}")
R1S=();     while IFS= read -r l; do R1S+=("$l");     done < <(read_col 2 "${SAMPLES_TSV}")
R2S=();     while IFS= read -r l; do R2S+=("$l");     done < <(read_col 3 "${SAMPLES_TSV}")
[[ "${#SAMPLES[@]}" -gt 0 ]] || { echo "ERROR: samples.tsv 没有样品" >&2; exit 1; }

# ---- 解析组装模式 ----------------------------------------------------------
case "${ASSEMBLY_MODE}" in
  per-sample|co-assembly|both) : ;;
  *) echo "ERROR: --assembly 必须是 per-sample|co-assembly|both (got: ${ASSEMBLY_MODE})" >&2; exit 1 ;;
esac

# 组装单条命令
run_megahit() {
  local outdir="$1" r1_list="$2" r2_list="$3"
  if [[ -s "${outdir}/final.contigs.fa" ]]; then
    echo "[skip] 组装已存在: ${outdir}"; return 0
  fi
  # megahit 要求输出目录不存在（它自己创建）；存在但无最终结果 = 上次中断残留，清掉重跑
  [[ -d "${outdir}" ]] && rm -rf "${outdir}"
  megahit -1 "${r1_list}" -2 "${r2_list}" -o "${outdir}" -t "${THREADS}" \
      --k-min "${MEGAHIT_K_MIN}" --k-max "${MEGAHIT_K_MAX}" --k-step "${MEGAHIT_K_STEP}" \
      --min-contig-len "${MEGAHIT_MIN_CONTIG_LEN}"
  # 清理 megahit 中间文件（保留 final.contigs.fa 与 log/options），避免大输入磁盘爆炸
  # 中间文件形如 k21.contigs.fa / k29.contigs.fa（以 k 开头）与 intermediate_contigs/
  if [[ -s "${outdir}/final.contigs.fa" ]]; then
    rm -rf "${outdir}/intermediate_contigs" "${outdir}"/k*.contigs.fa 2>/dev/null || true
    echo "    已清理 megahit 中间文件: ${outdir}"
  fi
}


# ---- 1. 单样本组装 ----------------------------------------------------------
if [[ "${ASSEMBLY_MODE}" == "per-sample" || "${ASSEMBLY_MODE}" == "both" ]]; then
  echo "==> 单样本组装（并行 ${CONCURRENT_JOBS}，每个 megahit ${THREADS} 线程；注意 THREADS*JOBS<=节点核数）"
  export CLEAN_DIR ASSEMBLY_WORK THREADS \
         MEGAHIT_K_MIN MEGAHIT_K_MAX MEGAHIT_K_STEP MEGAHIT_MIN_CONTIG_LEN
  run_pool "${CONCURRENT_JOBS}" "${PIPELINE_DIR}/bin/workers/02_megahit.sh" "${SAMPLES[@]}"
fi

# ---- 2. 共组装（按组或全部） -------------------------------------------------
if [[ "${ASSEMBLY_MODE}" == "co-assembly" || "${ASSEMBLY_MODE}" == "both" ]]; then
  echo "==> 共组装"
  G_SIDS=(); G_GIDS=(); GROUPED="no"
  if [[ -n "${GROUP_FILE:-}" && -s "${GROUP_FILE}" ]]; then
    while IFS=$'\t' read -r sid gid; do
      [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
      G_SIDS+=("${sid}"); G_GIDS+=("${gid:-coassembly}")
    done < "${GROUP_FILE}"
    # 校验分组文件覆盖所有样品
    for s in "${SAMPLES[@]}"; do
      hit="no"
      for k in "${!G_SIDS[@]}"; do [[ "${G_SIDS[$k]}" == "${s}" ]] && hit="yes"; done
      [[ "${hit}" == "yes" ]] || { echo "ERROR: ${s} 不在 group-file 中" >&2; exit 1; }
    done
    GROUP_IDS=()
    while IFS= read -r l; do GROUP_IDS+=("$l"); done < <(for k in "${!G_SIDS[@]}"; do echo "${G_GIDS[$k]}"; done | sort -u)
    GROUPED="yes"
  else
    GROUP_IDS=("coassembly")
  fi

  sample_group() {  # 输出样品所在组（无分组文件时全部归 coassembly）
    local s="$1" k
    if [[ "${GROUPED}" == "yes" ]]; then
      for k in "${!G_SIDS[@]}"; do
        [[ "${G_SIDS[$k]}" == "${s}" ]] && { echo "${G_GIDS[$k]}"; return; }
      done
    fi
    echo "coassembly"
  }

  for g in "${GROUP_IDS[@]}"; do
    # 组名清洗成安全文件名
    asm_id="$(printf '%s' "${g}" | tr -c 'A-Za-z0-9._-' '_')"
    r1_list=""; r2_list=""; ngroup=0
    for i in "${!SAMPLES[@]}"; do
      [[ "$(sample_group "${SAMPLES[$i]}")" == "${g}" ]] || continue
      ngroup=$((ngroup+1))
      r1_list+="${CLEAN_DIR}/${SAMPLES[$i]}_1.fq.gz,"
      r2_list+="${CLEAN_DIR}/${SAMPLES[$i]}_2.fq.gz,"
    done
    r1_list="${r1_list%,}"; r2_list="${r2_list%,}"
    echo "[run ] 共组装: ${asm_id} (${ngroup} 样本)"
    run_megahit "${ASSEMBLY_WORK}/coassembly/${asm_id}" "${r1_list}" "${r2_list}"
  done
fi

# ---- 3. 过滤 + 重命名 + 统计 ------------------------------------------------
echo "==> 过滤与重命名"
: > "${RESULT_ASSEMBLY}/assembly.stats.tsv"
printf 'asm_id\tfile\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len\n' > "${RESULT_ASSEMBLY}/assembly.stats.tsv"
: > "${RESULT_ASSEMBLY}/assemblies.list"
: > "${RESULT_ASSEMBLY}/assembly.fa"

collect_assembly() {
  local asm_id="$1" fa="$2"
  [[ -s "${fa}" ]] || { echo "WARN: ${asm_id} 组装文件为空: ${fa}"; return 0; }
  local filtered="${RESULT_ASSEMBLY}/${asm_id}.contigs.fa"
  local binfa="${BINNING_CONTIGS}/${asm_id}.fa"
  # 基因预测用：>= GENE_MIN_CONTIG_LEN，头重命名 <asm_id>|原始头
  seqkit seq -m "${GENE_MIN_CONTIG_LEN}" "${fa}" | \
      awk -v p="${asm_id}" '/^>/{print ">"p"|"substr($0,2); next}{print}' > "${filtered}"
  # binning 用：>= BIN_MIN_CONTIG_LEN
  seqkit seq -m "${BIN_MIN_CONTIG_LEN}" "${fa}" | \
      awk -v p="${asm_id}" '/^>/{print ">"p"|"substr($0,2); next}{print}' > "${binfa}"
  # 统计
  seqkit stat -T "${fa}" | tail -n +2 | \
      awk -F '\t' -v a="${asm_id}" -v f="${fa}" '{print a"\t"f"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6}' >> "${RESULT_ASSEMBLY}/assembly.stats.tsv"
  printf '%s\t%s\n' "${asm_id}" "${filtered}" >> "${RESULT_ASSEMBLY}/assemblies.list"
  cat "${filtered}" >> "${RESULT_ASSEMBLY}/assembly.fa"
}

if [[ "${ASSEMBLY_MODE}" == "per-sample" || "${ASSEMBLY_MODE}" == "both" ]]; then
  for s in "${SAMPLES[@]}"; do
    collect_assembly "${s}" "${ASSEMBLY_WORK}/per_sample/${s}/final.contigs.fa"
  done
fi
if [[ "${ASSEMBLY_MODE}" == "co-assembly" || "${ASSEMBLY_MODE}" == "both" ]]; then
  for g in "${GROUP_IDS[@]}"; do
    asm_id="$(printf '%s' "${g}" | tr -c 'A-Za-z0-9._-' '_')"
    collect_assembly "${asm_id}" "${ASSEMBLY_WORK}/coassembly/${asm_id}/final.contigs.fa"
  done
fi

# 注：不做序列级去重——contig 头已带 <asm_id>| 前缀（跨组装天然唯一），
# 且 rmdup 在 both 模式下会删掉跨组装序列相同的 contig，导致后续基因编号与
# 组装/比对结果错位（02 移除，2026-08）。

echo "02_assembly.sh 完成：${RESULT_ASSEMBLY}"
