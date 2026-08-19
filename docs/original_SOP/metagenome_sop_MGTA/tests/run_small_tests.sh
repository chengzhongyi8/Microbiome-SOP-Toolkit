#!/usr/bin/env bash
# 轻量本地测试：Python 辅助脚本 + run_mg_sop.sh --check-only
# 不需要安装任何生信软件。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPE="$(cd "${HERE}/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
PASS=0; FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# ============================================================================
echo "[test] bwa_counts_to_matrix.py"
mkdir -p "${TMP}/idx"
cat > "${TMP}/idx/s1.txt" <<'TSV'
Unigene1	1000	10	2
Unigene2	2000	20	3
*	0	5	0
TSV
cat > "${TMP}/idx/s2.txt" <<'TSV'
Unigene1	1000	5	1
Unigene2	2000	10	0
*	0	2	0
TSV
python3 "${PIPE}/bin/bwa_counts_to_matrix.py" \
    --idxstats-dir "${TMP}/idx" --output-prefix "${TMP}/gene" >/dev/null
c=$(awk -F'\t' 'NR==2{print $2","$3}' "${TMP}/gene.count.tsv")
f=$(awk -F'\t' 'NR==3{print $3}' "${TMP}/gene.FPKM.tsv")
[[ "${c}" == "10,5" ]] && ok "count 矩阵正确 (Unigene1: 10,5)" || fail "count 矩阵: got ${c}"
# Unigene2 FPKM in s2: 10*1e9/(2000*15)=333333.333333
[[ "${f}" == "333333.333333" ]] && ok "FPKM 矩阵正确 (Unigene2/s2)" || fail "FPKM: got ${f}"

# ============================================================================
echo "[test] taxonomy_abundance.py"
cat > "${TMP}/abd.tsv" <<'TSV'
gene_id	s1	s2
Unigene1	10	20
Unigene2	30	40
TSV
cat > "${TMP}/lca.tsv" <<'TSV'
Unigene1	d__Bacteria; 2; p__Proteobacteria; 1224; c__Gammaproteobacteria; 1236; o__Enterobacterales; 91347; f__Enterobacteriaceae; 543; g__Escherichia; 561; s__Escherichia coli; 562
Unigene2	unclassified
TSV
python3 "${PIPE}/bin/taxonomy_abundance.py" \
    --abundance "${TMP}/abd.tsv" --lca "${TMP}/lca.tsv" \
    --outdir "${TMP}/tax" --filter all >/dev/null
g=$(awk -F'\t' '$1=="Escherichia"{print $2","$3}' "${TMP}/tax/Table_taxa_Genus.tsv")
u=$(awk -F'\t' '$1=="Unclassified"{print $2","$3}' "${TMP}/tax/Table_taxa_Genus.tsv")
[[ "${g}" == "10,20" ]] && ok "属水平丰度正确 (Escherichia: 10,20)" || fail "属水平: got ${g}"
[[ "${u}" == "30,40" ]] && ok "Unclassified 丰度正确 (30,40)" || fail "Unclassified: got ${u}"
python3 "${PIPE}/bin/taxonomy_abundance.py" \
    --abundance "${TMP}/abd.tsv" --lca "${TMP}/lca.tsv" \
    --outdir "${TMP}/taxb" --filter bacteria >/dev/null
lines=$(wc -l < "${TMP}/taxb/Table_taxa_Genus.tsv" | tr -d " ")
[[ "${lines}" == "2" ]] && ok "bacteria 过滤生效（只留 Escherichia 行+表头）" || fail "bacteria 过滤: ${lines} 行"

# ============================================================================
echo "[test] summarize_eggnog.py"
cat > "${TMP}/ann.tsv" <<'TSV'
#query	seed_ortholog	evalue	score	taxonomic	protein	GOs	EC	KEGG_ko	KEGG_Pathway	KEGG_Module	KEGG_Reaction	KEGG_rclass	BRITE	KEGG_TC	CAZy	BiGG_Reaction	tax_scope	eggNOG_OGs	best_OG	COG_category	Description
Unigene1	12345	0.0	100	2	protein	-	-	ko:K00001,ko:K00002	-	-	-	-	-	-	GH5	-	2	COG0001	COG0001	G	Some function
Unigene2	12346	1e-10	80	2	protein	-	-	ko:K00001	-	-	-	-	-	-	-	-	2	COG0002	COG0002	E	Amino acid transport
TSV
python3 "${PIPE}/bin/summarize_eggnog.py" \
    --abundance "${TMP}/abd.tsv" --annotations "${TMP}/ann.tsv" \
    --outdir "${TMP}/fun" >/dev/null
ko=$(awk -F'\t' '$1=="K00001"{print $3","$4}' "${TMP}/fun/KO.tsv")
cazy=$(awk -F'\t' '$1=="GH5"{print $3","$4}' "${TMP}/fun/CAZy.tsv")
[[ "${ko}" == "40,60" ]] && ok "KO 丰度正确 (K00001: 40,60)" || fail "KO 丰度: got ${ko}"
[[ "${cazy}" == "10,20" ]] && ok "CAZy 丰度正确 (GH5: 10,20)" || fail "CAZy 丰度: got ${cazy}"

