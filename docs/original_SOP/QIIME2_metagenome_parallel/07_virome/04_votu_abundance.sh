#!/usr/bin/env bash
# Purpose: quantify vOTUs from metagenome reads with count, coverage breadth, RPKM and TPM outputs.
# Input: vOTU.fna and samples.tsv metagenome reads.
# Output: per-sample CoverM tables.
# Software: CoverM.
# Resources: THREADS_PER_JOB CPUs per sequential sample.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_COVERM}" "${COVERM}"
VOTU="${PROJECT_DIR}/results/07_virome/votu/vOTU.fna"; OUT="${PROJECT_DIR}/results/07_virome/abundance"; mkdir -p "${OUT}"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  "${COVERM}" contig -r "${VOTU}" -t "${THREADS_PER_JOB}" --coupled "${r1}" "${r2}" \
    --min-read-percent-identity "${MIN_READ_IDENTITY}" --min-read-aligned-percent "${MIN_READ_ALIGNED_PERCENT}" \
    -m count covered_fraction mean rpkm tpm -o "${OUT}/${sample}.tsv"
done < "${SAMPLES_TSV}"
