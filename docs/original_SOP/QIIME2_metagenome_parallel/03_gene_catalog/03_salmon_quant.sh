#!/usr/bin/env bash
# Purpose: index the non-redundant gene catalog and quantify every sample.
# Input: gene_catalog.fna and samples.tsv read pairs.
# Output: per-sample Salmon quant directories, merged count and TPM matrices.
# Software: Salmon.
# Resources: THREADS_PER_JOB CPUs; samples run sequentially to honor TOTAL_THREADS.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_SALMON}" "${SALMON}"
CATALOG="${PROJECT_DIR}/results/03_gene_catalog/catalog/gene_catalog.fna"
OUT="${PROJECT_DIR}/results/03_gene_catalog/salmon"; mkdir -p "${OUT}/quant"
[[ -d "${OUT}/index" ]] || "${SALMON}" index -t "${CATALOG}" -i "${OUT}/index" -p "${THREADS_PER_JOB}"
quant_dirs=()
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  "${SALMON}" quant -i "${OUT}/index" -l A -1 "${r1}" -2 "${r2}" --meta \
    --validateMappings -p "${THREADS_PER_JOB}" -o "${OUT}/quant/${sample}"
  quant_dirs+=("${OUT}/quant/${sample}")
done < "${SAMPLES_TSV}"
"${SALMON}" quantmerge --quants "${quant_dirs[@]}" --column NumReads -o "${OUT}/gene.count.tsv"
"${SALMON}" quantmerge --quants "${quant_dirs[@]}" --column TPM -o "${OUT}/gene.TPM.tsv"
