#!/usr/bin/env bash
# Purpose: annotate non-redundant gene catalog proteins with eggNOG orthology/functions.
# Input: gene_catalog.faa.
# Output: eggNOG mapper seed orthologs and annotations.
# Software/database: eggNOG-mapper and configured eggNOG data directory.
# Resources: THREADS_PER_JOB CPUs; large database/storage.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_ANNOTATION}" "${EMAPPER}"
[[ -d "${EGGNOG_DB}" ]] || { echo "ERROR: configure EGGNOG_DB" >&2; exit 1; }
IN="${PROJECT_DIR}/results/03_gene_catalog/catalog/gene_catalog.faa"
OUT="${PROJECT_DIR}/results/05_function_annotation/eggnog"; mkdir -p "${OUT}"
"${EMAPPER}" -m diamond --no_annot --no_file_comments --data_dir "${EGGNOG_DB}" \
  --cpu "${THREADS_PER_JOB}" -i "${IN}" --itype proteins -o catalog --output_dir "${OUT}"
"${EMAPPER}" -m no_search --annotate_hits_table "${OUT}/catalog.emapper.seed_orthologs" \
  --data_dir "${EGGNOG_DB}" --cpu "${THREADS_PER_JOB}" --no_file_comments \
  -o catalog_annotations --output_dir "${OUT}"
