#!/usr/bin/env bash
# Purpose: generate a concise human-readable summary of the finished pipeline:
#          sample count, read counts, ASV counts, taxonomy stats, DADA2 params,
#          and a map of result files.
# Input: results/ from all previous steps.
# Output: results/summary/summary_report.tsv, results/summary/README_summary.md,
#          results/README.md.
# Software: bash, awk, sort, wc.
# Resources: 1 CPU, low memory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"

OUT="${PROJECT_DIR}/results/summary"
mkdir -p "${OUT}"
REPORT="${OUT}/summary_report.tsv"
MD="${OUT}/README_summary.md"

# helper: printf 'metric\tvalue\n'
add() { printf '%s\t%s\n' "$1" "$2" >> "${REPORT}"; }

: > "${REPORT}"

# ---- project info ----------------------------------------------------------
add "project_dir" "${PROJECT_DIR}"
add "fastq_dir" "${FASTQ_DIR}"
add "sequencing_mode" "${SEQUENCING_MODE}"
add "region" "${REGION:-<not set>}"
add "forward_primer" "${FORWARD_PRIMER:-<not set>}"
add "reverse_primer" "${REVERSE_PRIMER:-<not set>}"
add "metadata_file" "${METADATA_FILE:-<auto>}"
add "classifier" "${CLASSIFIER:-<not set>}"
add "dada2_trim_left_f" "${TRIM_LEFT_F:-${TRIM_LEFT_F_AUTO:-}}"
add "dada2_trim_left_r" "${TRIM_LEFT_R:-${TRIM_LEFT_R_AUTO:-}}"
add "dada2_trunc_len_f" "${TRUNC_LEN_F:-${TRUNC_LEN_F_AUTO:-}}"
add "dada2_trunc_len_r" "${TRUNC_LEN_R:-${TRUNC_LEN_R_AUTO:-}}"
if [[ -n "${TRUNC_LEN_F_AUTO:-}" ]]; then
  add "dada2_params_source" "auto-estimated"
  add "dada2_auto_warning" "${AUTO_WARNING:-none}"
else
  add "dada2_params_source" "manual"
fi

# ---- sample and read counts ------------------------------------------------
MANIFEST="${PROJECT_DIR}/work/manifest.tsv"
if [[ -s "${MANIFEST}" ]]; then
  nsamp="$(awk -F '\t' 'NR>1 && $1 != "" {n++} END {print n+0}' "${MANIFEST}")"
  add "samples" "${nsamp}"
fi

COUNTS="${PROJECT_DIR}/results/qc/sample-sequence-counts.tsv"
total_reads=""
if [[ -s "${COUNTS}" ]]; then
  if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
    # DADA2 stats 按“配对”计；这里 input 也按配对（forward 条数）计，保持口径一致
    total_reads="$(awk -F '\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END {print s+0}' "${COUNTS}")"
    add "total_input_read_pairs" "${total_reads}"
  else
    total_reads="$(awk -F '\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END {print s+0}' "${COUNTS}")"
    add "total_input_reads" "${total_reads}"
  fi
fi

STATS="${PROJECT_DIR}/results/microeco_input/denoising-stats.tsv"
if [[ -s "${STATS}" ]]; then
  nonchimeric="$(awk -F '\t' 'NR==1 {for (i=1;i<=NF;i++) if ($i=="non-chimeric") col=i}
                   NR>1 && $1 !~ /^#/ && col {s+=$col} END {print s+0}' "${STATS}")"
  add "reads_passing_dada2_nonchimeric" "${nonchimeric}"
  if [[ -n "${total_reads}" && "${total_reads}" -gt 0 ]]; then
    pct="$(awk -v n="${nonchimeric}" -v t="${total_reads}" 'BEGIN {printf "%.1f", 100*n/t}')"
    add "nonchimeric_retention_pct" "${pct}"
  fi
fi

# ---- ASV / taxonomy stats --------------------------------------------------
TABLE="${PROJECT_DIR}/results/microeco_input/feature-table.tsv"
if [[ -s "${TABLE}" ]]; then
  asv="$(awk '!/^#/ && NF {n++} END {print n+0}' "${TABLE}")"
  add "asv_count" "${asv}"
fi

TAX="${PROJECT_DIR}/results/microeco_input/taxonomy.tsv"
if [[ -s "${TAX}" ]]; then
  classifiable="$(awk -F '\t' 'NR>1 && $2 !~ /Unassigned/ {n++} END {print n+0}' "${TAX}")"
  add "asv_classified" "${classifiable}"
fi

