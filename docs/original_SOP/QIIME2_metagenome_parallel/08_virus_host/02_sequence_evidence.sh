#!/usr/bin/env bash
# Purpose: generate independent tRNA, CRISPR-spacer, and long-sequence-homology host evidence.
# Input: VOTU_FASTA, MAG_FASTA, optional SPACER_FASTA environment variables.
# Output: separate BLAST TSV files; no manual Excel merge.
# Software: tRNAscan-SE, BLAST+; CRISPR spacers must be extracted by a reviewed caller.
# Resources: THREADS_PER_JOB CPUs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_HOST_EVIDENCE}" tRNAscan-SE makeblastdb blastn
: "${VOTU_FASTA:?Set VOTU_FASTA}"; : "${MAG_FASTA:?Set MAG_FASTA to concatenated MAG contigs with MAG-prefixed unique IDs}"
OUT="${PROJECT_DIR}/results/08_virus_host/sequence_evidence"; mkdir -p "${OUT}"
makeblastdb -in "${MAG_FASTA}" -dbtype nucl -out "${OUT}/mag_db"
tRNAscan-SE -B -o "${OUT}/votu_trna.out" -a "${OUT}/votu_trna.fna" "${VOTU_FASTA}"
blastn -query "${OUT}/votu_trna.fna" -db "${OUT}/mag_db" -perc_identity 100 -qcov_hsp_perc 100 \
  -evalue 1e-5 -num_threads "${THREADS_PER_JOB}" -outfmt '6 qseqid sseqid pident length qlen slen evalue bitscore' \
  -out "${OUT}/trna_hits.tsv"
makeblastdb -in "${VOTU_FASTA}" -dbtype nucl -out "${OUT}/votu_db"
if [[ -n "${SPACER_FASTA:-}" ]]; then
  blastn -task blastn-short -query "${SPACER_FASTA}" -db "${OUT}/votu_db" -evalue 1e-5 \
    -num_threads "${THREADS_PER_JOB}" -outfmt '6 qseqid sseqid pident length mismatch qlen evalue bitscore' \
    -out "${OUT}/crispr_hits.tsv"
fi
blastn -query "${VOTU_FASTA}" -db "${OUT}/mag_db" -perc_identity 70 -qcov_hsp_perc 75 -evalue 1e-3 \
  -num_threads "${THREADS_PER_JOB}" -outfmt '6 qseqid sseqid pident length qlen slen qcovs evalue bitscore' \
  -out "${OUT}/homology_hits.tsv"
