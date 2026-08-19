#!/usr/bin/env bash
# End-to-end dry run of the metagenome workflow using stub tools.
#
# The stub binaries in tests/stub_bin emulate ~30 bioinformatics tools well
# enough that every module (01-08) runs its real code paths and produces the
# real output files, without installing any actual bioinformatics software.
#
# Verifies: module wiring, resume markers, generated.env, conda activation,
# the bundled Python helper scripts, and key result files.
#
#   bash tests/run_e2e_stub.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
DRIVER="${ROOT}/bin/run_metagenome.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# ---- prepare inputs ---------------------------------------------------------
mkdir -p "${TMP}/fastq" "${TMP}/proj" "${TMP}/host"
for s in S1 S2; do
  printf '@%s/1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "${s}" | gzip > "${TMP}/fastq/${s}_1.fq.gz"
  printf '@%s/2\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "${s}" | gzip > "${TMP}/fastq/${s}_2.fq.gz"
done
# third sample with uncompressed dot-R1 naming to exercise compatibility
printf '@P1/1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' > "${TMP}/fastq/P1.R1.fq"
printf '@P1/2\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' > "${TMP}/fastq/P1.R2.fq"
# host index (stub)
: > "${TMP}/host/soybean.1.bt2"
: > "${TMP}/host/soybean.2.bt2"
# fake conda.sh
cat > "${TMP}/conda.sh" <<'CONDA'
conda() {
  if [[ "${1:-}" == "activate" ]]; then export CONDA_DEFAULT_ENV="${2:-}"; fi
}
CONDA
# fake databases (only used to pass existence checks)
mkdir -p "${TMP}/db/eggnog5" "${TMP}/db/checkm2" "${TMP}/db/kegg" \
         "${TMP}/db/gtdbtk" "${TMP}/db/kofam/profiles"
printf "x\n" > "${TMP}/db/nr.dmnd"
printf "x\n" > "${TMP}/db/megan.map"
printf "x\n" > "${TMP}/db/gtdbtk/placeholder"
printf "x\n" > "${TMP}/db/checkm2/uniref100.KO.1.dmnd"
printf "K00001\tTIGR00001\t1\n" > "${TMP}/db/kofam/ko_list"
printf 'M00001\tK00001\n' > "${TMP}/db/kegg/module.ko"
printf 'M00001\tTest module\n' > "${TMP}/db/kegg/module"
printf 'C    00010 Test pathway [PATH:ko00010]\nD      K00001  HK [EC:2.7.1.1]\n' > "${TMP}/db/kegg/ko00001.keg"

# ---- run the whole pipeline ---------------------------------------------------
export PATH="${HERE}/stub_bin:${PATH}"
bash "${DRIVER}" \
  --project-dir "${TMP}/proj" \
  --input "${TMP}/fastq" \
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

# ---- assertions --------------------------------------------------------------
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

ns=$(grep -vc '^sample_id' "${TMP}/proj/work/samples.tsv" || true)
[[ "${ns}" == "3" ]] && ok "sample discovery = 3 (incl. uncompressed .R1.fq)" || fail "samples: ${ns}"
nr=$(grep -vc '^sample' "${TMP}/proj/results/qc/read_counts.tsv" || true)
[[ "${nr}" == "3" ]] && ok "read_counts has all 3 samples" || fail "read_counts samples: ${nr}"
grep -q "Escherichia" "${TMP}/proj/results/taxonomy/Table_taxa_Species.tsv" \
  && ok "species table parsed (real MEGAN semicolon format)" \
  || fail "species table missing taxonomy"

for m in 01_qc_dehost 02_assembly 03_gene_catalog 04_quant 05_taxonomy 06_function 07_binning 08_mag_annotation; do
  [[ -f "${TMP}/proj/work/markers/${m}.ok" ]] && ok "marker ${m}.ok" || fail "marker ${m}.ok missing"
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
  [[ -s "${TMP}/${f}" ]] && ok "${f}" || fail "${f} missing or empty"
done
# all three binners' bins must reach refined_bins
RB="${TMP}/proj/results/mags/refined_bins"
nm=$(ls "${RB}" 2>/dev/null | grep -c "\.metabat2\." || true)
nx=$(ls "${RB}" 2>/dev/null | grep -c "\.maxbin2\." || true)
nc=$(ls "${RB}" 2>/dev/null | grep -c "\.concoct\." || true)
[[ "${nm}" -ge 1 && "${nx}" -ge 1 && "${nc}" -ge 1 ]] \
  && ok "refined_bins has all 3 binner outputs (metabat2=${nm} maxbin2=${nx} concoct=${nc})" \
  || fail "refined_bins methods missing (metabat2=${nm} maxbin2=${nx} concoct=${nc})"
head -1 "${TMP}/proj/results/mags/abundance/MAG_abundance.tsv" | grep -q "\.rpkm" \
  && ok "MAG_abundance.tsv has .rpkm column" || fail "MAG_abundance.tsv missing .rpkm"
head -1 "${TMP}/proj/results/mags/abundance/MAG_abundance.tsv" | grep -q "\.tpm" \
  && ok "MAG_abundance.tsv has .tpm column" || fail "MAG_abundance.tsv missing .tpm"
# resume: second run must skip everything (marker mtime unchanged)
if stat -c %Y "${TMP}/proj/work/markers/07_binning.ok" >/dev/null 2>&1; then
  stat_cmd="stat -c %Y"
else
  stat_cmd="stat -f %m"
fi
before=$($stat_cmd "${TMP}/proj/work/markers/07_binning.ok")
bash "${DRIVER}" \
  --project-dir "${TMP}/proj" --input "${TMP}/fastq" --conda-sh "${TMP}/conda.sh" \
  --qc-needed no --host-genome "${TMP}/host/soybean" \
  --binning metawrap \
  --nr-db "${TMP}/db/nr.dmnd" --megan-map "${TMP}/db/megan.map" \
  --eggnog-db "${TMP}/db/eggnog5" --checkm2-db "${TMP}/db/checkm2" \
  --kegg-module-def "${TMP}/db/kegg/module.ko" \
  --kegg-module-name "${TMP}/db/kegg/module" \
  --kegg-pathway-def "${TMP}/db/kegg/ko00001.keg" \
  --threads 2 --jobs 2 --memory-gb 8 >/dev/null 2>&1
after=$($stat_cmd "${TMP}/proj/work/markers/07_binning.ok")
[[ "${before}" == "${after}" ]] && ok "resume works (marker not rewritten)" || fail "resume broken"

echo
echo "=============================="
echo "E2E result: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
