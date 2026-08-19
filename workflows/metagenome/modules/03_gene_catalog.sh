#!/usr/bin/env bash
# ============================================================================
# 03_gene_catalog.sh — 基因预测 + 非冗余基因集
#
# 输入:  ${RESULT_DIR}/assembly/assembly.fa
# 输出:
#   ${RESULT_DIR}/gene_catalog/prediction/{genes.fna,proteins.faa,genes.gff}
#   ${RESULT_DIR}/gene_catalog/catalog/gene_catalog.fna   (非冗余核酸基因集)
#   ${RESULT_DIR}/gene_catalog/catalog/gene_catalog.faa   (翻译后的蛋白)
#   ${RESULT_DIR}/gene_catalog/catalog.stats.tsv
#
# 逻辑:
#   prodigal -p meta (拆块并行) -> 重命名 UnigeneN -> 去冗余(mmseqs2 linclust 默认 / cd-hit-est)
#   -> seqkit translate 得到蛋白序列
#   注意: 只能按完整 FASTA record 拆块(seqkit split2)，禁止 split -l 按行切
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

IN_FA="${RESULT_DIR}/assembly/assembly.fa"
PRED_WORK="${WORK_DIR}/gene_catalog"
PRED_RESULT="${RESULT_DIR}/gene_catalog"

[[ -s "${IN_FA}" ]] || { echo "ERROR: ${IN_FA} 不存在（先运行 02_assembly）" >&2; exit 1; }
mkdir -p "${PRED_WORK}/split" "${PRED_RESULT}/prediction" "${PRED_RESULT}/catalog"

source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_GENE}" prodigal seqkit

# ---- 1. 拆块（按完整 record，安全）------------------------------------------
echo "==> 拆块 (seqkit split2, ${GENE_SPLIT_SEQS} 条/块)"
if [[ -z "$(ls -A "${PRED_WORK}/split" 2>/dev/null)" ]]; then
  seqkit split2 -s "${GENE_SPLIT_SEQS}" --out-dir "${PRED_WORK}/split" "${IN_FA}"
fi
CHUNKS=(); while IFS= read -r l; do CHUNKS+=("$l"); done < <(ls "${PRED_WORK}/split"/*.fa 2>/dev/null | sort)
[[ "${#CHUNKS[@]}" -gt 0 ]] || { echo "ERROR: 拆分后没有块文件" >&2; exit 1; }

# ---- 2. 并行 prodigal -------------------------------------------------------
echo "==> prodigal 基因预测 (${#CHUNKS[@]} 块, 并行 ${CONCURRENT_JOBS})"
run_pool "${CONCURRENT_JOBS}" "${PIPELINE_DIR}/bin/workers/03_prodigal.sh" "${CHUNKS[@]}"

# ---- 3. 合并 + 重命名 UnigeneN ----------------------------------------------
echo "==> 合并与重命名"
cat "${PRED_WORK}"/split/*.fna > "${PRED_WORK}/genes.raw.fna"
cat "${PRED_WORK}"/split/*.faa > "${PRED_WORK}/proteins.raw.faa"
cat "${PRED_WORK}"/split/*.gff > "${PRED_RESULT}/prediction/genes.gff"
[[ -s "${PRED_WORK}/genes.raw.fna" ]] || { echo "ERROR: prodigal 没有产出基因" >&2; exit 1; }

# 核酸与蛋白按相同顺序重命名，保证 ID 一一对应
awk '/^>/{n++; print ">Unigene"n; next}{print}' "${PRED_WORK}/genes.raw.fna" > "${PRED_RESULT}/prediction/genes.fna"
awk '/^>/{n++; print ">Unigene"n; next}{print}' "${PRED_WORK}/proteins.raw.faa" > "${PRED_RESULT}/prediction/proteins.faa"

N_GENES_RAW="$(grep -c '^>' "${PRED_RESULT}/prediction/genes.fna")"
echo "    预测基因数: ${N_GENES_RAW}"

# ---- 4. 非冗余基因集 --------------------------------------------------------
echo "==> 去冗余 (${GENE_CLUSTERER})"
CATALOG="${PRED_RESULT}/catalog/gene_catalog.fna"
if [[ "${GENE_CLUSTERER}" == "mmseqs2" ]]; then
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_CLUSTER_MMSEQS}" mmseqs
  mmseqs easy-linclust "${PRED_RESULT}/prediction/genes.fna" \
      "${PRED_WORK}/mmseqs_catalog" "${PRED_WORK}/mmseqs_tmp" \
      --min-seq-id "${GENE_MIN_IDENTITY}" -c "${GENE_MIN_COVERAGE}" --cov-mode 1 \
      --threads "${THREADS}"
  cp -f "${PRED_WORK}/mmseqs_catalog_rep_seq.fasta" "${CATALOG}"
elif [[ "${GENE_CLUSTERER}" == "cd-hit-est" ]]; then
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_CLUSTER_CDHIT}" cd-hit-est
  cd-hit-est -i "${PRED_RESULT}/prediction/genes.fna" -o "${CATALOG}" \
      -c "${GENE_MIN_IDENTITY}" -aS "${GENE_MIN_COVERAGE}" -G 0 -g 0 \
      -T "${THREADS}" -M 0
else
  echo "ERROR: --cluster 必须是 mmseqs2 或 cd-hit-est" >&2; exit 1
fi
[[ -s "${CATALOG}" ]] || { echo "ERROR: 非冗余基因集为空" >&2; exit 1; }

# ---- 5. 翻译蛋白 ------------------------------------------------------------
echo "==> 翻译蛋白 (seqkit translate --trim)"
seqkit translate --trim "${CATALOG}" > "${PRED_RESULT}/catalog/gene_catalog.faa"

# ---- 6. 统计 -----------------------------------------------------------------
N_CATALOG="$(grep -c '^>' "${CATALOG}")"
N_PROT="$(grep -c '^>' "${PRED_RESULT}/catalog/gene_catalog.faa")"
printf 'predicted_genes\t%d\ncatalog_genes\t%d\ncatalog_proteins\t%d\n' \
    "${N_GENES_RAW}" "${N_CATALOG}" "${N_PROT}" > "${PRED_RESULT}/catalog.stats.tsv"
cat "${PRED_RESULT}/catalog.stats.tsv"

echo "03_gene_catalog.sh 完成：${PRED_RESULT}"
