#!/usr/bin/env bash
# Purpose: predict genes from renamed metagenomic contigs and preserve contig-to-gene coordinates.
# Input: results/02_assembly/renamed/all_samples.contigs.fa.
# Output: results/03_gene_catalog/prediction genes.fna, proteins.faa, genes.gff.
# Software: Prodigal. Use anonymous mode for mixed metagenomic contigs.
# Resources: 1 CPU per Prodigal process; split by complete FASTA records only when needed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_GENE}" "${PRODIGAL}"
IN="${PROJECT_DIR}/results/02_assembly/renamed/all_samples.contigs.fa"
OUT="${PROJECT_DIR}/results/03_gene_catalog/prediction"; mkdir -p "${OUT}"
[[ -s "${IN}" ]] || { echo "ERROR: combined renamed contigs not found" >&2; exit 1; }
"${PRODIGAL}" -i "${IN}" -p meta -f gff -o "${OUT}/genes.gff" \
  -d "${OUT}/genes.fna" -a "${OUT}/proteins.faa"

# For unusually large input, split records safely, never with `split -l`:
# seqkit split2 -s 50000 --out-dir chunks "${IN}"
