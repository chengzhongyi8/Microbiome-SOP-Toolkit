#!/usr/bin/env bash
# Purpose: classify assembled contigs; results must not be labeled as reads-based relative abundance.
# Input: renamed per-sample contigs.
# Output: contig classification and family summaries.
# Software/database: Kaiju.
# Resources: THREADS_PER_JOB CPUs per sequential sample.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_KAIJU}" "${KAIJU}" "${KAIJU2TABLE}"
OUT="${PROJECT_DIR}/results/04_taxonomy/contigs"; mkdir -p "${OUT}"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  fasta="${PROJECT_DIR}/results/02_assembly/renamed/${sample}.contigs.fa"
  "${KAIJU}" -z "${THREADS_PER_JOB}" -t "${KAIJU_NODES}" -f "${KAIJU_FMI}" -i "${fasta}" -o "${OUT}/${sample}.out"
  "${KAIJU2TABLE}" -t "${KAIJU_NODES}" -n "${KAIJU_NAMES}" -r family -o "${OUT}/${sample}.family.tsv" "${OUT}/${sample}.out"
done < "${SAMPLES_TSV}"