TREE="${PROJECT_DIR}/results/microeco_input/rooted-tree.nwk"
if [[ -s "${TREE}" ]]; then
  add "rooted_tree_present" "yes"
fi

# ---- markdown summary ------------------------------------------------------
{
  echo "# QIIME2 扩增子分析结果汇总"
  echo
  echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "## 核心指标"
  echo
  echo "| 指标 | 值 |"
  echo "|---|---|"
  while IFS=$'\t' read -r k v; do
    printf '| %s | %s |\n' "${k}" "${v}"
  done < "${REPORT}"
  echo
  echo "## 关键结果文件"
  echo
  echo "| 路径 | 说明 |"
  echo "|---|---|"
  echo "| \`${PROJECT_DIR}/results/qc/demux.qzv\` | 原始质量图（查看每条 reads 的质量与长度） |"
  echo "| \`${PROJECT_DIR}/results/qc/sample-sequence-counts.tsv\` | 每样本输入 reads 数 |"
  echo "| \`${PROJECT_DIR}/results/dada2/table.qzv\` | 去噪后特征表统计（用于选抽平深度） |"
  echo "| \`${PROJECT_DIR}/results/dada2/rep-seqs.qzv\` | 代表序列 |"
  echo "| \`${PROJECT_DIR}/results/dada2/stats.qzv\` | DADA2 去噪统计（输入/过滤/非嵌合） |"
  echo "| \`${PROJECT_DIR}/results/final/feature-table.qza\` | 最终 ASV 表（qza） |"
  echo "| \`${PROJECT_DIR}/results/final/rep-seqs.qza\` | 最终代表序列（qza） |"
  echo "| \`${PROJECT_DIR}/results/final/taxonomy.qza\` | 最终物种注释（qza） |"
  echo "| \`${PROJECT_DIR}/results/final/rooted-tree.qza\` | 最终有根树（qza） |"
  echo "| \`${PROJECT_DIR}/results/final/taxonomy.qzv\` | 物种注释可视化 |"
  echo "| \`${PROJECT_DIR}/results/microeco_input/\` | microeco/file2meco 五个直接输入 + TSV/FASTA/Newick 导出 |"
  if [[ -d "${PROJECT_DIR}/results/downstream" ]]; then
    echo "| \`${PROJECT_DIR}/results/downstream/\` | 可选下游（core metrics / rarefaction / barplot） |"
  fi
  echo
  echo "## 使用 microeco 读取"
  echo
  echo '```r'
  echo 'obj <- file2meco::qiime2meco('
  echo "  feature_table = \"${PROJECT_DIR}/results/microeco_input/feature-table.qza\","
  echo "  sample_table  = \"${PROJECT_DIR}/results/microeco_input/metadata.tsv\","
  echo "  taxonomy_table= \"${PROJECT_DIR}/results/microeco_input/taxonomy.qza\","
  echo "  phylo_tree    = \"${PROJECT_DIR}/results/microeco_input/rooted-tree.qza\","
  echo "  rep_fasta     = \"${PROJECT_DIR}/results/microeco_input/rep-seqs.qza\","
  echo "  auto_tidy     = TRUE"
  echo ')'
  echo '```'
  echo
  echo "## 注意"
  echo
  echo "- 自动估计的 DADA2 参数是建议值；正式分析前建议打开 demux.qzv 复核。"
  echo "- 若使用自动生成的 metadata（只有 sample_name 列），做组间比较前请替换为真实分组列。"
} > "${MD}"

# ---- results/README.md (result file map) -----------------------------------
{
  echo "# 运行结果目录说明"
  echo
  echo "- \`qc/\`：输入校验、manifest 校验、demux.qza/.qzv、每样本 reads 数。"
  echo "- \`dada2/\`：DADA2 去噪结果（table、rep-seqs、stats 及 qzv）。"
  echo "- \`taxonomy/\`：未过滤的物种注释。"
  echo "- \`final/\`：同步后的最终 feature-table/rep-seqs/taxonomy/tree（qza 与 qzv）。"
  echo "- \`microeco_input/\`：file2meco 可直接读取的五件套 + 文本导出 + 校验表。"
  echo "- \`downstream/\`：可选多样性模块输出（core metrics、alpha rarefaction、taxa barplot）。"
  echo "- \`summary/\`：本汇总报告。"
  echo "- \`software_versions.tsv\`：实际使用的软件版本记录。"
} > "${PROJECT_DIR}/results/README.md"

echo "Summary written: ${REPORT}"
echo "Summary markdown: ${MD}"
