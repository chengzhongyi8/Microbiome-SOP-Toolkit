#!/usr/bin/env bash
# Purpose: discover FASTQ files, build a QIIME2 manifest, compare sample IDs with
#          metadata, and (optionally) auto-generate a minimal metadata file.
# Input: config.sh (+ config.local.sh), gzipped FASTQ files, optional metadata TSV.
# Output: work/manifest.tsv, work/generated.env, QC ID lists.
# Software: bash, find, sort, awk, comm, grep.
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

for required_cmd in find sort awk comm uniq basename grep; do
  command -v "${required_cmd}" >/dev/null 2>&1 || { echo "ERROR: required command not found: ${required_cmd}" >&2; exit 1; }
done
MANIFEST="${PROJECT_DIR}/work/manifest.tsv"
QC_DIR="${PROJECT_DIR}/results/qc"
mkdir -p "${PROJECT_DIR}/work" "${QC_DIR}"

if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
  printf 'sample-id\tforward-absolute-filepath\treverse-absolute-filepath\n' > "${MANIFEST}"
  found=0
  while IFS= read -r -d '' r1; do
    name="$(basename "${r1}")"
    sample=""
    r2=""
    for i in "${!R1_SUFFIXES[@]}"; do
      if [[ "${name}" == *"${R1_SUFFIXES[$i]}" ]]; then
        sample="${name%${R1_SUFFIXES[$i]}}"
        r2="${FASTQ_DIR}/${sample}${R2_SUFFIXES[$i]}"
        break
      fi
    done
    [[ -n "${sample}" ]] || continue
    [[ -f "${r2}" ]] || { echo "ERROR: missing R2 for ${r1}; expected ${r2}" >&2; exit 1; }
    printf '%s\t%s\t%s\n' "${sample}" "${r1}" "${r2}" >> "${MANIFEST}"
    found=$((found + 1))
  done < <(find "${FASTQ_DIR}" -maxdepth 1 -type f \( -name '*_R1.fastq.gz' -o -name '*_R1.fq.gz' -o -name '*.R1.fastq.gz' -o -name '*.R1.fq.gz' -o -name '*_1.fastq.gz' -o -name '*_1.fq.gz' \) -print0 | sort -z)
  [[ "${found}" -gt 0 ]] || { echo "ERROR: no R1 files matched configured suffixes" >&2; exit 1; }

  # Orphan-R2 detection: every R2 file must have a matching R1 (already in manifest).
  r2_count=0
  r2_find_args=()
  for i in "${!R2_SUFFIXES[@]}"; do
    r2_find_args+=(-o -name "*${R2_SUFFIXES[$i]}")
  done
  unset 'r2_find_args[0]'
  while IFS= read -r -d '' _r2; do
    r2_count=$((r2_count + 1))
  done < <(find "${FASTQ_DIR}" -maxdepth 1 -type f \( "${r2_find_args[@]}" \) -print0)
  if [[ "${r2_count}" -ne "${found}" ]]; then
    echo "ERROR: R1/R2 file counts differ (R1=${found}, R2=${r2_count}); check for orphan/extra R2 files" >&2
    exit 1
  fi
else
  printf 'sample-id\tabsolute-filepath\n' > "${MANIFEST}"
  while IFS= read -r -d '' read_file; do
    name="$(basename "${read_file}")"
    sample="${name%.fastq.gz}"
    sample="${sample%.fq.gz}"
    printf '%s\t%s\n' "${sample}" "${read_file}" >> "${MANIFEST}"
  done < <(find "${FASTQ_DIR}" -maxdepth 1 -type f \( -name '*.fastq.gz' -o -name '*.fq.gz' \) -print0 | sort -z)
fi

# Sample ID sanity: no whitespace, no path separators / control characters.
if awk -F '\t' 'NR>1 && $1 !~ /^[A-Za-z0-9._-]+$/ {print $1}' "${MANIFEST}" | grep -q .; then
  echo "ERROR: manifest contains invalid sample IDs (allowed: letters, digits, . _ -):" >&2
  awk -F '\t' 'NR>1 && $1 !~ /^[A-Za-z0-9._-]+$/ {print $1}' "${MANIFEST}" >&2
  exit 1
fi

awk -F '\t' 'NR>1 {print $1}' "${MANIFEST}" | sort > "${QC_DIR}/manifest_samples.txt"
duplicates="$(uniq -d "${QC_DIR}/manifest_samples.txt")"
[[ -z "${duplicates}" ]] || { printf 'ERROR: duplicate sample IDs:\n%s\n' "${duplicates}" >&2; exit 1; }

# Metadata: use the provided file, or auto-generate a minimal one.
if [[ -z "${METADATA_FILE}" && "${AUTO_GENERATE_METADATA}" == "yes" ]]; then
  auto_meta="${PROJECT_DIR}/work/metadata.tsv"
  printf '#SampleID\tsample_name\n' > "${auto_meta}"
  while IFS= read -r sid; do
    printf '%s\t%s\n' "${sid}" "${sid}" >> "${auto_meta}"
  done < "${QC_DIR}/manifest_samples.txt"
  printf 'export METADATA_FILE=%q\n' "${auto_meta}" > "${PROJECT_DIR}/work/generated.env"
  METADATA_FILE="${auto_meta}"
  echo "Auto-generated metadata: ${auto_meta} (replace with your own columns before interpretation)"
fi

if [[ -z "${METADATA_FILE}" ]]; then
  echo "ERROR: METADATA_FILE is empty (set it or enable AUTO_GENERATE_METADATA=yes)" >&2
  exit 1
fi
[[ -s "${METADATA_FILE}" ]] || { echo "ERROR: metadata not found or empty: ${METADATA_FILE}" >&2; exit 1; }

awk -F '\t' 'NR>1 && NF && $1 !~ /^#/ {print $1}' "${METADATA_FILE}" | sort -u > "${QC_DIR}/metadata_samples.txt"
comm -23 "${QC_DIR}/manifest_samples.txt" "${QC_DIR}/metadata_samples.txt" > "${QC_DIR}/only_in_manifest.txt"
comm -13 "${QC_DIR}/manifest_samples.txt" "${QC_DIR}/metadata_samples.txt" > "${QC_DIR}/only_in_metadata.txt"
if [[ -s "${QC_DIR}/only_in_manifest.txt" || -s "${QC_DIR}/only_in_metadata.txt" ]]; then
  echo "ERROR: manifest and metadata sample IDs differ; inspect ${QC_DIR}/only_in_*.txt" >&2
  exit 1
fi
echo "Manifest created: ${MANIFEST}"
