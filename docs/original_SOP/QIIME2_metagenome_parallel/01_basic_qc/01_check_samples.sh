#!/usr/bin/env bash
# Purpose: validate samples.tsv paths, unique IDs, paired files, and total resource contract.
# Input: config/samples.tsv and project/database configs.
# Output: results/01_basic_qc/sample_check.ok and normalized sample IDs.
# Software: bash, awk, gzip.
# Resources: 1 CPU, low memory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
source "${PIPELINE_DIR}/config/databases.sh"
for required_cmd in awk sort uniq gzip mkdir touch; do
  command -v "${required_cmd}" >/dev/null 2>&1 || { echo "ERROR: required command not found: ${required_cmd}" >&2; exit 1; }
done

[[ -s "${SAMPLES_TSV}" ]] || { echo "ERROR: samples.tsv not found" >&2; exit 1; }
[[ "${CONCURRENT_JOBS}" =~ ^[1-9][0-9]*$ && "${THREADS_PER_JOB}" =~ ^[1-9][0-9]*$ && "${TOTAL_THREADS}" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: thread settings must be positive integers" >&2; exit 1; }
requested=$((CONCURRENT_JOBS * THREADS_PER_JOB))
[[ "${requested}" -le "${TOTAL_THREADS}" ]] || { echo "ERROR: ${CONCURRENT_JOBS} jobs x ${THREADS_PER_JOB} threads = ${requested}, above TOTAL_THREADS=${TOTAL_THREADS}" >&2; exit 1; }

OUT="${PROJECT_DIR}/results/01_basic_qc"
mkdir -p "${OUT}"
awk -F '\t' 'NR>1 && $1 !~ /^#/ && $1 != "" {print $1}' "${SAMPLES_TSV}" | sort > "${OUT}/sample_ids.txt"
duplicates="$(uniq -d "${OUT}/sample_ids.txt")"
[[ -z "${duplicates}" ]] || { printf 'ERROR: duplicate sample IDs:\n%s\n' "${duplicates}" >&2; exit 1; }

while IFS=$'\t' read -r sample group metag_r1 metag_r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  [[ "${sample}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "ERROR: unsafe sample ID: ${sample}" >&2; exit 1; }
  [[ -s "${metag_r1}" && -s "${metag_r2}" ]] || { echo "ERROR: missing metagenome pair for ${sample}" >&2; exit 1; }
  gzip -t "${metag_r1}"
  gzip -t "${metag_r2}"
  if [[ -n "${metat_r1}" || -n "${metat_r2}" ]]; then
    [[ -s "${metat_r1}" && -s "${metat_r2}" ]] || { echo "ERROR: incomplete metatranscriptome pair for ${sample}" >&2; exit 1; }
    gzip -t "${metat_r1}"
    gzip -t "${metat_r2}"
  fi
done < "${SAMPLES_TSV}"
touch "${OUT}/sample_check.ok"
