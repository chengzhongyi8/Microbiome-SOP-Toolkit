#!/usr/bin/env bash
# Purpose: run one configured primary virus detector; supplementary detectors are opt-in and remain separate.
# Input: ASSEMBLY_FASTA environment variable.
# Output: detector-specific unmerged output directories.
# Software/databases: geNomad or VirSorter2; optional DeepVirFinder/VIBRANT are not auto-run.
# Resources: THREADS_PER_JOB CPUs; database-dependent memory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
: "${ASSEMBLY_FASTA:?Set ASSEMBLY_FASTA to the assembly under study}"
OUT="${PROJECT_DIR}/results/07_virome/detection"; mkdir -p "${OUT}"
if [[ "${VIRUS_PRIMARY}" == "genomad" ]]; then
  source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_VIRUS_GENOMAD}" "${GENOMAD}"
  [[ -d "${GENOMAD_DB}" ]] || { echo "ERROR: configure GENOMAD_DB" >&2; exit 1; }
  "${GENOMAD}" end-to-end --cleanup --threads "${THREADS_PER_JOB}" \
    "${ASSEMBLY_FASTA}" "${OUT}/genomad" "${GENOMAD_DB}"
elif [[ "${VIRUS_PRIMARY}" == "virsorter2" ]]; then
  source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_VIRUS_VIRSORTER2}" "${VIRSORTER2}"
  "${VIRSORTER2}" run --prep-for-dramv -i "${ASSEMBLY_FASTA}" -w "${OUT}/virsorter2" \
    --min-length "${VIRUS_MIN_CONTIG_LEN}" -j "${THREADS_PER_JOB}" all
else
  echo "ERROR: VIRUS_PRIMARY must be genomad or virsorter2" >&2; exit 1
fi

[[ "${RUN_DEEPVIRFINDER}" == "no" ]] || echo "REVIEW: run DeepVirFinder in its own environment and keep its scores separate."
[[ "${RUN_VIBRANT}" == "no" ]] || echo "REVIEW: run VIBRANT separately; its AMG list is candidate evidence, not final AMGs."
