#!/usr/bin/env bash
# Purpose: denoise reads and optionally filter ASVs by sample prevalence.
# Input: work/demux-for-dada2.qza and DADA2 parameters (manual or auto-estimated by step 08).
# Output: raw and prevalence-filtered table, rep-seqs, stats, and qzv files.
# Software: QIIME2 q2-dada2 and q2-feature-table.
# Resources: DADA2_THREADS CPUs; memory depends on read count.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${WORKFLOW_DIR}/config.sh"
[[ -f "${WORKFLOW_DIR}/config.local.sh" ]] && source "${WORKFLOW_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR:-}/work/config.local.sh" ]] && source "${PROJECT_DIR}/work/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/dada2_params.env" ]] && source "${PROJECT_DIR}/work/dada2_params.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${WORKFLOW_DIR}/activate_qiime2.sh"
INPUT="${PROJECT_DIR}/work/demux-for-dada2.qza"
DADA2_DIR="${PROJECT_DIR}/results/dada2"
mkdir -p "${DADA2_DIR}/debug"
# 让 q2cli 的调试日志（qiime2-q2cli-err-*.log）落在项目目录而不是计算节点的 /tmp，
# 这样 DADA2 失败时能直接看到 R 层的完整报错。
export TMPDIR="${DADA2_DIR}/debug"

# Resolve DADA2 parameters: manual config values win; otherwise use auto-estimated ones.
if [[ -n "${TRUNC_LEN_F}" ]]; then
  [[ -z "${TRIM_LEFT_F:-}" ]] && TRIM_LEFT_F="${TRIM_LEFT_F_AUTO:-0}"
  echo "Using forward DADA2 parameters: trim-left=${TRIM_LEFT_F}, trunc-len=${TRUNC_LEN_F} (manual trunc)"
elif [[ "${AUTO_TRUNC}" == "yes" && -n "${TRUNC_LEN_F_AUTO:-}" ]]; then
  TRUNC_LEN_F="${TRUNC_LEN_F_AUTO}"
  [[ -z "${TRIM_LEFT_F:-}" ]] && TRIM_LEFT_F="${TRIM_LEFT_F_AUTO:-0}"
  echo "Using forward DADA2 parameters: trim-left=${TRIM_LEFT_F}, trunc-len=${TRUNC_LEN_F} (auto trunc)"
else
  echo "ERROR: fill TRIM_LEFT_F and TRUNC_LEN_F manually (or enable AUTO_TRUNC=yes and run 08_auto_dada2_params.sh)" >&2
  exit 1
fi
[[ "${TRIM_LEFT_F}" =~ ^[0-9]+$ && "${TRUNC_LEN_F}" =~ ^[0-9]+$ ]] || { echo "ERROR: forward DADA2 parameters must be non-negative integers" >&2; exit 1; }
if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
  if [[ -n "${TRUNC_LEN_R}" ]]; then
    [[ -z "${TRIM_LEFT_R:-}" ]] && TRIM_LEFT_R="${TRIM_LEFT_R_AUTO:-0}"
    echo "Using reverse DADA2 parameters: trim-left=${TRIM_LEFT_R}, trunc-len=${TRUNC_LEN_R} (manual trunc)"
  elif [[ "${AUTO_TRUNC}" == "yes" && -n "${TRUNC_LEN_R_AUTO:-}" ]]; then
    TRUNC_LEN_R="${TRUNC_LEN_R_AUTO}"
    [[ -z "${TRIM_LEFT_R:-}" ]] && TRIM_LEFT_R="${TRIM_LEFT_R_AUTO:-0}"
    echo "Using reverse DADA2 parameters: trim-left=${TRIM_LEFT_R}, trunc-len=${TRUNC_LEN_R} (auto trunc)"
  else
    echo "ERROR: fill TRIM_LEFT_R and TRUNC_LEN_R manually (or enable AUTO_TRUNC=yes and run 08_auto_dada2_params.sh)" >&2
    exit 1
  fi
  [[ "${TRIM_LEFT_R}" =~ ^[0-9]+$ && "${TRUNC_LEN_R}" =~ ^[0-9]+$ ]] || { echo "ERROR: reverse DADA2 parameters must be non-negative integers" >&2; exit 1; }
  qiime dada2 denoise-paired --i-demultiplexed-seqs "${INPUT}" \
    --p-trim-left-f "${TRIM_LEFT_F}" --p-trim-left-r "${TRIM_LEFT_R}" \
    --p-trunc-len-f "${TRUNC_LEN_F}" --p-trunc-len-r "${TRUNC_LEN_R}" \
    --p-max-ee-f "${MAX_EE}" --p-max-ee-r "${MAX_EE}" \
    --p-n-threads "${DADA2_THREADS}" --o-table "${DADA2_DIR}/table-unfiltered.qza" \
    --o-representative-sequences "${DADA2_DIR}/rep-seqs-unfiltered.qza" \
    --o-denoising-stats "${DADA2_DIR}/stats.qza"
else
  qiime dada2 denoise-single --i-demultiplexed-seqs "${INPUT}" \
    --p-trim-left "${TRIM_LEFT_F}" --p-trunc-len "${TRUNC_LEN_F}" \
    --p-max-ee "${MAX_EE}" \
    --p-n-threads "${DADA2_THREADS}" --o-table "${DADA2_DIR}/table-unfiltered.qza" \
    --o-representative-sequences "${DADA2_DIR}/rep-seqs-unfiltered.qza" \
    --o-denoising-stats "${DADA2_DIR}/stats.qza"
fi

if [[ -n "${MIN_SAMPLES}" ]]; then
  [[ "${MIN_SAMPLES}" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: MIN_SAMPLES must be empty or a positive integer" >&2; exit 1; }
  qiime feature-table filter-features --i-table "${DADA2_DIR}/table-unfiltered.qza" \
    --p-min-samples "${MIN_SAMPLES}" --o-filtered-table "${DADA2_DIR}/table-prevalence.qza"
  qiime feature-table filter-seqs --i-data "${DADA2_DIR}/rep-seqs-unfiltered.qza" \
    --i-table "${DADA2_DIR}/table-prevalence.qza" --o-filtered-data "${DADA2_DIR}/rep-seqs-prevalence.qza"
else
  cp "${DADA2_DIR}/table-unfiltered.qza" "${DADA2_DIR}/table-prevalence.qza"
  cp "${DADA2_DIR}/rep-seqs-unfiltered.qza" "${DADA2_DIR}/rep-seqs-prevalence.qza"
fi

qiime metadata tabulate --m-input-file "${DADA2_DIR}/stats.qza" --o-visualization "${DADA2_DIR}/stats.qzv"
qiime feature-table summarize --i-table "${DADA2_DIR}/table-prevalence.qza" \
  --m-sample-metadata-file "${METADATA_FILE}" --o-visualization "${DADA2_DIR}/table.qzv"
qiime feature-table tabulate-seqs --i-data "${DADA2_DIR}/rep-seqs-prevalence.qza" \
  --o-visualization "${DADA2_DIR}/rep-seqs.qzv"

# 全部成功后才写完成标记；否则 resume 会看到旧的 table-prevalence.qza 就跳过本步
touch "${DADA2_DIR}/.step04.done"
echo "Step 04 complete."
