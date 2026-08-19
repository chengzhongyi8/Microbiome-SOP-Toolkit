#!/usr/bin/env bash
# Purpose: assemble each metagenome independently with MEGAHIT.
# Input: samples.tsv metag read pairs.
# Output: results/02_assembly/single/<sample>/final.contigs.fa.
# Software: MEGAHIT.
# Resources: THREADS_PER_JOB CPUs per sequential sample, MEMORY_GB upper memory setting.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_ASSEMBLY}" "${MEGAHIT}"
OUT="${PROJECT_DIR}/results/02_assembly/single"; mkdir -p "${OUT}"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  [[ ! -e "${OUT}/${sample}/final.contigs.fa" ]] || { echo "Skip existing assembly: ${sample}"; continue; }
  "${MEGAHIT}" -1 "${r1}" -2 "${r2}" -o "${OUT}/${sample}" -t "${THREADS_PER_JOB}" \
    --k-min "${MEGAHIT_K_MIN}" --k-max "${MEGAHIT_K_MAX}" --k-step "${MEGAHIT_K_STEP}" \
    --min-contig-len "${MEGAHIT_MIN_CONTIG_LEN}"
done < "${SAMPLES_TSV}"
