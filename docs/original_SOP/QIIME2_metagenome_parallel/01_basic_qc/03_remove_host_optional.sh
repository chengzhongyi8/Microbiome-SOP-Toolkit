#!/usr/bin/env bash
# Purpose: optionally remove reads mapping to a configured host reference.
# Input: paired metagenome reads, HOST_REFERENCE.
# Output: results/01_basic_qc/host_removed/<sample>_R[12].fastq.gz.
# Software: Bowtie2 and samtools.
# Resources: THREADS_PER_JOB CPUs; host index must already exist.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
[[ "${RUN_HOST_REMOVAL}" == "yes" ]] || { echo "Host removal disabled; no files changed."; exit 0; }
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_HOST_REMOVAL}" bowtie2 samtools
[[ -n "${HOST_REFERENCE}" ]] || { echo "ERROR: HOST_REFERENCE is empty" >&2; exit 1; }
OUT="${PROJECT_DIR}/results/01_basic_qc/host_removed"; mkdir -p "${OUT}"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  bowtie2 -x "${HOST_REFERENCE}" -1 "${r1}" -2 "${r2}" -p "${THREADS_PER_JOB}" \
    --very-sensitive --un-conc-gz "${OUT}/${sample}_R%.fastq.gz" -S "${OUT}/${sample}.host.sam"
  samtools flagstat -@ "${THREADS_PER_JOB}" "${OUT}/${sample}.host.sam" > "${OUT}/${sample}.flagstat.txt"
done < "${SAMPLES_TSV}"
