#!/usr/bin/env bash
# Purpose: count paired input reads without hard-coded sample names.
# Input: metag paths in samples.tsv.
# Output: results/01_basic_qc/read_counts.tsv.
# Software: seqkit.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_SEQKIT}" "${SEQKIT}"
OUT="${PROJECT_DIR}/results/01_basic_qc"; mkdir -p "${OUT}"
printf 'sample_id\tread1_records\tread2_records\n' > "${OUT}/read_counts.tsv"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  n1="$(${SEQKIT} stats -T -j "${THREADS_PER_JOB}" "${r1}" | awk 'NR==2 {print $4}')"
  n2="$(${SEQKIT} stats -T -j "${THREADS_PER_JOB}" "${r2}" | awk 'NR==2 {print $4}')"
  [[ "${n1}" == "${n2}" ]] || { echo "ERROR: paired read counts differ for ${sample}" >&2; exit 1; }
  printf '%s\t%s\t%s\n' "${sample}" "${n1}" "${n2}" >> "${OUT}/read_counts.tsv"
done < "${SAMPLES_TSV}"
