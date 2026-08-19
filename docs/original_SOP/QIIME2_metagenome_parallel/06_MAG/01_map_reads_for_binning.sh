#!/usr/bin/env bash
# Purpose: map all metagenome reads to the chosen assembly and create sorted BAM/depth inputs for binners.
# Input: ASSEMBLY_FASTA environment variable and samples.tsv.
# Output: results/06_MAG/mapping/*.bam and metabat_depth.tsv.
# Software: Bowtie2, samtools, MetaBAT2 jgi_summarize_bam_contig_depths.
# Resources: THREADS_PER_JOB CPUs per sequential sample; substantial BAM storage.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config/project_config.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_MAPPING}" bowtie2 bowtie2-build samtools jgi_summarize_bam_contig_depths
: "${ASSEMBLY_FASTA:?Set ASSEMBLY_FASTA to one single/coassembly FASTA; do not use a concatenation without documenting it}"
[[ -s "${ASSEMBLY_FASTA}" ]] || { echo "ERROR: ASSEMBLY_FASTA not found" >&2; exit 1; }
OUT="${PROJECT_DIR}/results/06_MAG/mapping"; mkdir -p "${OUT}"
[[ -s "${OUT}/assembly.1.bt2" || -s "${OUT}/assembly.1.bt2l" ]] || bowtie2-build --threads "${THREADS_PER_JOB}" "${ASSEMBLY_FASTA}" "${OUT}/assembly"
bams=()
while IFS=$'\t' read -r sample group r1 r2 metat_r1 metat_r2; do
  [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
  bowtie2 -x "${OUT}/assembly" -1 "${r1}" -2 "${r2}" -p "${THREADS_PER_JOB}" --very-sensitive \
    | samtools sort -@ "${THREADS_PER_JOB}" -o "${OUT}/${sample}.bam"
  samtools index -@ "${THREADS_PER_JOB}" "${OUT}/${sample}.bam"
  bams+=("${OUT}/${sample}.bam")
done < "${SAMPLES_TSV}"
jgi_summarize_bam_contig_depths --outputDepth "${OUT}/metabat_depth.tsv" "${bams[@]}"
