#!/usr/bin/env bash
# ============================================================================
# 04_quant.sh — 基因定量
#
# 输入:  ${RESULT_DIR}/gene_catalog/catalog/gene_catalog.fna
#        ${WORK_DIR}/qc/clean/<sample>_{1,2}.fq.gz
# 输出:
#   QUANT_TOOL=salmon:
#     ${RESULT_DIR}/quant/gene.count.tsv   (NumReads 丰度矩阵)
#     ${RESULT_DIR}/quant/gene.TPM.tsv     (TPM 丰度矩阵)
#   QUANT_TOOL=bwa:
#     ${RESULT_DIR}/quant/gene.count.tsv
#     ${RESULT_DIR}/quant/gene.FPKM.tsv
#
# 注意:
#   - salmon 走 --meta 模式，双端 reads 计数为 fragments；
#   - bwa 路线先过滤 secondary/supplementary/unmapped(-F 0x904) 再 idxstats，
#     避免多比对 reads 重复计数；FPKM 按 reads 口径计算（近似 fragments）。
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
CATALOG="${RESULT_DIR}/gene_catalog/catalog/gene_catalog.fna"
QUANT_WORK="${WORK_DIR}/quant"
QUANT_RESULT="${RESULT_DIR}/quant"
MWORKER="${PIPELINE_DIR}/bin/workers"

[[ -s "${CATALOG}" ]] || { echo "ERROR: ${CATALOG} 不存在（先运行 03_gene_catalog）" >&2; exit 1; }
mkdir -p "${QUANT_RESULT}"

case "${QUANT_TOOL}" in
  salmon|bwa) : ;;
  *) echo "ERROR: --quant 必须是 salmon 或 bwa" >&2; exit 1 ;;
esac

read_samples() {
  while IFS= read -r l; do SAMPLES+=("$l"); done < <(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!="" {print $1}' "${SAMPLES_TSV}")
}

# ---- Salmon ----------------------------------------------------------------
if [[ "${QUANT_TOOL}" == "salmon" ]]; then
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_SALMON}"
  SALMON_BIN="$(resolve_tool SALMON)"
  mkdir -p "${QUANT_WORK}/salmon/quant"
  echo "==> salmon index (${SALMON_BIN})"
  if [[ ! -s "${QUANT_WORK}/salmon/index/versionInfo.json" ]]; then
    "${SALMON_BIN}" index -t "${CATALOG}" -i "${QUANT_WORK}/salmon/index" -p "${THREADS}" -k "${SALMON_K}"
  fi
  echo "==> salmon quant"
  SAMPLES=(); read_samples
  run_pool "${CONCURRENT_JOBS}" "${MWORKER}/04_salmon.sh" "${SAMPLES[@]}"

  echo "==> 合并丰度矩阵"
  quant_dirs=()
  for s in "${SAMPLES[@]}"; do quant_dirs+=("${QUANT_WORK}/salmon/quant/${s}"); done
  "${SALMON_BIN}" quantmerge --quants "${quant_dirs[@]}" --column NumReads -o "${QUANT_RESULT}/gene.count.tsv"
  "${SALMON_BIN}" quantmerge --quants "${quant_dirs[@]}" --column TPM       -o "${QUANT_RESULT}/gene.TPM.tsv"
  for f in "${QUANT_RESULT}/gene.count.tsv" "${QUANT_RESULT}/gene.TPM.tsv"; do
    sed '1 s/\.quant//g' "${f}" > "${f}.tmp" && mv -f "${f}.tmp" "${f}"
  done
fi

# ---- BWA + samtools --------------------------------------------------------
if [[ "${QUANT_TOOL}" == "bwa" ]]; then
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_BWA}"
  BWA_BIN="$(resolve_tool BWA)"
  SAMTOOLS_BIN="$(resolve_tool SAMTOOLS)"
  mkdir -p "${QUANT_WORK}/bwa/bam" "${QUANT_WORK}/bwa/idxstats"
  echo "==> bwa index (${BWA_BIN})"
  if [[ ! -s "${QUANT_WORK}/bwa/catalog.bwt" ]]; then
    "${BWA_BIN}" index -p "${QUANT_WORK}/bwa/catalog" "${CATALOG}"
  fi
  echo "==> bwa mem + samtools (过滤 secondary/supplementary/unmapped)"
  SAMPLES=(); read_samples
  run_pool "${CONCURRENT_JOBS}" "${MWORKER}/04_bwa.sh" "${SAMPLES[@]}"

  echo "==> 合并 count/FPKM 矩阵"
  run_py3 "${PIPELINE_DIR}/bin/bwa_counts_to_matrix.py" \
      --idxstats-dir "${QUANT_WORK}/bwa/idxstats" \
      --samples "$(printf '%s\n' "${SAMPLES[@]}")" \
      --output-prefix "${QUANT_RESULT}/gene"
fi

# ---- Contig 覆盖表（可选） ----------------------------------------------------
# 把 clean reads 用 bowtie2 回比到组装 contigs，samtools depth 计算平均覆盖深度，
# 输出 results/quant/contig.depth.tsv（contig_id<TAB>length<TAB>各样本平均深度）。
if [[ "${CONTIG_COVERAGE:-no}" == "yes" ]]; then
  echo "==> contig 覆盖深度表 (bowtie2 + samtools depth)"
  ASSEMBLY_FA="${RESULT_DIR}/assembly/assembly.fa"
  [[ -s "${ASSEMBLY_FA}" ]] || { echo "ERROR: contig 覆盖需要 ${ASSEMBLY_FA}（先运行 02_assembly）" >&2; exit 1; }
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_QC}" bowtie2
  CC_WORK="${WORK_DIR}/contig_cov"
  mkdir -p "${CC_WORK}"
  # 建组装索引（大组装 >4Gb 自动 --large-index，同宿主索引逻辑）
  if [[ ! -e "${CC_WORK}/assembly.1.bt2" && ! -e "${CC_WORK}/assembly.1.bt2l" ]]; then
    echo "  -> bowtie2-build 组装索引: ${ASSEMBLY_FA}"
    build_args=(--threads "${THREADS}")
    fa_bytes="$(stat -c %s "${ASSEMBLY_FA}" 2>/dev/null || stat -f %z "${ASSEMBLY_FA}" 2>/dev/null || echo 0)"
    if [[ "${fa_bytes}" -gt 4000000000 ]]; then
      echo "    检测到大组装(>4Gb)，自动加 --large-index"
      build_args+=(--large-index)
    fi
    bowtie2-build "${build_args[@]}" "${ASSEMBLY_FA}" "${CC_WORK}/assembly"
  fi
  echo "  -> 回比 reads 并计算深度"
  SAMPLES=(); read_samples
  run_pool "${CONCURRENT_JOBS}" "${MWORKER}/04_contig_cov.sh" "${SAMPLES[@]}"
  echo "==> 合并 contig 覆盖矩阵"
  run_py3 "${PIPELINE_DIR}/bin/contig_coverage.py" \
      --depth-dir "${CC_WORK}" \
      --samples "$(printf '%s\n' "${SAMPLES[@]}")" \
      --output "${QUANT_RESULT}/contig.depth.tsv"
fi

echo "04_quant.sh 完成：${QUANT_RESULT}"
