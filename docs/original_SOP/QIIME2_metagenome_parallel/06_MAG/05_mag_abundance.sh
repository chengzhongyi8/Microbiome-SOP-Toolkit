#!/usr/bin/env bash
# Purpose: quantify dereplicated MAG coverage/abundance from every sample.
# Input: dRep genomes and samples.tsv reads.
# Output: per-sample CoverM count, covered_fraction, mean, rpkm, tpm, relative_abundance.
# Software: CoverM.
# Resources: THREADS_PER_JOB CPUs per sequential sample.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_COVERM}" "${COVERM}"
MAG_DIR="${PROJECT_DIR}/results/06_MAG/postprocess/drep/dereplicated_genomes"
OUT="${PROJECT_DIR}/results/06_MAG/abundance"; mkdir -p "${OUT}"
mags=("${MAG_DIR}"/*.fa)
[[ -s "${mags[0]}" ]] || { echo "ERROR: no dereplicated MAG FASTA files" >&2; exit 1; }
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  "${COVERM}" genome -d "${mags[@]}" -t "${THREADS_PER_JOB}" \
    --coupled "${r1}" "${r2}" --min-read-percent-identity "${MIN_READ_IDENTITY}" \
    --min-read-aligned-percent "${MIN_READ_ALIGNED_PERCENT}" \
    -m count covered_fraction mean rpkm tpm relative_abundance -o "${OUT}/${sample}.tsv"
done < "${SAMPLES_TSV}"
