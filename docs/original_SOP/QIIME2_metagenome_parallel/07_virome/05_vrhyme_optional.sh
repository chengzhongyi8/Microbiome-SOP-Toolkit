#!/usr/bin/env bash
# Purpose: optionally bin viral contigs while preserving each bin as a multi-contig FASTA.
# Input: VIRUS_FASTA and metagenome reads.
# Output: native vRhyme bin files and membership tables; never concatenated into fake sequences.
# Software: vRhyme.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
[[ "${RUN_VRHYME}" == "yes" ]] || { echo "vRhyme disabled."; exit 0; }
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_VRHYME}" vRhyme
: "${VIRUS_FASTA:?Set VIRUS_FASTA}"
OUT="${PROJECT_DIR}/results/07_virome/vrhyme"; mkdir -p "${OUT}"
reads=()
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  reads+=("${r1}" "${r2}")
done < "${SAMPLES_TSV}"
vRhyme -i "${VIRUS_FASTA}" -r "${reads[@]}" -t "${THREADS_PER_JOB}" -o "${OUT}"
echo "Keep each native bin FASTA with all contig headers. CheckV is primarily a single-contig evaluator."
