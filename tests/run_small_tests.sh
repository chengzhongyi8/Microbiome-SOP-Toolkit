#!/usr/bin/env bash
# Lightweight local tests for the metagenome workflow Python helpers and the
# metagenome driver --check-only.  No bioinformatics software is required.
#
#   bash tests/run_small_tests.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
BIN="${ROOT}/workflows/metagenome/bin"
DRIVER="${ROOT}/bin/run_metagenome.sh"
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
python3 "${BIN}/bwa_counts_to_matrix.py" \
    --idxstats-dir "${TMP}/idx" --output-prefix "${TMP}/gene" >/dev/null
c=$(awk -F'\t' 'NR==2{print $2","$3}' "${TMP}/gene.count.tsv")
f=$(awk -F'\t' 'NR==3{print $3}' "${TMP}/gene.FPKM.tsv")
[[ "${c}" == "10,5" ]] && ok "count matrix correct (Unigene1: 10,5)" || fail "count: got ${c}"
[[ "${f}" == "333333.333333" ]] && ok "FPKM matrix correct (Unigene2/s2)" || fail "FPKM: got ${f}"

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
python3 "${BIN}/taxonomy_abundance.py" \
    --abundance "${TMP}/abd.tsv" --lca "${TMP}/lca.tsv" \
    --outdir "${TMP}/tax" --filter all >/dev/null
g=$(awk -F'\t' '$1=="Escherichia"{print $2","$3}' "${TMP}/tax/Table_taxa_Genus.tsv")
u=$(awk -F'\t' '$1=="Unclassified"{print $2","$3}' "${TMP}/tax/Table_taxa_Genus.tsv")
[[ "${g}" == "10,20" ]] && ok "genus abundance correct (Escherichia: 10,20)" || fail "genus: got ${g}"
[[ "${u}" == "30,40" ]] && ok "Unclassified abundance correct (30,40)" || fail "Unclassified: got ${u}"
python3 "${BIN}/taxonomy_abundance.py" \
    --abundance "${TMP}/abd.tsv" --lca "${TMP}/lca.tsv" \
    --outdir "${TMP}/taxb" --filter bacteria >/dev/null
lines=$(wc -l < "${TMP}/taxb/Table_taxa_Genus.tsv" | tr -d " ")
[[ "${lines}" == "2" ]] && ok "bacteria filter works (2 lines)" || fail "bacteria filter: ${lines} lines"

# ============================================================================
echo "[test] summarize_eggnog.py"
cat > "${TMP}/ann.tsv" <<'TSV'
#query	seed_ortholog	evalue	score	taxonomic	protein	GOs	EC	KEGG_ko	KEGG_Pathway	KEGG_Module	KEGG_Reaction	KEGG_rclass	BRITE	KEGG_TC	CAZy	BiGG_Reaction	tax_scope	eggNOG_OGs	best_OG	COG_category	Description
Unigene1	12345	0.0	100	2	protein	-	-	ko:K00001,ko:K00002	-	-	-	-	-	-	GH5	-	2	COG0001	COG0001	G	Some function
Unigene2	12346	1e-10	80	2	protein	-	-	ko:K00001	-	-	-	-	-	-	-	-	2	COG0002	COG0002	E	Amino acid transport
TSV
python3 "${BIN}/summarize_eggnog.py" \
    --abundance "${TMP}/abd.tsv" --annotations "${TMP}/ann.tsv" \
    --outdir "${TMP}/fun" >/dev/null
ko=$(awk -F'\t' '$1=="K00001"{print $3","$4}' "${TMP}/fun/KO.tsv")
cazy=$(awk -F'\t' '$1=="GH5"{print $3","$4}' "${TMP}/fun/CAZy.tsv")
[[ "${ko}" == "40,60" ]] && ok "KO abundance correct (K00001: 40,60)" || fail "KO: got ${ko}"
[[ "${cazy}" == "10,20" ]] && ok "CAZy abundance correct (GH5: 10,20)" || fail "CAZy: got ${cazy}"

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
cat > "${TMP}/kegg_abd.tsv" <<'TSV'
gene_id	s1	s2
Unigene1	10	0
Unigene2	0	20
TSV
python3 "${BIN}/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_ann.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg" >/dev/null
m1=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg/KEGG_module_completeness.tsv")
p1=$(awk -F'\t' '$1=="ko00010"{print $5","$8}' "${TMP}/kegg/KEGG_pathway_completeness.tsv")
[[ "${m1}" == "0.333333,0.333333" ]] && ok "module completeness correct (M00001: 1/3,1/3)" || fail "module: got ${m1}"
[[ "${p1}" == "0.333333,0.333333" ]] && ok "pathway completeness correct (ko00010: 1/3,1/3)" || fail "pathway: got ${p1}"
npath=$(tail -n +2 "${TMP}/kegg/KEGG_pathway_completeness.tsv" | wc -l | tr -d ' ')
[[ "${npath}" == "2" ]] && ok "real ko00001.keg parsing yields 2 pathways" || fail "pathways: ${npath}"
python3 "${BIN}/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_ann.tsv" \
    --outdir "${TMP}/kegg2" >/dev/null
md=$(awk -F'\t' '$1=="M00001"{print $2","$3}' "${TMP}/kegg2/KEGG_module_detected.tsv")
[[ "${md}" == "1,1" ]] && ok "detection table correct (M00001: 1,1)" || fail "detection: got ${md}"