# ============================================================================
echo "[test] kegg_completeness.py"
cat > "${TMP}/kegg_ann.tsv" <<'TSV'
#query	seed_ortholog	evalue	score	taxonomic	protein	GOs	EC	KEGG_ko	KEGG_Pathway	KEGG_Module	KEGG_Reaction	KEGG_rclass	BRITE	KEGG_TC	CAZy	BiGG_Reaction	tax_scope	eggNOG_OGs	best_OG	COG_category	Description
Unigene1	12345	0.0	100	2	protein	-	-	ko:K00001	ko00010	M00001	-	-	-	-	-	-	2	COG0001	COG0001	G	Some function
Unigene2	12346	1e-10	80	2	protein	-	-	ko:K00002	ko00010	M00001	-	-	-	-	-	-	2	COG0002	COG0002	E	Amino acid transport
TSV
cat > "${TMP}/kegg_module.ko" <<'TSV'
M00001	K00001 K00002 K00003
M00002	K00004 K00005
TSV
cat > "${TMP}/kegg_module.name" <<'TSV'
M00001	Test module
TSV
cat > "${TMP}/kegg_pathway.keg" <<'TSV'
+D	KO
#<h2><a href="/kegg/brite.html"><img src="/Fig/bget/kegg3.gif" align="middle" border=0></a> &nbsp; KEGG Orthology (KO)</h2>
!
A09100 Metabolism
B
B  09101 Carbohydrate metabolism
C    00010 Glycolysis / Gluconeogenesis [PATH:ko00010]
D      K00001  HK; hexokinase [EC:2.7.1.1]
D      K00002  glk; glucokinase [EC:2.7.1.2]
D      K00003  glk; glucokinase [EC:2.7.1.2]
A09120 Xenobiotics
B
B  09121 Xenobiotics biodegradation
C    00620 Toluene degradation [PATH:ko00620]
D      K00004  foo [EC:1.1.1.1]
C    00000 Empty pathway [PATH:ko00000]
TSV
# 丰度：s1 只有 Unigene1，s2 只有 Unigene2
cat > "${TMP}/kegg_abd.tsv" <<'TSV'
gene_id	s1	s2
Unigene1	10	0
Unigene2	0	20
TSV
python3 "${PIPE}/bin/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_ann.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg" >/dev/null
m1=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg/KEGG_module_completeness.tsv")
p1=$(awk -F'\t' '$1=="ko00010"{print $5","$8}' "${TMP}/kegg/KEGG_pathway_completeness.tsv")
[[ "${m1}" == "0.333333,0.333333" ]] && ok "模块完整度正确 (M00001: 1/3, 1/3)" || fail "模块完整度: got ${m1}"
[[ "${p1}" == "0.333333,0.333333" ]] && ok "通路完整度正确 (ko00010: 1/3, 1/3)" || fail "通路完整度: got ${p1}"
npath=$(tail -n +2 "${TMP}/kegg/KEGG_pathway_completeness.tsv" | wc -l | tr -d ' ')
[[ "${npath}" == "2" ]] && ok "真实格式 ko00001.keg 解析出 2 条通路（HTML 残留与空通路被跳过）" || fail "通路数: ${npath}"
# 无定义文件 -> 检测表
python3 "${PIPE}/bin/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_ann.tsv" \
    --outdir "${TMP}/kegg2" >/dev/null
md=$(awk -F'\t' '$1=="M00001"{print $2","$3}' "${TMP}/kegg2/KEGG_module_detected.tsv")
[[ "${md}" == "1,1" ]] && ok "模块检测表正确 (M00001: 1,1)" || fail "模块检测表: got ${md}"

# ============================================================================
echo "[test] kegg_completeness.py 兼容老版 emapper 表头 (KEGG_KOs 复数)"
# 老版 eggNOG-mapper v1 表头：KEGG_KOs / KEGG_Pathways / KEGG_Modules（复数列名，位置也不同）
cat > "${TMP}/kegg_v1_ann.tsv" <<'TSV'
#query	seed_ortholog	evalue	score	tax_scope	protein	GOs	EC	KEGG_KOs	KEGG_Pathways	KEGG_Modules
Unigene1	12345	0.0	100	2	protein	-	-	ko:K00001,ko:K00002	ko00010	M00001
Unigene2	12346	1e-10	80	2	protein	-	-	ko:K00001	ko00010	M00001
TSV
python3 "${PIPE}/bin/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_v1_ann.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg_v1" >/dev/null
m1v1=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg_v1/KEGG_module_completeness.tsv")
[[ "${m1v1}" == "0.666667,0.333333" ]] && ok "v1 表头模块完整度正确 (M00001: s1=2/3, s2=1/3)" || fail "v1 模块完整度: got ${m1v1}"

