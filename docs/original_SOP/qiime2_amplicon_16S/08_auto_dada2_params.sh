#!/usr/bin/env bash
# Purpose: estimate DADA2 trim/trunc parameters from the quality profile when
#          AUTO_TRUNC=yes and manual values are empty.
# Input: work/demux-for-dada2.qza, work/primers.env (from step 03), config.
# Output: work/dada2_auto.env with TRIM_LEFT_*_AUTO and TRUNC_LEN_*_AUTO.
# Software: Python 3 (stdlib only), QIIME2 tools export.
# Resources: 1 CPU, low memory (samples a bounded number of reads).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/dada2_params.env" ]] && source "${PROJECT_DIR}/work/dada2_params.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${SCRIPT_DIR}/activate_qiime2.sh"

[[ "${AUTO_TRUNC}" == "yes" ]] || { echo "AUTO_TRUNC=no; keeping manual DADA2 parameters."; exit 0; }

INPUT="${PROJECT_DIR}/work/demux-for-dada2.qza"
EXPORT_DIR="${PROJECT_DIR}/work/demux_dada2_export"
OUT_ENV="${PROJECT_DIR}/work/dada2_auto.env"
[[ -s "${INPUT}" ]] || { echo "ERROR: ${INPUT} not found (run 03 first)" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found (needed for auto DADA2 estimation)" >&2; exit 1; }

# Fresh export of the exact reads DADA2 will consume.
if [[ ! -d "${EXPORT_DIR}" || -z "$(find "${EXPORT_DIR}" -name '*.fastq.gz' -o -name '*.fq.gz' -o -name '*.fastq' -o -name '*.fq' 2>/dev/null | head -1)" ]]; then
  rm -rf "${EXPORT_DIR}"
  qiime tools export --input-path "${INPUT}" --output-path "${EXPORT_DIR}"
fi

# Resolve expected amplicon length from REGION when not set explicitly.
expected_arg=()
if [[ -n "${EXPECTED_AMPLICON_LENGTH}" ]]; then
  expected_arg=(--expected-amplicon-length "${EXPECTED_AMPLICON_LENGTH}")
elif [[ -n "${REGION}" && -f "${SCRIPT_DIR}/primers.tsv" ]]; then
  norm_region="$(printf '%s' "${REGION}" | tr '[:lower:]' '[:upper:]' | tr -d ' _-')"
  row="$(awk -F '\t' -v want="${norm_region}" '!/^#/ {
      r=$1; a=$2; gsub(/[ _-]/, "", r); gsub(/[ _-]/, "", a);
      n=split(a, aliases, ",");
      if (toupper(r)==want) {print; exit}
      for (i=1; i<=n; i++) if (toupper(aliases[i])==want) {print; exit}
    }' "${SCRIPT_DIR}/primers.tsv")"
  if [[ -n "${row}" ]]; then
    imin="$(printf '%s' "${row}" | awk -F '\t' '{print $5}')"
    imax="$(printf '%s' "${row}" | awk -F '\t' '{print $6}')"
    expected_len=$(( (imin + imax) / 2 ))
    expected_arg=(--expected-amplicon-length "${expected_len}")
    echo "AUTO: using expected insert length ~${expected_len} bp from REGION=${REGION}"
  fi
fi

args=(--dir "${EXPORT_DIR}" --mode "${SEQUENCING_MODE}"
      --quality-threshold "${QUALITY_THRESHOLD}"
      --min-trunc-len "${MIN_TRUNC_LEN}"
      --max-samples "${MAX_ESTIMATOR_SAMPLES}"
      --max-reads-per-sample "${MAX_ESTIMATOR_READS}")
if [[ -n "${FORWARD_PRIMER}" ]]; then
  args+=(--forward-primer "${FORWARD_PRIMER}")
fi
if [[ "${SEQUENCING_MODE}" == "paired" && -n "${REVERSE_PRIMER}" ]]; then
  args+=(--reverse-primer "${REVERSE_PRIMER}")
fi
args+=("${expected_arg[@]}")

python3 "${SCRIPT_DIR}/bin/estimate_dada2_params.py" "${args[@]}" --output "${OUT_ENV}"
# shellcheck disable=SC1090
source "${OUT_ENV}"

