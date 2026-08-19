#!/usr/bin/env bash
# Purpose: import FASTQ into QIIME2, summarize quality, and export per-sample input depths.
# Input: work/manifest.tsv.
# Output: results/qc/demux.qza, demux.qzv, sample-sequence-counts.tsv.
# Software: QIIME2.
# Resources: 1 CPU; storage approximately equals compressed input size.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${SCRIPT_DIR}/activate_qiime2.sh"
MANIFEST="${PROJECT_DIR}/work/manifest.tsv"
QC_DIR="${PROJECT_DIR}/results/qc"
[[ -s "${MANIFEST}" ]] || { echo "ERROR: run 01_make_manifest.sh first" >&2; exit 1; }

if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
  qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "${MANIFEST}" --output-path "${QC_DIR}/demux.qza" \
    --input-format PairedEndFastqManifestPhred33V2
else
  qiime tools import --type 'SampleData[SequencesWithQuality]' \
    --input-path "${MANIFEST}" --output-path "${QC_DIR}/demux.qza" \
    --input-format SingleEndFastqManifestPhred33V2
fi

qiime demux summarize --i-data "${QC_DIR}/demux.qza" --o-visualization "${QC_DIR}/demux.qzv"
qiime tools export --input-path "${QC_DIR}/demux.qza" --output-path "${PROJECT_DIR}/work/demux_export"

if [[ "${COUNT_READS}" == "yes" ]]; then
  if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
    printf 'sample-id\tforward-reads\treverse-reads\n' > "${QC_DIR}/sample-sequence-counts.tsv"
    while IFS=$'\t' read -r sample forward reverse; do
      [[ "${sample}" == "sample-id" ]] && continue
      n_forward="$(gzip -cd "${forward}" | awk 'END {print NR/4}')"
      n_reverse="$(gzip -cd "${reverse}" | awk 'END {print NR/4}')"
      [[ "${n_forward}" == "${n_reverse}" ]] || { echo "ERROR: paired FASTQ counts differ for ${sample}" >&2; exit 1; }
      printf '%s\t%s\t%s\n' "${sample}" "${n_forward}" "${n_reverse}" >> "${QC_DIR}/sample-sequence-counts.tsv"
    done < "${MANIFEST}"
  else
    printf 'sample-id\treads\n' > "${QC_DIR}/sample-sequence-counts.tsv"
    while IFS=$'\t' read -r sample reads; do
      [[ "${sample}" == "sample-id" ]] && continue
      n_reads="$(gzip -cd "${reads}" | awk 'END {print NR/4}')"
      printf '%s\t%s\n' "${sample}" "${n_reads}" >> "${QC_DIR}/sample-sequence-counts.tsv"
    done < "${MANIFEST}"
  fi
else
  echo "NOTE: COUNT_READS=no; skipping per-sample read counts (demux.qzv still has them)."
fi

cat <<MSG
Stage 1 complete.
Open: ${QC_DIR}/demux.qzv
Review quality plots, overlap, primer status, and sample depths.
- If AUTO_TRUNC=yes and TRIM_LEFT_*/TRUNC_LEN_* are empty, stage 2 will estimate them automatically.
- To force manual values, fill all applicable TRIM_LEFT_* and TRUNC_LEN_* in config.sh / config.local.sh.
- Primers are detected automatically (AUTO_PRIMER_TRIM=yes) and trimmed when found.
MSG