# ============================================================================
echo "[test] kegg_completeness.py legacy emapper v1 header"
cat > "${TMP}/kegg_v1_ann.tsv" <<'TSV'
#query	seed_ortholog	evalue	score	tax_scope	protein	GOs	EC	KEGG_KOs	KEGG_Pathways	KEGG_Modules
Unigene1	12345	0.0	100	2	protein	-	-	ko:K00001,ko:K00002	ko00010	M00001
Unigene2	12346	1e-10	80	2	protein	-	-	ko:K00001	ko00010	M00001
TSV
python3 "${BIN}/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_v1_ann.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg_v1" >/dev/null
m1v1=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg_v1/KEGG_module_completeness.tsv")
[[ "${m1v1}" == "0.666667,0.333333" ]] && ok "v1 header module completeness correct" || fail "v1 module: got ${m1v1}"

# ============================================================================
echo "[test] kegg_completeness.py no-header column probing"
cat > "${TMP}/kegg_noheader.tsv" <<'TSV'
Unigene1	12345	0.0	100	2	protein	-	-	-	G	foo	ko:K00001,ko:K00002	ko00010	M00001
Unigene2	12346	1e-10	80	2	protein	-	-	-	E	bar	ko:K00001	ko00010	M00001
TSV
python3 "${BIN}/kegg_completeness.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_noheader.tsv" \
    --module-def "${TMP}/kegg_module.ko" --module-name "${TMP}/kegg_module.name" \
    --pathway-def "${TMP}/kegg_pathway.keg" --outdir "${TMP}/kegg_nh" >/dev/null
m1nh=$(awk -F'\t' '$1=="M00001"{print $5","$8}' "${TMP}/kegg_nh/KEGG_module_completeness.tsv")
[[ "${m1nh}" == "0.666667,0.333333" ]] && ok "no-header probing correct" || fail "no-header: got ${m1nh}"
python3 "${BIN}/summarize_eggnog.py" \
    --abundance "${TMP}/kegg_abd.tsv" --annotations "${TMP}/kegg_noheader.tsv" \
    --outdir "${TMP}/sum_nh" >/dev/null
ko1=$(awk -F'\t' '$1=="K00001"{print $3","$4}' "${TMP}/sum_nh/KO.tsv")
[[ "${ko1}" == "10,20" ]] && ok "summarize no-header KO probing correct" || fail "summarize probing: got ${ko1}"

# ============================================================================
echo "[test] contig_coverage.py"
mkdir -p "${TMP}/cov"
printf 'c1\t1000\nc2\t2000\n' > "${TMP}/cov/s1.length.tsv"
printf 'c1\t1000\nc2\t2000\n' > "${TMP}/cov/s2.length.tsv"
printf 'c1\t5000\n' > "${TMP}/cov/s1.depth.sum.tsv"
printf 'c1\t1000\nc2\t4000\n' > "${TMP}/cov/s2.depth.sum.tsv"
python3 "${BIN}/contig_coverage.py" \
    --depth-dir "${TMP}/cov" --samples "$(printf 's1\ns2\n')" \
    --output "${TMP}/cov/out.tsv" >/dev/null
c1=$(awk -F'\t' '$1=="c1"{print $3","$4}' "${TMP}/cov/out.tsv")
c2=$(awk -F'\t' '$1=="c2"{print $3","$4}' "${TMP}/cov/out.tsv")
[[ "${c1}" == "5.0000,1.0000" ]] && ok "contig c1 depth correct (5,1)" || fail "c1 depth: got ${c1}"
[[ "${c2}" == "0.0000,2.0000" ]] && ok "contig c2 depth correct (0,2)" || fail "c2 depth: got ${c2}"

# ============================================================================
echo "[test] run_metagenome.sh --check-only"
mkdir -p "${TMP}/fastq" "${TMP}/proj"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_1.fq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_2.fq.gz"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S2_1.fq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S2_2.fq.gz"
: > "${TMP}/fake_conda.sh"
bash "${DRIVER}" \
    --project-dir "${TMP}/proj" \
    --input "${TMP}/fastq" \
    --conda-sh "${TMP}/fake_conda.sh" \
    --check-only >/dev/null 2>&1
n=$(grep -vc '^sample_id' "${TMP}/proj/work/samples.tsv" || true)
[[ "${n}" == "2" ]] && ok "sample discovery correct (2)" || fail "sample discovery: ${n}"
[[ -s "${TMP}/proj/work/generated.env" ]] && ok "generated.env written" || fail "generated.env missing"

# ============================================================================
echo "[test] yaml2env.py (16s + metagenome example configs)"
python3 "${ROOT}/bin/yaml2env.py" 16s "${ROOT}/config/16s_config.example.yaml" > "${TMP}/e16.env" 2>/dev/null
grep -q "export FASTQ_DIR=" "${TMP}/e16.env" && ok "16s yaml -> FASTQ_DIR" || fail "16s FASTQ_DIR missing"
grep -q "export TRIM_LEFT_F=" "${TMP}/e16.env" && ok "16s yaml -> TRIM_LEFT_F" || fail "16s TRIM_LEFT_F missing"
python3 "${ROOT}/bin/yaml2env.py" metagenome "${ROOT}/config/metagenome_config.example.yaml" > "${TMP}/emg.env" 2>/dev/null
grep -q "export PROJECT_DIR=" "${TMP}/emg.env" && ok "metagenome yaml -> PROJECT_DIR" || fail "mg PROJECT_DIR missing"
grep -q "export CHECKM2_DB=" "${TMP}/emg.env" && ok "metagenome yaml -> CHECKM2_DB" || fail "mg CHECKM2_DB missing"

echo
echo "=============================="
echo "result: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
