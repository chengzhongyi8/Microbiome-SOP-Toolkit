#!/usr/bin/env bash
# Purpose: classify ASVs, apply optional target/non-target filters, and synchronize table, sequences, taxonomy.
# Input: prevalence-filtered table/rep-seqs and classifier qza.
# Output: results/final/feature-table.qza, rep-seqs.qza, taxonomy.qza.
# Software: QIIME2 q2-feature-classifier, q2-taxa, q2-feature-table; awk.
# Resources: CLASSIFIER_JOBS CPUs; classifier-dependent memory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${SCRIPT_DIR}/activate_qiime2.sh"
DADA2_DIR="${PROJECT_DIR}/results/dada2"
TAX_DIR="${PROJECT_DIR}/results/taxonomy"
FINAL_DIR="${PROJECT_DIR}/results/final"
WORK_DIR="${PROJECT_DIR}/work/taxonomy_sync"
mkdir -p "${TAX_DIR}" "${FINAL_DIR}" "${WORK_DIR}"
# Resolve classifier explicitly or auto-discover it in CLASSIFIER_DIR.
if [[ -z "${CLASSIFIER}" && -n "${CLASSIFIER_DIR}" && -d "${CLASSIFIER_DIR}" ]]; then
  if [[ -n "${REGION}" && -f "${SCRIPT_DIR}/primers.tsv" ]]; then
    keywords="$(awk -F '\t' -v r="${REGION}" '!/^#/ {gsub(/[ _-]/, "", $1); gsub(/[ _-]/, "", r); if (toupper($1)==toupper(r)) {print $7; exit}}' "${SCRIPT_DIR}/primers.tsv")"
    if [[ -n "${keywords}" ]]; then
      IFS=',' read -r -a kws <<< "${keywords}"
      for kw in "${kws[@]}"; do
        [[ -n "${kw}" ]] || continue
        cand="$(find "${CLASSIFIER_DIR}" -maxdepth 1 -type f -name '*.qza' -iname "*${kw}*" | head -1)"
        if [[ -n "${cand}" ]]; then
          CLASSIFIER="${cand}"
          echo "Auto-picked classifier (region keyword '${kw}'): ${CLASSIFIER}"
          break
        fi
      done
    fi
  fi
  if [[ -z "${CLASSIFIER}" ]]; then
    n="$(find "${CLASSIFIER_DIR}" -maxdepth 1 -type f -name '*.qza' | wc -l | tr -d ' ')"
    if [[ "${n}" -eq 1 ]]; then
      CLASSIFIER="$(find "${CLASSIFIER_DIR}" -maxdepth 1 -type f -name '*.qza')"
      echo "Auto-picked the only classifier: ${CLASSIFIER}"
    elif [[ "${n}" -gt 1 ]]; then
      echo "ERROR: multiple classifiers in CLASSIFIER_DIR; set CLASSIFIER explicitly:" >&2
      find "${CLASSIFIER_DIR}" -maxdepth 1 -type f -name '*.qza' >&2
      exit 1
    fi
  fi
fi
[[ -s "${CLASSIFIER}" ]] || { echo "ERROR: classifier not found: ${CLASSIFIER}" >&2; exit 1; }

qiime feature-classifier classify-sklearn --i-classifier "${CLASSIFIER}" \
  --i-reads "${DADA2_DIR}/rep-seqs-prevalence.qza" --p-n-jobs "${CLASSIFIER_JOBS}" \
  --o-classification "${TAX_DIR}/taxonomy-unfiltered.qza"
qiime metadata tabulate --m-input-file "${TAX_DIR}/taxonomy-unfiltered.qza" \
  --o-visualization "${TAX_DIR}/taxonomy-unfiltered.qzv"

