#!/usr/bin/env bash
# 端到端 dry-run：用 stub 工具把整条 SOP 跑通（不装任何生信软件）。
# 验证：模块串联、resume 标记、generated.env、环境激活、Python 辅助脚本。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPE="$(cd "${HERE}/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# ---- 准备输入 ---------------------------------------------------------------
mkdir -p "${TMP}/fastq" "${TMP}/proj" "${TMP}/host"
for s in S1 S2; do
  printf '@%s/1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "${s}" | gzip > "${TMP}/fastq/${s}_1.fq.gz"
  printf '@%s/2\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "${s}" | gzip > "${TMP}/fastq/${s}_2.fq.gz"
done
# 第三个样本用“非压缩 + 点分R1”命名，验证兼容性
printf '@P1/1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' > "${TMP}/fastq/P1.R1.fq"
printf '@P1/2\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' > "${TMP}/fastq/P1.R2.fq"
# 宿主索引（stub）
: > "${TMP}/host/soybean.1.bt2"
: > "${TMP}/host/soybean.2.bt2"
# 假 conda.sh
cat > "${TMP}/conda.sh" <<'CONDA'
conda() {
  if [[ "${1:-}" == "activate" ]]; then export CONDA_DEFAULT_ENV="${2:-}"; fi
}
CONDA
# 假数据库（只用于通过存在性校验）
mkdir -p "${TMP}/db/eggnog5" "${TMP}/db/checkm2" "${TMP}/db/kegg" \
         "${TMP}/db/gtdbtk" "${TMP}/db/kofam/profiles"
printf "x\n" > "${TMP}/db/nr.dmnd"
printf "x\n" > "${TMP}/db/megan.map"
printf "x\n" > "${TMP}/db/gtdbtk/placeholder"
printf "x\n" > "${TMP}/db/checkm2/uniref100.KO.1.dmnd"
printf "K00001\tTIGR00001\t1\n" > "${TMP}/db/kofam/ko_list"
# dummy KEGG 定义（stub emapper 输出 ko:K00001）
printf 'M00001\tK00001\n' > "${TMP}/db/kegg/module.ko"
printf 'M00001\tTest module\n' > "${TMP}/db/kegg/module"
printf 'C    00010 Test pathway [PATH:ko00010]\nD      K00001  HK [EC:2.7.1.1]\n' > "${TMP}/db/kegg/ko00001.keg"

# ---- 跑整条流程 -------------------------------------------------------------
export PATH="${PIPE}/tests/stub_bin:${PATH}"
bash "${PIPE}/run_mg_sop.sh" \
  --project-dir "${TMP}/proj" \
  --fastq-dir "${TMP}/fastq" \
  --conda-sh "${TMP}/conda.sh" \
  --qc-needed no \
  --host-genome "${TMP}/host/soybean" \
  --assembly per-sample \
  --cluster mmseqs2 \
  --quant salmon \
  --contig-coverage yes \
  --taxonomy nr-megan \
  --function eggnog \
  --binning metawrap \
  --nr-db "${TMP}/db/nr.dmnd" \
  --megan-map "${TMP}/db/megan.map" \
  --eggnog-db "${TMP}/db/eggnog5" \
  --checkm2-db "${TMP}/db/checkm2" \
  --mag-annotate yes \
  --mag-quant yes \
  --mag-quant-methods "rpkm tpm" \
  --mag-filter yes \
  --mag-min-completeness 50 --mag-max-contamination 10 \
  --kegg-module-def "${TMP}/db/kegg/module.ko" \
  --kegg-module-name "${TMP}/db/kegg/module" \
  --kegg-pathway-def "${TMP}/db/kegg/ko00001.keg" \
  --gtdbtk-db "${TMP}/db/gtdbtk" \
  --gtdbtk-pplacer-cpus 1 \
  --kofam-profile "${TMP}/db/kofam/profiles" \
  --kofam-ko-list "${TMP}/db/kofam/ko_list" \
  --threads 2 --jobs 2 \
  --memory-gb 8

# ---- 校验 -------------------------------------------------------------------
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

ns=$(grep -vc '^sample_id' "${TMP}/proj/work/samples.tsv" || true)
[[ "${ns}" == "3" ]] && ok "样品发现 3 个（含非压缩 .R1.fq）" || fail "样品数: ${ns}"
nr=$(grep -vc '^sample' "${TMP}/proj/results/qc/read_counts.tsv" || true)
[[ "${nr}" == "3" ]] && ok "read_counts 包含全部 3 个样本（无静默丢失）" || fail "read_counts 样本数: ${nr}"
grep -q "Escherichia" "${TMP}/proj/results/taxonomy/Table_taxa_Species.tsv" \
  && ok "物种表解析出 Escherichia（真实分号格式）" \
  || fail "物种表未解析出物种（检查 lca 解析）"

