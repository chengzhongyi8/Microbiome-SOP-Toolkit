#!/usr/bin/env bash
# Purpose: calculate per-sample contig GC/assembly statistics and prepare >500 bp inputs for optional traits.
# Input: per-sample assemblies from samples.tsv.
# Output: QUAST directories and filtered contig FASTA files.
# Software: seqkit, QUAST. MicrobeCensus/RasperGade16S/gRodon remain explicit follow-up choices.
# Resources: THREADS_PER_JOB CPUs per sequential sample.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_TRAITS}" "${SEQKIT}" quast.py
OUT="${PROJECT_DIR}/results/11_microbe_traits"; mkdir -p "${OUT}/contigs_500bp" "${OUT}/quast"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  fasta="${PROJECT_DIR}/results/02_assembly/single/${sample}/final.contigs.fa"
  "${SEQKIT}" seq -m 500 "${fasta}" > "${OUT}/contigs_500bp/${sample}.fa"
  quast.py -t "${THREADS_PER_JOB}" -o "${OUT}/quast/${sample}" "${fasta}"
done < "${SAMPLES_TSV}"
