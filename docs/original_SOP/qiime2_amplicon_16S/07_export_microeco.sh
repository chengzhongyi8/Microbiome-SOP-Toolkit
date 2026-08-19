#!/usr/bin/env bash
# Purpose: create file2meco inputs, plain-text exports, ID checks, and optional downstream QIIME2 summaries.
# Input: synchronized final QIIME2 artifacts and metadata.
# Output: results/microeco_input plus optional results/downstream.
# Software: QIIME2, BIOM, awk; optional R with file2meco and microeco.
# Resources: 1 CPU except optional QIIME2 downstream actions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${SCRIPT_DIR}/activate_qiime2.sh"
command -v biom >/dev/null 2>&1 || { echo "ERROR: ${QIIME2_ENV} 中未找到 biom 命令" >&2; exit 1; }
FINAL_DIR="${PROJECT_DIR}/results/final"
OUT="${PROJECT_DIR}/results/microeco_input"
TMP="${PROJECT_DIR}/work/microeco_export"
DOWNSTREAM="${PROJECT_DIR}/results/downstream"
mkdir -p "${OUT}" "${TMP}" "${DOWNSTREAM}"

for artifact in feature-table.qza taxonomy.qza rooted-tree.qza rep-seqs.qza; do
  [[ -s "${FINAL_DIR}/${artifact}" ]] || { echo "ERROR: missing ${FINAL_DIR}/${artifact}" >&2; exit 1; }
  cp "${FINAL_DIR}/${artifact}" "${OUT}/${artifact}"
  qiime tools peek "${OUT}/${artifact}"
done
cp "${METADATA_FILE}" "${OUT}/metadata.tsv"

qiime tools export --input-path "${OUT}/feature-table.qza" --output-path "${TMP}/table"
biom convert -i "${TMP}/table/feature-table.biom" -o "${OUT}/feature-table.tsv" --to-tsv
qiime tools export --input-path "${OUT}/taxonomy.qza" --output-path "${TMP}/taxonomy"
cp "${TMP}/taxonomy/taxonomy.tsv" "${OUT}/taxonomy.tsv"
qiime tools export --input-path "${OUT}/rooted-tree.qza" --output-path "${TMP}/tree"
cp "${TMP}/tree/tree.nwk" "${OUT}/rooted-tree.nwk"
qiime tools export --input-path "${OUT}/rep-seqs.qza" --output-path "${TMP}/rep_seqs"
cp "${TMP}/rep_seqs/dna-sequences.fasta" "${OUT}/rep-seqs.fasta"
qiime tools export --input-path "${PROJECT_DIR}/results/dada2/stats.qza" --output-path "${TMP}/stats"
cp "${TMP}/stats/stats.tsv" "${OUT}/denoising-stats.tsv"

awk -F '\t' 'BEGIN {OFS="\t"}
  /^# Constructed/ {next}
  /^#OTU ID/ {for (i=2; i<=NF; i++) sample[i]=$i; nsamp=NF-1; next}
  {for (i=2; i<=NF; i++) total[i]+=$i}
  END {print "sample-id","frequency"; for (i=2; i<=nsamp+1; i++) print sample[i],total[i]}' \
  "${OUT}/feature-table.tsv" > "${OUT}/sample-depth.tsv"

awk -F '\t' '!/^#/ && $1 != "" {print $1}' "${OUT}/feature-table.tsv" | sort -u > "${TMP}/table.ids"
awk '/^>/ {sub(/^>/, ""); sub(/[[:space:]].*$/, ""); print}' "${OUT}/rep-seqs.fasta" | sort -u > "${TMP}/seq.ids"
awk -F '\t' 'NR>1 {print $1}' "${OUT}/taxonomy.tsv" | sort -u > "${TMP}/tax.ids"
tr ':,();' '\n' < "${OUT}/rooted-tree.nwk" | awk 'NF {print $1}' | sort -u > "${TMP}/tree.tokens"
cmp "${TMP}/table.ids" "${TMP}/seq.ids" >/dev/null || { echo "ERROR: table and sequence ASV IDs differ" >&2; exit 1; }
cmp "${TMP}/table.ids" "${TMP}/tax.ids" >/dev/null || { echo "ERROR: table and taxonomy ASV IDs differ" >&2; exit 1; }
comm -23 "${TMP}/table.ids" "${TMP}/tree.tokens" > "${TMP}/tree.missing"
if [[ -s "${TMP}/tree.missing" ]]; then
  echo "ERROR: ASVs absent from tree:" >&2
  cat "${TMP}/tree.missing" >&2
  exit 1