for m in 01_qc_dehost 02_assembly 03_gene_catalog 04_quant 05_taxonomy 06_function 07_binning 08_mag_annotation; do
  [[ -f "${TMP}/proj/work/markers/${m}.ok" ]] && ok "marker ${m}.ok" || fail "marker ${m}.ok 缺失"
done
for f in \
  proj/results/qc/read_counts.tsv \
  proj/results/qc/host_removal_summary.txt \
  proj/results/assembly/assembly.fa \
  proj/results/assembly/assembly.stats.tsv \
  proj/results/gene_catalog/catalog/gene_catalog.fna \
  proj/results/gene_catalog/catalog/gene_catalog.faa \
  proj/results/quant/gene.count.tsv \
  proj/results/quant/gene.TPM.tsv \
  proj/results/quant/contig.depth.tsv \
  proj/results/taxonomy/Table_taxa_Species.tsv \
  proj/results/taxonomy/gene_taxonomy.tsv \
  proj/results/function/KO.tsv \
  proj/results/function/CAZy.tsv \
  proj/results/function/COG.tsv \
  proj/results/function/KEGG_module_completeness.tsv \
  proj/results/function/KEGG_pathway_completeness.tsv \
  proj/results/mags/MAG_list.txt \
  proj/results/mags/MAG_quality.tsv \
  proj/results/mags/MAG_quality.filtered.tsv \
  proj/results/mags/filtered_genomes/rep1.fa \
  proj/results/mags/abundance/MAG_abundance.tsv \
  proj/results/mags/annotations/gtdb/tax.bac120.summary.tsv \
  proj/results/mags/annotations/kofam_summary.tsv \
  proj/results/mags/annotations/kofam/kofam_merged.kofam_merged.tsv \
  proj/results/mags/annotations/kofam/kofam_merged.KO_bin_matrix.tsv \
  proj/results/mags/annotations/kofam/kofam_merged.KO_bin_matrix_besthit.tsv \
  proj/results/summary/README_summary.md \
  proj/results/summary/params.tsv \
  proj/results/software_versions.tsv \
  proj/logs/pipeline.log ; do
  [[ -s "${TMP}/${f}" ]] && ok "${f}" || fail "${f} 缺失或为空"
done
# 三款 binner 的 bin 都应进入 refined_bins（metabat2=.fa maxbin2=.fasta concoct=无前缀 .fa）
RB="${TMP}/proj/results/mags/refined_bins"
nm=$(ls "${RB}" 2>/dev/null | grep -c "\.metabat2\." || true)
nx=$(ls "${RB}" 2>/dev/null | grep -c "\.maxbin2\." || true)
nc=$(ls "${RB}" 2>/dev/null | grep -c "\.concoct\." || true)
[[ "${nm}" -ge 1 && "${nx}" -ge 1 && "${nc}" -ge 1 ]] \
  && ok "refined_bins 含三方法 (metabat2=${nm} maxbin2=${nx} concoct=${nc})" \
  || fail "refined_bins 方法缺失 (metabat2=${nm} maxbin2=${nx} concoct=${nc})"
# MAG 丰度矩阵应含 rpkm/tpm 列（--mag-quant-methods "rpkm tpm" 生效）
head -1 "${TMP}/proj/results/mags/abundance/MAG_abundance.tsv" | grep -q "\.rpkm" \
  && ok "MAG_abundance.tsv 含 .rpkm 列" || fail "MAG_abundance.tsv 缺 .rpkm 列"
head -1 "${TMP}/proj/results/mags/abundance/MAG_abundance.tsv" | grep -q "\.tpm" \
  && ok "MAG_abundance.tsv 含 .tpm 列" || fail "MAG_abundance.tsv 缺 .tpm 列"
# resume：再跑一次应全部 skip（marker 不重新生成但流程正常退出）
before=$(stat -f %m "${TMP}/proj/work/markers/07_binning.ok")
bash "${PIPE}/run_mg_sop.sh" \
  --project-dir "${TMP}/proj" --fastq-dir "${TMP}/fastq" --conda-sh "${TMP}/conda.sh" \
  --qc-needed no --host-genome "${TMP}/host/soybean" \
  --binning metawrap \
  --nr-db "${TMP}/db/nr.dmnd" --megan-map "${TMP}/db/megan.map" \
  --eggnog-db "${TMP}/db/eggnog5" --checkm2-db "${TMP}/db/checkm2" \
  --kegg-module-def "${TMP}/db/kegg/module.ko" \
  --kegg-module-name "${TMP}/db/kegg/module" \
  --kegg-pathway-def "${TMP}/db/kegg/ko00001.keg" \
  --threads 2 --jobs 2 --memory-gb 8 >/dev/null 2>&1
after=$(stat -f %m "${TMP}/proj/work/markers/07_binning.ok")
[[ "${before}" == "${after}" ]] && ok "resume 生效（marker 未重写）" || fail "resume 未生效"

echo
echo "=============================="
echo "E2E 结果: ${PASS} 通过, ${FAIL} 失败"
[[ "${FAIL}" -eq 0 ]]
