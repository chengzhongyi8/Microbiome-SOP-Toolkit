#!/usr/bin/env bash
# Purpose: construct a non-redundant nucleotide gene catalog.
# Input: predicted genes.fna.
# Output: representative nucleotide catalog and translated proteins.
# Software: MMseqs2 (recommended large-data option) or CD-HIT-EST; seqkit.
# Resources: THREADS_PER_JOB CPUs; temporary storage can exceed input size.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
IN="${PROJECT_DIR}/results/03_gene_catalog/prediction/genes.fna"
OUT="${PROJECT_DIR}/results/03_gene_catalog/catalog"; mkdir -p "${OUT}"
if [[ "${GENE_CLUSTERER}" == "mmseqs2" ]]; then
  source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_CLUSTER_MMSEQS}" "${MMSEQS}"
  "${MMSEQS}" easy-linclust "${IN}" "${OUT}/genes" "${OUT}/mmseqs_tmp" \
    --min-seq-id "${GENE_MIN_IDENTITY}" -c "${GENE_MIN_COVERAGE}" --cov-mode 1 \
    --threads "${THREADS_PER_JOB}"
  cp "${OUT}/genes_rep_seq.fasta" "${OUT}/gene_catalog.fna"
elif [[ "${GENE_CLUSTERER}" == "cd-hit-est" ]]; then
  source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_CLUSTER_CDHIT}" "${CD_HIT_EST}"
  "${CD_HIT_EST}" -i "${IN}" -o "${OUT}/gene_catalog.fna" -c "${GENE_MIN_IDENTITY}" \
    -aS "${GENE_MIN_COVERAGE}" -G 0 -g 0 -T "${THREADS_PER_JOB}" -M 0
else
  echo "ERROR: GENE_CLUSTERER must be mmseqs2 or cd-hit-est" >&2; exit 1
fi
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_SEQKIT}" "${SEQKIT}"
"${SEQKIT}" translate --trim "${OUT}/gene_catalog.fna" > "${OUT}/gene_catalog.faa"