fi

printf 'file\tstatus\n' > "${OUT}/file2meco_validation.tsv"
for file in feature-table.qza metadata.tsv taxonomy.qza rooted-tree.qza rep-seqs.qza; do
  printf '%s\tpresent-and-nonempty\n' "${file}" >> "${OUT}/file2meco_validation.tsv"
done

if [[ "${RUN_CORE_METRICS}" == "yes" ]]; then
  [[ -n "${SAMPLING_DEPTH}" ]] || { echo "ERROR: set SAMPLING_DEPTH" >&2; exit 1; }
  qiime diversity core-metrics-phylogenetic --i-phylogeny "${OUT}/rooted-tree.qza" \
    --i-table "${OUT}/feature-table.qza" --p-sampling-depth "${SAMPLING_DEPTH}" \
    --m-metadata-file "${OUT}/metadata.tsv" --output-dir "${DOWNSTREAM}/core-metrics"
fi
if [[ "${RUN_ALPHA_RAREFACTION}" == "yes" ]]; then
  [[ -n "${ALPHA_MAX_DEPTH}" ]] || { echo "ERROR: set ALPHA_MAX_DEPTH" >&2; exit 1; }
  qiime diversity alpha-rarefaction --i-table "${OUT}/feature-table.qza" \
    --i-phylogeny "${OUT}/rooted-tree.qza" --p-max-depth "${ALPHA_MAX_DEPTH}" \
    --m-metadata-file "${OUT}/metadata.tsv" --o-visualization "${DOWNSTREAM}/alpha-rarefaction.qzv"
fi
if [[ "${RUN_TAXA_BARPLOT}" == "yes" ]]; then
  qiime taxa barplot --i-table "${OUT}/feature-table.qza" --i-taxonomy "${OUT}/taxonomy.qza" \
    --m-metadata-file "${OUT}/metadata.tsv" --o-visualization "${DOWNSTREAM}/taxa-barplot.qzv"
fi

# Switch to the separate R environment only after every QIIME2 command has finished.
r_env_available="no"
if conda env list | awk -v env="${R_MICROECO_ENV}" 'NF && $1 !~ /^#/ && ($1==env || $NF==env) {found=1} END {exit !found}'; then
  r_env_available="yes"
fi
if [[ "${RUN_FILE2MECO_VALIDATION}" == "yes" || ("${RUN_FILE2MECO_VALIDATION}" == "auto" && "${r_env_available}" == "yes") ]]; then
  source "${SCRIPT_DIR}/activate_r_microeco.sh"
  Rscript -e 'x <- file2meco::qiime2meco(feature_table="'"${OUT}"'/feature-table.qza", sample_table="'"${OUT}"'/metadata.tsv", taxonomy_table="'"${OUT}"'/taxonomy.qza", phylo_tree="'"${OUT}"'/rooted-tree.qza", rep_fasta="'"${OUT}"'/rep-seqs.qza", auto_tidy=TRUE); stopifnot(inherits(x, "microtable")); saveRDS(x, "'"${OUT}"'/file2meco-smoke-test.rds")'
  printf 'file2meco-call\tpassed-in-%s\n' "${R_MICROECO_ENV}" >> "${OUT}/file2meco_validation.tsv"
elif [[ "${RUN_FILE2MECO_VALIDATION}" == "no" ]]; then
  printf 'file2meco-call\tskipped-by-config\n' >> "${OUT}/file2meco_validation.tsv"
else
  printf 'file2meco-call\tnot-run-env-%s-not-found\n' "${R_MICROECO_ENV}" >> "${OUT}/file2meco_validation.tsv"
fi
