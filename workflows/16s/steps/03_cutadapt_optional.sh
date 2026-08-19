#!/usr/bin/env bash
# Purpose: optionally remove primers before DADA2.
#          With AUTO_PRIMER_TRIM=yes and primers configured, primers are detected
#          at read starts and cutadapt is run automatically when found.
# Input: results/qc/demux.qza (+ work/demux_export for primer detection).
# Output: work/demux-for-dada2.qza and work/primers.env (PRIMER_DETECTED_*, CUTADAPT_RAN).
# Software: QIIME2 q2-cutadapt; Python 3 (estimator, stdlib only).
# Resources: CUTADAPT_THREADS CPUs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${WORKFLOW_DIR}/config.sh"
[[ -f "${WORKFLOW_DIR}/config.local.sh" ]] && source "${WORKFLOW_DIR}/config.local.sh"
[[ -f "${PROJECT_DIR:-}/work/config.local.sh" ]] && source "${PROJECT_DIR}/work/config.local.sh"
[[ -f "${PROJECT_DIR}/work/generated.env" ]] && source "${PROJECT_DIR}/work/generated.env"
[[ -f "${PROJECT_DIR}/work/primers.env" ]] && source "${PROJECT_DIR}/work/primers.env"
[[ -f "${PROJECT_DIR}/work/dada2_auto.env" ]] && source "${PROJECT_DIR}/work/dada2_auto.env"
source "${WORKFLOW_DIR}/activate_qiime2.sh"

INPUT="${PROJECT_DIR}/results/qc/demux.qza"
OUTPUT="${PROJECT_DIR}/work/demux-for-dada2.qza"
DEMUX_EXPORT="${PROJECT_DIR}/work/demux_export"
PRIMERS_ENV="${PROJECT_DIR}/work/primers.env"
[[ -s "${INPUT}" ]] || { echo "ERROR: run stage 1 first" >&2; exit 1; }

run_cutadapt="${RUN_CUTADAPT}"
primer_detected_f="no"
primer_detected_r="no"

# ---- auto primer detection -------------------------------------------------
if [[ "${run_cutadapt}" != "yes" && "${AUTO_PRIMER_TRIM}" == "yes" && -n "${FORWARD_PRIMER}" ]]; then
  [[ -d "${DEMUX_EXPORT}" ]] || { echo "ERROR: demux export dir not found (run 02 first): ${DEMUX_EXPORT}" >&2; exit 1; }
  detect_args=(--dir "${DEMUX_EXPORT}" --mode "${SEQUENCING_MODE}" --forward-primer "${FORWARD_PRIMER}")
  if [[ "${SEQUENCING_MODE}" == "paired" && -n "${REVERSE_PRIMER}" ]]; then
    detect_args+=(--reverse-primer "${REVERSE_PRIMER}")
  fi
  detect_args+=(--detect-primers)
  tmp_env="${PROJECT_DIR}/work/primers.detect.env"
  if python3 "${WORKFLOW_DIR}/bin/estimate_dada2_params.py" "${detect_args[@]}" --output "${tmp_env}"; then
    # shellcheck disable=SC1090
    source "${tmp_env}"
    primer_detected_f="${PRIMER_DETECTED_F:-no}"
    primer_detected_r="${PRIMER_DETECTED_R:-no}"
    if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
      if [[ "${primer_detected_f}" == "yes" && "${primer_detected_r}" == "yes" ]]; then
        run_cutadapt="yes"
        echo "AUTO: both primers detected -> running cutadapt"
      elif [[ "${primer_detected_f}" == "yes" || "${primer_detected_r}" == "yes" ]]; then
        echo "WARNING: asymmetric primer detection (F=${primer_detected_f}, R=${primer_detected_r}); not auto-trimming; DADA2 trim-left will be set per detected read" >&2
      else
        echo "AUTO: no primers detected -> reads assumed already primer-free"
      fi
    else
      if [[ "${primer_detected_f}" == "yes" ]]; then
        run_cutadapt="yes"
        echo "AUTO: forward primer detected -> running cutadapt"
      else
        echo "AUTO: no primer detected -> reads assumed already primer-free"
      fi
    fi
  else
    echo "WARNING: primer detection failed; skipping auto-trim" >&2
  fi
fi

# ---- trim ------------------------------------------------------------------
if [[ "${run_cutadapt}" == "yes" ]]; then
  [[ -n "${FORWARD_PRIMER}" ]] || { echo "ERROR: FORWARD_PRIMER is empty" >&2; exit 1; }
  if [[ "${SEQUENCING_MODE}" == "paired" ]]; then
    [[ -n "${REVERSE_PRIMER}" ]] || { echo "ERROR: REVERSE_PRIMER is empty" >&2; exit 1; }
    qiime cutadapt trim-paired --i-demultiplexed-sequences "${INPUT}" \
      --p-front-f "${FORWARD_PRIMER}" --p-front-r "${REVERSE_PRIMER}" \
      --p-error-rate "${CUTADAPT_ERROR_RATE}" --p-minimum-length "${CUTADAPT_MINIMUM_LENGTH}" \
      --p-cores "${CUTADAPT_THREADS}" --o-trimmed-sequences "${OUTPUT}"
  else
    qiime cutadapt trim-single --i-demultiplexed-sequences "${INPUT}" \
      --p-front "${FORWARD_PRIMER}" --p-error-rate "${CUTADAPT_ERROR_RATE}" \
      --p-minimum-length "${CUTADAPT_MINIMUM_LENGTH}" --p-cores "${CUTADAPT_THREADS}" \
      --o-trimmed-sequences "${OUTPUT}"
  fi
  cutadapt_ran="yes"
else
  cp "${INPUT}" "${OUTPUT}"
  cutadapt_ran="no"
fi

# ---- record decisions for downstream steps (08 auto params, 04 dada2) ------
mkdir -p "$(dirname "${PRIMERS_ENV}")"
{
  printf 'export PRIMER_DETECTED_F=%q\n' "${primer_detected_f}"
  printf 'export PRIMER_DETECTED_R=%q\n' "${primer_detected_r}"
  printf 'export CUTADAPT_RAN=%q\n' "${cutadapt_ran}"
} > "${PRIMERS_ENV}"
echo "Primer decision written to ${PRIMERS_ENV}"
