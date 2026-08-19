#!/usr/bin/env bash
# Purpose: validate configuration, FASTQ readability, metadata header, and tools.
# Input: config.sh (+ optional config.local.sh / work/*.env), FASTQ directory, metadata TSV.
# Output: results/qc/input_check.ok and a console report.
# Software: bash, find, gzip, awk; QIIME2 is checked but not run here.
# Resources: 1 CPU, low memory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${WORKFLOW_DIR}/config.sh"
[[ -f "${WORKFLOW_DIR}/config.local.sh" ]] && source "${WORKFLOW_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR:-}/work/config.local.sh" ]] && source "${PROJECT_DIR}/work/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"

for required_cmd in find gzip awk mkdir touch; do
  command -v "${required_cmd}" >/dev/null 2>&1 || { echo "ERROR: required command not found: ${required_cmd}" >&2; exit 1; }
done

[[ "${PROJECT_DIR}" == /* ]] || { echo "ERROR: PROJECT_DIR must be absolute" >&2; exit 1; }
[[ -d "${FASTQ_DIR}" ]] || { echo "ERROR: FASTQ_DIR not found: ${FASTQ_DIR}" >&2; exit 1; }
[[ "${SEQUENCING_MODE}" == "paired" || "${SEQUENCING_MODE}" == "single" ]] || { echo "ERROR: SEQUENCING_MODE must be paired or single" >&2; exit 1; }

for v in AUTO_TRUNC AUTO_PRIMER_TRIM AUTO_GENERATE_METADATA RESUME; do
  val="${!v:-}"
  if [[ -n "${val}" && "${val}" != "yes" && "${val}" != "no" ]]; then
    echo "ERROR: ${v} must be yes or no (got '${val}')" >&2
    exit 1
  fi
done

# metadata: either a real file, or auto-generation will happen in 01.
if [[ -n "${METADATA_FILE}" ]]; then
  [[ -s "${METADATA_FILE}" ]] || { echo "ERROR: metadata not found or empty: ${METADATA_FILE}" >&2; exit 1; }
  metadata_header="$(awk -F '\t' 'NR==1 {sub(/^#/, "", $1); print $1}' "${METADATA_FILE}")"
  [[ "${metadata_header}" == "SampleID" || "${metadata_header}" == "sample-id" || "${metadata_header}" == "sample_name" ]] || {
    echo "ERROR: metadata first column must be #SampleID, sample-id, or sample_name" >&2
    exit 1
  }
else
  if [[ "${AUTO_GENERATE_METADATA}" == "yes" ]]; then
    echo "NOTE: METADATA_FILE is empty; a minimal metadata will be generated from sample IDs in step 01."
  else
    echo "ERROR: METADATA_FILE is empty and AUTO_GENERATE_METADATA=no" >&2
    exit 1
  fi
fi

# Suffix arrays must stay aligned (R1[i] pairs with R2[i]).
if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
  [[ "${#R1_SUFFIXES[@]}" -eq "${#R2_SUFFIXES[@]}" ]] || {
    echo "ERROR: R1_SUFFIXES and R2_SUFFIXES arrays must have the same length" >&2
    exit 1
  }
fi

# Classifier is needed in stage 2; warn early instead of failing stage 1.
if [[ -z "${CLASSIFIER}" && -z "${CLASSIFIER_DIR}" ]]; then
  echo "WARNING: neither CLASSIFIER nor CLASSIFIER_DIR is set; step 05 will fail unless you configure one."
fi
# Primers: if REGION is set but primers empty, remind that setup_project.sh fills them.
if [[ -n "${REGION}" && -z "${FORWARD_PRIMER}" ]]; then
  echo "NOTE: REGION=${REGION} is set; primers will be resolved from primers.tsv (or override in config)."
fi
# DADA2 auto/manual consistency.
if [[ "${AUTO_TRUNC}" != "yes" && ( -z "${TRIM_LEFT_F}" || -z "${TRUNC_LEN_F}" ) ]]; then
  echo "ERROR: AUTO_TRUNC=no requires TRIM_LEFT_F and TRUNC_LEN_F to be filled manually" >&2
  exit 1
fi

mkdir -p "${PROJECT_DIR}/results/qc" "${PROJECT_DIR}/work"

fastq_count=0
while IFS= read -r -d '' fastq; do
  if [[ "${CHECK_GZIP_INTEGRITY}" == "yes" ]]; then
    gzip -t "${fastq}" || { echo "ERROR: gzip integrity check failed for ${fastq}" >&2; exit 1; }
  fi
  fastq_count=$((fastq_count + 1))
done < <(find "${FASTQ_DIR}" -maxdepth 1 -type f \( -name '*.fastq.gz' -o -name '*.fq.gz' \) -print0)

[[ "${fastq_count}" -gt 0 ]] || { echo "ERROR: no .fastq.gz/.fq.gz files found" >&2; exit 1; }
printf 'FASTQ files checked: %s\nMode: %s\nMetadata: %s\n' "${fastq_count}" "${SEQUENCING_MODE}" "${METADATA_FILE:-<auto>}"
touch "${PROJECT_DIR}/results/qc/input_check.ok"
