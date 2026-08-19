#!/usr/bin/env bash
# Purpose: run selected independent MAG binners on one documented assembly/depth matrix.
# Input: ASSEMBLY_FASTA and results/06_MAG/mapping.
# Output: separate MetaBAT2, MaxBin2 and/or CONCOCT directories.
# Software: MetaBAT2, MaxBin2, CONCOCT.
# Resources: THREADS_PER_JOB CPUs; binners run sequentially.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
: "${ASSEMBLY_FASTA:?Set ASSEMBLY_FASTA}"
MAP="${PROJECT_DIR}/results/06_MAG/mapping"; OUT="${PROJECT_DIR}/results/06_MAG/binning"; mkdir -p "${OUT}"

if [[ ",${MAG_BINNERS}," == *",metabat2,"* ]]; then
  source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_BINNING}" metabat2
  mkdir -p "${OUT}/metabat2"
  metabat2 -i "${ASSEMBLY_FASTA}" -a "${MAP}/metabat_depth.tsv" -m "${BIN_MIN_CONTIG_LEN}" \
    -t "${THREADS_PER_JOB}" -o "${OUT}/metabat2/bin"
fi
if [[ ",${MAG_BINNERS}," == *",maxbin2,"* ]]; then
  mkdir -p "${OUT}/maxbin2"
  awk -F '\t' 'NR==1 {for (i=4;i<=NF;i++) print $i}' "${MAP}/metabat_depth.tsv" > "${OUT}/maxbin2/abundance_columns.txt"
  echo "REVIEW REQUIRED: prepare one two-column contig abundance file per sample from metabat_depth.tsv, list them in abundance_list.txt, then run:"
  echo "run_MaxBin.pl -contig \"${ASSEMBLY_FASTA}\" -abund_list \"${OUT}/maxbin2/abundance_list.txt\" -out \"${OUT}/maxbin2/bin\" -thread \"${THREADS_PER_JOB}\""
fi
if [[ ",${MAG_BINNERS}," == *",concoct,"* ]]; then
  mkdir -p "${OUT}/concoct"
  echo "REVIEW REQUIRED: CONCOCT requires its own cut-up contig and coverage-table workflow."
  echo "Run cut_up_fasta.py, concoct_coverage_table.py, concoct, merge_cutup_clustering.py, then extract_fasta_bins.py."
fi