include_args=()
exclude_terms=()
[[ -n "${TARGET_DOMAIN}" ]] && include_args=(--p-include "${TARGET_DOMAIN}")
[[ "${EXCLUDE_MITOCHONDRIA}" == "yes" ]] && exclude_terms+=("mitochondria")
[[ "${EXCLUDE_CHLOROPLAST}" == "yes" ]] && exclude_terms+=("chloroplast")
[[ "${EXCLUDE_ARCHAEA}" == "yes" ]] && exclude_terms+=("Archaea")
[[ "${EXCLUDE_EUKARYOTA}" == "yes" ]] && exclude_terms+=("Eukaryota")
[[ "${EXCLUDE_UNASSIGNED_DOMAIN}" == "yes" ]] && exclude_terms+=("Unassigned")

filter_args=("${include_args[@]}")
if [[ "${#exclude_terms[@]}" -gt 0 ]]; then
  exclude_csv="$(IFS=,; echo "${exclude_terms[*]}")"
  filter_args+=(--p-exclude "${exclude_csv}")
fi

if [[ "${#filter_args[@]}" -gt 0 ]]; then
  qiime taxa filter-table --i-table "${DADA2_DIR}/table-prevalence.qza" \
    --i-taxonomy "${TAX_DIR}/taxonomy-unfiltered.qza" "${filter_args[@]}" \
    --o-filtered-table "${FINAL_DIR}/feature-table.qza"
  qiime taxa filter-seqs --i-sequences "${DADA2_DIR}/rep-seqs-prevalence.qza" \
    --i-taxonomy "${TAX_DIR}/taxonomy-unfiltered.qza" "${filter_args[@]}" \
    --o-filtered-sequences "${WORK_DIR}/rep-seqs-taxonomy-filtered.qza"
  qiime feature-table filter-seqs --i-data "${WORK_DIR}/rep-seqs-taxonomy-filtered.qza" \
    --i-table "${FINAL_DIR}/feature-table.qza" --o-filtered-data "${FINAL_DIR}/rep-seqs.qza"
else
  cp "${DADA2_DIR}/table-prevalence.qza" "${FINAL_DIR}/feature-table.qza"
  cp "${DADA2_DIR}/rep-seqs-prevalence.qza" "${FINAL_DIR}/rep-seqs.qza"
fi

# Re-import taxonomy with exactly the final ASV IDs. Confidence remains available in the unfiltered artifact/qzv.
qiime tools export --input-path "${FINAL_DIR}/rep-seqs.qza" --output-path "${WORK_DIR}/rep_export"
qiime tools export --input-path "${TAX_DIR}/taxonomy-unfiltered.qza" --output-path "${WORK_DIR}/tax_export"
awk '/^>/ {sub(/^>/, ""); sub(/[[:space:]].*$/, ""); print}' "${WORK_DIR}/rep_export/dna-sequences.fasta" \
  | sort -u > "${WORK_DIR}/final_asv_ids.txt"
awk -F '\t' 'BEGIN {OFS="\t"} NR==FNR {ids[$1]=1; next} FNR>1 && ($1 in ids) {print $1,$2}' \
  "${WORK_DIR}/final_asv_ids.txt" "${WORK_DIR}/tax_export/taxonomy.tsv" > "${WORK_DIR}/taxonomy-headerless.tsv"

expected="$(wc -l < "${WORK_DIR}/final_asv_ids.txt" | tr -d ' ')"
observed="$(wc -l < "${WORK_DIR}/taxonomy-headerless.tsv" | tr -d ' ')"
[[ "${expected}" -eq "${observed}" ]] || { echo "ERROR: taxonomy is missing final ASV IDs (${observed}/${expected})" >&2; exit 1; }
qiime tools import --type 'FeatureData[Taxonomy]' --input-format HeaderlessTSVTaxonomyFormat \
  --input-path "${WORK_DIR}/taxonomy-headerless.tsv" --output-path "${FINAL_DIR}/taxonomy.qza"
qiime metadata tabulate --m-input-file "${FINAL_DIR}/taxonomy.qza" --o-visualization "${FINAL_DIR}/taxonomy.qzv"