# ---- trim-left --------------------------------------------------------------
# After cutadapt the reads are primer-free -> trim-left 0.
# Without cutadapt, trim-left removes primer bases per detected read.
trim_left_f="0"
trim_left_r="0"
if [[ -n "${TRIM_LEFT_F:-}" ]]; then
  trim_left_f="${TRIM_LEFT_F}"
  echo "Using manual TRIM_LEFT_F=${trim_left_f}"
elif [[ "${CUTADAPT_RAN:-no}" != "yes" && -n "${FORWARD_PRIMER}" && "${PRIMER_DETECTED_F:-no}" == "yes" ]]; then
  trim_left_f="${#FORWARD_PRIMER}"
  echo "AUTO: forward primer still present -> TRIM_LEFT_F=${trim_left_f}"
fi
if [[ -n "${TRIM_LEFT_R:-}" ]]; then
  trim_left_r="${TRIM_LEFT_R}"
  echo "Using manual TRIM_LEFT_R=${trim_left_r}"
elif [[ "${SEQUENCING_MODE}" == "paired" && "${CUTADAPT_RAN:-no}" != "yes" && -n "${REVERSE_PRIMER}" && "${PRIMER_DETECTED_R:-no}" == "yes" ]]; then
  trim_left_r="${#REVERSE_PRIMER}"
  echo "AUTO: reverse primer still present -> TRIM_LEFT_R=${trim_left_r}"
fi

# trunc-len is counted AFTER trim-left in DADA2, so subtract trim-left.
trunc_len_f_auto=$(( ${TRUNC_LEN_F:-0} - trim_left_f ))
if [[ "${trunc_len_f_auto}" -lt 1 ]]; then
  echo "ERROR: auto-estimated TRUNC_LEN_F=${trunc_len_f_auto} is <1 (reads too short vs trim-left ${trim_left_f}); estimator: reads=${READS_ANALYZED:-?} p25_f=${READ_LEN_P25_F:-?} warn=${WARNING:-?}; set TRUNC_LEN_F manually in config.local.sh" >&2
  exit 1
fi
trunc_len_r_auto=0
if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
  trunc_len_r_auto=$(( ${TRUNC_LEN_R:-0} - trim_left_r ))
  if [[ "${trunc_len_r_auto}" -lt 1 ]]; then
    echo "ERROR: auto-estimated TRUNC_LEN_R=${trunc_len_r_auto} is <1 (reads too short vs trim-left ${trim_left_r}); estimator: reads=${READS_ANALYZED:-?} p25_r=${READ_LEN_P25_R:-?} p50_r=${READ_LEN_P50_R:-?} warn=${WARNING:-?}; set TRUNC_LEN_R manually in config.local.sh" >&2
    exit 1
  fi
fi

cat > "${OUT_ENV}" <<ENVEOF
export TRIM_LEFT_F_AUTO='${trim_left_f}'
export TRIM_LEFT_R_AUTO='${trim_left_r}'
export TRUNC_LEN_F_AUTO='${trunc_len_f_auto}'
export TRUNC_LEN_R_AUTO='${trunc_len_r_auto}'
export AUTO_RAW_TRUNC_F='${TRUNC_LEN_F:-0}'
export AUTO_RAW_TRUNC_R='${TRUNC_LEN_R:-0}'
export AUTO_MEAN_Q_AT_TRUNC_F='${MEAN_Q_AT_TRUNC_F:-}'
export AUTO_MEAN_Q_AT_TRUNC_R='${MEAN_Q_AT_TRUNC_R:-}'
export AUTO_READ_LEN_P25_F='${READ_LEN_P25_F:-}'
export AUTO_READ_LEN_P25_R='${READ_LEN_P25_R:-}'
export AUTO_WARNING='${WARNING:-none}'
ENVEOF

cat <<MSG
Auto-estimated DADA2 parameters (config values still win if set):
  TRIM_LEFT_F=${trim_left_f}  TRIM_LEFT_R=${trim_left_r}
  TRUNC_LEN_F=${trunc_len_f_auto}  TRUNC_LEN_R=${trunc_len_r_auto}
  WARNING: ${WARNING:-none}
MSG
