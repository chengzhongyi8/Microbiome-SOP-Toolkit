#!/usr/bin/env bash
# Purpose: optional group-wise coassembly; distinct from concatenating completed assemblies.
# Input: samples.tsv grouped paired reads.
# Output: results/02_assembly/coassembly/<group>/final.contigs.fa.
# Software: MEGAHIT.
# Resources: THREADS_PER_JOB CPUs per group; potentially high memory/storage.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
[[ "${ASSEMBLY_STRATEGY}" == "coassembly" ]] || { echo "Coassembly disabled."; exit 0; }
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_ASSEMBLY}" "${MEGAHIT}"
OUT="${PROJECT_DIR}/results/02_assembly/coassembly"; mkdir -p "${OUT}"
awk -F '\t' 'NR>1 && $1 !~ /^#/ && $2 != "" {print $2}' "${SAMPLES_TSV}" | sort -u | while IFS= read -r group; do
  r1_list="$(awk -F '\t' -v g="${group}" 'NR>1 && $2==g {if (x) x=x","$3; else x=$3} END {print x}' "${SAMPLES_TSV}")"
  r2_list="$(awk -F '\t' -v g="${group}" 'NR>1 && $2==g {if (x) x=x","$4; else x=$4} END {print x}' "${SAMPLES_TSV}")"
  "${MEGAHIT}" -1 "${r1_list}" -2 "${r2_list}" -o "${OUT}/${group}" -t "${THREADS_PER_JOB}" \
    --k-min "${MEGAHIT_K_MIN}" --k-max "${MEGAHIT_K_MAX}" --k-step "${MEGAHIT_K_STEP}" \
    --min-contig-len "${MEGAHIT_MIN_CONTIG_LEN}"
done