# ============================================================================
echo "[test] kegg_completeness.py 无表头 + KEGG_ko 不在第9列（模拟老版 emapper --no_file_comments）"
cat > "${TMP}/kegg_noheader.tsv" <<'TSV'
Unigene1	12345	0.0	100	2	protein	-	-	-	G	foo	ko:K00001,ko:K00002	ko00010	M00001
Unigene2	12346	1e-10	80	2	protein	-	-	-	E	bar	ko:K00001	ko00010	M00001
TSV
python3 "${PIPE}/bin/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_noheader.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg_nh" >/dev/null
m1nh=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg_nh/KEGG_module_completeness.tsv")
[[ "${m1nh}" == "0.666667,0.333333" ]] && ok "无表头探测列位正确 (M00001: s1=2/3, s2=1/3)" || fail "无表头探测: got ${m1nh}"
# summarize_eggnog.py 同样验证
python3 "${PIPE}/bin/summarize_eggnog.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_noheader.tsv" \
    --outdir "${TMP}/sum_nh" >/dev/null
ko1=$(awk -F'\t' '$1=="K00001"{print $3","$4}' "${TMP}/sum_nh/KO.tsv")
[[ "${ko1}" == "10,20" ]] && ok "summarize 无表头探测 KO 正确 (K00001: 10,20)" || fail "summarize 探测: got ${ko1}"

# ============================================================================
echo "[test] summarize_eggnog.py 无表头含 COG/CAZy 列（模拟完整 v1 列结构）"
# 列：0 query,1 seed,2 evalue,3 score,4 tax,5 protein,6 GOs,7 EC,8 COG,9 Description,
#     10 KEGG_ko,11 KEGG_Pathway,12 KEGG_Module,13 CAZy
cat > "${TMP}/kegg_full.tsv" <<'TSV'
Unigene1	12345	0.0	100	2	protein	-	-	G	Some function	ko:K00001,ko:K00002	ko00010	M00001	GH5
Unigene2	12346	1e-10	80	2	protein	-	-	E	Amino acid transport	ko:K00001	ko00010	M00001	-
TSV
python3 "${PIPE}/bin/summarize_eggnog.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_full.tsv" \
    --outdir "${TMP}/sum_full" >/dev/null
cog1=$(awk -F'\t' '$1=="G"{print $3","$4}' "${TMP}/sum_full/COG.tsv")
cazy1=$(awk -F'\t' '$1=="GH5"{print $3","$4}' "${TMP}/sum_full/CAZy.tsv")
[[ "${cog1}" == "10,0" ]] && ok "COG 探测正确 (G: 10,0)" || fail "COG: got ${cog1}"
[[ "${cazy1}" == "10,0" ]] && ok "CAZy 探测正确 (GH5: 10,0)" || fail "CAZy: got ${cazy1}"

# ============================================================================
echo "[test] contig_coverage.py"
mkdir -p "${TMP}/cov"
printf 'c1	1000\nc2	2000\n' > "${TMP}/cov/s1.length.tsv"
printf 'c1	1000\nc2	2000\n' > "${TMP}/cov/s2.length.tsv"
printf 'c1	5000\n' > "${TMP}/cov/s1.depth.sum.tsv"
printf 'c1	1000\nc2	4000\n' > "${TMP}/cov/s2.depth.sum.tsv"
python3 "${PIPE}/bin/contig_coverage.py" \
    --depth-dir "${TMP}/cov" --samples "$(printf 's1\ns2\n')" \
    --output "${TMP}/cov/out.tsv" >/dev/null
c1=$(awk -F'\t' '$1=="c1"{print $3","$4}' "${TMP}/cov/out.tsv")
c2=$(awk -F'\t' '$1=="c2"{print $3","$4}' "${TMP}/cov/out.tsv")
[[ "${c1}" == "5.0000,1.0000" ]] && ok "contig c1 深度正确 (5,1)" || fail "c1 深度: got ${c1}"
[[ "${c2}" == "0.0000,2.0000" ]] && ok "contig c2 深度正确 (0,2，缺失样本记 0)" || fail "c2 深度: got ${c2}"

# ============================================================================
echo "[test] run_mg_sop.sh --check-only"
mkdir -p "${TMP}/fastq" "${TMP}/proj"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_1.fq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_2.fq.gz"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S2_1.fq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S2_2.fq.gz"
: > "${TMP}/fake_conda.sh"
bash "${PIPE}/run_mg_sop.sh" \
    --project-dir "${TMP}/proj" \
    --fastq-dir "${TMP}/fastq" \
    --conda-sh "${TMP}/fake_conda.sh" \
    --check-only >/dev/null 2>&1
n=$(grep -vc '^sample_id' "${TMP}/proj/work/samples.tsv" || true)
[[ "${n}" == "2" ]] && ok "样品发现正确 (2 个)" || fail "样品发现: ${n} 个"
[[ -s "${TMP}/proj/work/generated.env" ]] && ok "generated.env 已生成" || fail "generated.env 缺失"

# ============================================================================
echo
echo "=============================="
echo "结果: ${PASS} 通过, ${FAIL} 失败"
[[ "${FAIL}" -eq 0 ]]
