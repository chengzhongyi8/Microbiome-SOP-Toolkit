#!/usr/bin/env bash
# Purpose: map metatranscriptome reads to reviewed gene/vOTU/AMG references and emit count, TPM, RPKM, breadth.
# Input: samples.tsv metat columns and references.tsv.
# Output: results/09_metatranscriptome/<reference>/<sample>.tsv.
# Software: CoverM.
# Resources: THREADS_PER_JOB CPUs; references and samples processed sequentially.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_COVERM}" "${COVERM}"
REFERENCES="${SCRIPT_DIR}/references.tsv"
while IFS=$'\t' read -r ref_name fasta ref_type; do
  [[ "${ref_name}" == "reference_name" || -z "${ref_name}" || "${ref_name}" == \#* ]] && continue
  [[ -s "${fasta}" ]] || { echo "ERROR: missing reference ${fasta}" >&2; exit 1; }
  OUT="${PROJECT_DIR}/results/09_metatranscriptome/${ref_name}"; mkdir -p "${OUT}"
  while IFS=$'\t' read -r sample group metag_r1 metag_r2 r1 r2; do
    [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
    [[ -n "${r1}" && -n "${r2}" ]] || continue
    "${COVERM}" contig -r "${fasta}" -t "${THREADS_PER_JOB}" --coupled "${r1}" "${r2}" \
      --min-read-percent-identity "${MIN_READ_IDENTITY}" --min-read-aligned-percent "${MIN_READ_ALIGNED_PERCENT}" \
      -m count covered_fraction mean rpkm tpm -o "${OUT}/${sample}.tsv"
  done < "${SAMPLES_TSV}"
done < "${REFERENCES}"
