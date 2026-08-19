#!/usr/bin/env bash
# Purpose: rename single-sample contigs as sample|full_original_id, validate uniqueness, and report stats.
# Input: per-sample final.contigs.fa.
# Output: renamed per-sample FASTA, combined FASTA, seqkit stats.
# Software: awk, seqkit.
# Resources: 1 CPU for renaming; THREADS_PER_JOB for stats. No source assembly is deleted.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"; source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_SEQKIT}" "${SEQKIT}"
IN="${PROJECT_DIR}/results/02_assembly/single"; OUT="${PROJECT_DIR}/results/02_assembly/renamed"
mkdir -p "${OUT}"; : > "${OUT}/all_samples.contigs.fa"
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  fasta="${IN}/${sample}/final.contigs.fa"; [[ -s "${fasta}" ]] || { echo "ERROR: missing assembly for ${sample}" >&2; exit 1; }
  awk -v s="${sample}" '/^>/ {id=$1; sub(/^>/, "", id); print ">" s "|" id; next} {print}' "${fasta}" > "${OUT}/${sample}.contigs.fa"
  awk '/^>/ {sub(/^>/, ""); print $1}' "${OUT}/${sample}.contigs.fa" | sort | uniq -d > "${OUT}/${sample}.duplicate_ids.txt"
  [[ ! -s "${OUT}/${sample}.duplicate_ids.txt" ]] || { echo "ERROR: duplicate renamed contigs for ${sample}" >&2; exit 1; }
  "${SEQKIT}" seq -m "${GENE_MIN_CONTIG_LEN}" "${OUT}/${sample}.contigs.fa" >> "${OUT}/all_samples.contigs.fa"
done < "${SAMPLES_TSV}"
awk '/^>/ {sub(/^>/, ""); print $1}' "${OUT}/all_samples.contigs.fa" | sort | uniq -d > "${OUT}/all_samples.duplicate_ids.txt"
[[ ! -s "${OUT}/all_samples.duplicate_ids.txt" ]] || { echo "ERROR: duplicate IDs in combined contig collection" >&2; exit 1; }
"${SEQKIT}" stats -T -j "${THREADS_PER_JOB}" "${OUT}"/*.contigs.fa "${OUT}/all_samples.contigs.fa" > "${OUT}/contig_stats.tsv"
