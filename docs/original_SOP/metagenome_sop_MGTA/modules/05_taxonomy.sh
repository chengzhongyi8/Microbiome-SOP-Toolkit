#!/usr/bin/env bash
# ============================================================================
# 05_taxonomy.sh — 物种注释
#
# 默认 nr-megan（基因层面，准确）:
#   diamond blastp vs NR -> blast2lca (MEGAN) -> python 合并丰度，输出各层级表
#   输出 ${RESULT_DIR}/taxonomy/Table_taxa_{Domain,Phylum,Class,Order,Family,Genus,Species}.tsv
#
# 预留 kraken2（reads 层面，快；服务器未配置时会明确报错）:
#   kraken2 --paired + 可选 bracken，输出每个样本 report
#
# TAXA_FILTER=all 保留所有 domain；bacteria 只保留细菌（PDF 里的旧行为）
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
PROT_FA="${RESULT_DIR}/gene_catalog/catalog/gene_catalog.faa"
# 丰度文件按定量工具选：salmon->TPM，bwa->FPKM
if [[ "${QUANT_TOOL:-salmon}" == "bwa" ]]; then
  ABUNDANCE="${RESULT_DIR}/quant/gene.FPKM.tsv"
else
  ABUNDANCE="${RESULT_DIR}/quant/gene.TPM.tsv"
fi
TAX_WORK="${WORK_DIR}/taxonomy"
TAX_RESULT="${RESULT_DIR}/taxonomy"

[[ -s "${PROT_FA}" ]] || { echo "ERROR: ${PROT_FA} 不存在（先运行 03_gene_catalog）" >&2; exit 1; }
[[ -s "${ABUNDANCE}" ]] || { echo "ERROR: 丰度文件不存在: ${ABUNDANCE}（先运行 04_quant）" >&2; exit 1; }
mkdir -p "${TAX_RESULT}"

case "${TAXONOMY_TOOL}" in
  nr-megan|kraken2|none) : ;;
  *) echo "ERROR: --taxonomy 必须是 nr-megan|kraken2|none" >&2; exit 1 ;;
esac

[[ "${TAXONOMY_TOOL}" == "none" ]] && { echo "物种注释已跳过 (--taxonomy none)"; exit 0; }

# ---- NR + MEGAN ------------------------------------------------------------
if [[ "${TAXONOMY_TOOL}" == "nr-megan" ]]; then
  [[ -s "${NR_DMND}" ]] || { echo "ERROR: NR diamond 数据库不存在: ${NR_DMND}（改 config.sh 或 --nr-db）" >&2; exit 1; }
  [[ -s "${MEGAN_MAP}" ]] || { echo "ERROR: MEGAN 映射文件不存在: ${MEGAN_MAP}（改 config.sh 或 --megan-map）" >&2; exit 1; }
  mkdir -p "${TAX_WORK}"

  echo "==> diamond blastp vs NR"
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_DIAMOND}" diamond
  if [[ ! -s "${TAX_WORK}/nr.blast.tsv" ]]; then
    diamond blastp --threads "${THREADS}" \
        -d "${NR_DMND}" -q "${PROT_FA}" \
        -o "${TAX_WORK}/nr.blast.tsv" \
        --max-target-seqs "${DIAMOND_MAX_TARGET_SEQS}" \
        --evalue "${DIAMOND_EVALUE}" \
        --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore
  fi

  echo "==> blast2lca (MEGAN)"
  # 优先用 config.sh 里的独立路径；不存在时回退到 PATH 里的 blast2lca
  BLAST2LCA_BIN="${BLAST2LCA:-}"
  if [[ ! -x "${BLAST2LCA_BIN}" ]]; then
    BLAST2LCA_BIN="$(command -v blast2lca 2>/dev/null || true)"
  fi
  [[ -n "${BLAST2LCA_BIN}" ]] || { echo "ERROR: 找不到 blast2lca（检查 config.sh 的 BLAST2LCA 或 PATH）" >&2; exit 1; }
  if [[ ! -s "${TAX_WORK}/lca.tsv" ]]; then
    "${BLAST2LCA_BIN}" -i "${TAX_WORK}/nr.blast.tsv" -f BlastTab \
        -ms "${MEGAN_MIN_SUPPORT}" -me "${MEGAN_MIN_EVALUE}" \
        -a2t "${MEGAN_MAP}" \
        -o "${TAX_WORK}/lca.tsv"
  fi

  [[ -s "${TAX_WORK}/lca.tsv" ]] || { echo "ERROR: blast2lca 没有输出（可能 NR 比对结果为空）" >&2; exit 1; }
  echo "==> 合并丰度，输出各层级物种表"
  run_py3 "${PIPELINE_DIR}/bin/taxonomy_abundance.py" \
      --abundance "${ABUNDANCE}" \
      --lca "${TAX_WORK}/lca.tsv" \
      --outdir "${TAX_RESULT}" \
      --filter "${TAXA_FILTER}"
fi

# ---- Kraken2（预留） --------------------------------------------------------
if [[ "${TAXONOMY_TOOL}" == "kraken2" ]]; then
  [[ -d "${KRAKEN2_DB}" ]] || { echo "ERROR: --taxonomy kraken2 需要配置 KRAKEN2_DB（服务器未安装/未配置时会在此报错）" >&2; exit 1; }
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_KRAKEN2}" kraken2
  mkdir -p "${TAX_RESULT}/kraken2"
  SAMPLES=(); while IFS= read -r l; do SAMPLES+=("$l"); done < <(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!="" {print $1}' "${SAMPLES_TSV}")
  for s in "${SAMPLES[@]}"; do
    [[ -s "${TAX_RESULT}/kraken2/${s}.report" ]] && { echo "[skip] ${s}"; continue; }
    echo "[run ] ${s} kraken2"
    kraken2 --db "${KRAKEN2_DB}" --paired --gzip-compressed \
        --threads "${THREADS}" \
        --report "${TAX_RESULT}/kraken2/${s}.report" \
        --output "${TAX_RESULT}/kraken2/${s}.kraken2" \
        "${CLEAN_DIR}/${s}_1.fq.gz" "${CLEAN_DIR}/${s}_2.fq.gz"
    if command -v bracken >/dev/null 2>&1; then
      bracken -d "${KRAKEN2_DB}" -i "${TAX_RESULT}/kraken2/${s}.report" \
          -o "${TAX_RESULT}/kraken2/${s}.bracken" -r 150 -l S 2>/dev/null || true
    fi
  done
fi

echo "05_taxonomy.sh 完成：${TAX_RESULT}"
