#!/usr/bin/env bash
# Purpose: predict genes from each reviewed MAG using genome/normal mode, not metagenome mode.
# Input: dereplicated MAG FASTA files.
# Output: per-MAG GFF, proteins, CDS.
# Software: Prodigal. Downstream eggNOG/KOfam can consume proteins.
# Resources: 1 CPU per sequential MAG.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_GENE}" "${PRODIGAL}"
MAG_DIR="${PROJECT_DIR}/results/06_MAG/postprocess/drep/dereplicated_genomes"
OUT="${PROJECT_DIR}/results/06_MAG/annotation"; mkdir -p "${OUT}"
for fasta in "${MAG_DIR}"/*.fa; do
  mag="$(basename "${fasta}" .fa)"
  "${PRODIGAL}" -i "${fasta}" -p single -f gff -o "${OUT}/${mag}.gff" \
    -a "${OUT}/${mag}.faa" -d "${OUT}/${mag}.fna"
done
