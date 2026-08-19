#!/usr/bin/env bash
# Purpose: produce reads-based taxonomic profiles; these estimate read composition, not contig/MAG composition.
# Input: samples.tsv metagenome paired reads.
# Output: Kaiju raw and rank tables per sample.
# Software/database: Kaiju, nodes.dmp, names.dmp, FMI database.
# Resources: THREADS_PER_JOB CPUs per sequential sample.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_KAIJU}" "${KAIJU}" "${KAIJU2TABLE}"
for db in "${KAIJU_NODES}" "${KAIJU_NAMES}" "${KAIJU_FMI}"; do [[ -s "${db}" ]] || { echo "ERROR: configure Kaiju databases" >&2; exit 1; }; done
OUT="${PROJECT_DIR}/results/04_taxonomy/reads"; mkdir -p "${OUT}"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  "${KAIJU}" -z "${THREADS_PER_JOB}" -t "${KAIJU_NODES}" -f "${KAIJU_FMI}" -i "${r1}" -j "${r2}" -o "${OUT}/${sample}.out"
  "${KAIJU2TABLE}" -t "${KAIJU_NODES}" -n "${KAIJU_NAMES}" -r family -o "${OUT}/${sample}.family.tsv" "${OUT}/${sample}.out"
done < "${SAMPLES_TSV}"
