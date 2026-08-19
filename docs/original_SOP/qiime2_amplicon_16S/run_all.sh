#!/usr/bin/env bash
# Purpose: one-command QIIME2 amplicon pipeline.
#
#   bash run_all.sh --fastq-dir /data/fastq --region 16S_V4 --classifier /db/silva138.qza
#
# You only need to tell it where your reads are, which region you amplified
# (or your primer sequences), and where your classifier is. Everything else is
# resolved automatically (primers from primers.tsv, DADA2 trim/trunc from the
# quality profile, metadata auto-generated if absent, outputs into PROJECT_DIR).
#
# Options (override config.sh / config.local.sh):
#   --fastq-dir DIR          directory containing *.fastq.gz / *.fq.gz (top level)
#   --project-dir DIR        output project directory (default: config value)
#   --region NAME            e.g. 16S_V4, 16S_V3V4, ITS1, ITS2, 18S_V4, COI
#   --forward-primer SEQ     overrides the region default
#   --reverse-primer SEQ     overrides the region default
#   --classifier PATH        .qza classifier (or set --classifier-dir)
#   --classifier-dir DIR     auto-discover a classifier in DIR
#   --mode paired|single     default: paired
#   --metadata PATH          sample metadata TSV (default: auto-generate)
#   --auto-trunc yes|no      auto-estimate DADA2 truncation (default: yes)
#   --auto-primer-trim yes|no (default: yes)
#   --quality-threshold N    mean-Q cutoff for auto truncation (default 20)
#   --min-trunc-len N        (default 50)
#   --max-ee N               DADA2 max expected errors per read (default 2.0)
#   --trim-left-f N          DADA2 trim-left forward (manual override; default auto)
#   --trim-left-r N          DADA2 trim-left reverse (manual override; default auto)
#   --trunc-len-f N          DADA2 trunc-len forward (manual override; default auto)
#   --trunc-len-r N          DADA2 trunc-len reverse (manual override; default auto)
#                            Manual DADA2 params are written per-project to
#                            <project>/work/dada2_params.env, never into the global
#                            config.local.sh, so different projects don't pollute each other.
#   --expected-amplicon-len N  insert length WITHOUT primers (for overlap check)
#   --min-samples N          prevalence filter (default: none)
#   --target-domain NAME     e.g. Bacteria (default: Bacteria)
#   --conda-sh PATH          full path to conda.sh on the server
#   --qiime2-env NAME        (default: qiime2)
#   --microeco-env NAME      (default: microeco)
#   --threads N              sets cutadapt/dada2/classifier/phylogeny threads
#   --resume yes|no          skip steps whose outputs exist (default: yes)
#   --force                  rerun everything, ignoring resume markers
#   --init-only              only write config.local.sh, then exit
#   --no-init                do not (re)write config.local.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
# 记住 config.sh 的 DADA2 参数默认值：项目 env 只接受"命令行显式传入"或"config.sh 默认"，
# 不继承全局 config.local.sh 里可能残留的旧项目值（避免跨项目泄漏）。
TRIM_LEFT_F_DEFAULT="${TRIM_LEFT_F:-}"
TRIM_LEFT_R_DEFAULT="${TRIM_LEFT_R:-}"
TRUNC_LEN_F_DEFAULT="${TRUNC_LEN_F:-}"
TRUNC_LEN_R_DEFAULT="${TRUNC_LEN_R:-}"
MAX_EE_DEFAULT="${MAX_EE}"
TRIM_LEFT_F_CLI=""; TRIM_LEFT_R_CLI=""; TRUNC_LEN_F_CLI=""; TRUNC_LEN_R_CLI=""; MAX_EE_CLI=""
[[ -f "${SCRIPT_DIR}/config.local.sh" ]] && source "${SCRIPT_DIR}/config.local.sh"

usage() {
  sed -n '2,40p' "${SCRIPT_DIR}/run_all.sh" | sed 's/^# \{0,1\}//'
  exit 0
}

FORCE="no"
DO_INIT="no"
NO_INIT="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fastq-dir)          FASTQ_DIR="${2:?missing value for --fastq-dir}"; shift 2 ;;
    --project-dir)        PROJECT_DIR="${2:?missing value for --project-dir}"; shift 2 ;;
    --region)             REGION="${2:?missing value for --region}"; shift 2 ;;
    --forward-primer)     FORWARD_PRIMER="${2:?missing value for --forward-primer}"; shift 2 ;;
    --reverse-primer)     REVERSE_PRIMER="${2:?missing value for --reverse-primer}"; shift 2 ;;
    --classifier)         CLASSIFIER="${2:?missing value for --classifier}"; shift 2 ;;
    --classifier-dir)     CLASSIFIER_DIR="${2:?missing value for --classifier-dir}"; shift 2 ;;
    --mode)               SEQUENCING_MODE="${2:?missing value for --mode}"; shift 2 ;;
    --metadata)           METADATA_FILE="${2:?missing value for --metadata}"; shift 2 ;;
    --auto-trunc)         AUTO_TRUNC="${2:?missing value for --auto-trunc}"; shift 2 ;;
    --auto-primer-trim)   AUTO_PRIMER_TRIM="${2:?missing value for --auto-primer-trim}"; shift 2 ;;
    --quality-threshold)  QUALITY_THRESHOLD="${2:?missing value for --quality-threshold}"; shift 2 ;;
    --min-trunc-len)      MIN_TRUNC_LEN="${2:?missing value for --min-trunc-len}"; shift 2 ;;
    --max-ee)              MAX_EE="${2:?missing value for --max-ee}"; MAX_EE_CLI="${2}"; shift 2 ;;
    --trim-left-f)         TRIM_LEFT_F="${2:?missing value for --trim-left-f}"; TRIM_LEFT_F_CLI="${2}"; shift 2 ;;
    --trim-left-r)         TRIM_LEFT_R="${2:?missing value for --trim-left-r}"; TRIM_LEFT_R_CLI="${2}"; shift 2 ;;
    --trunc-len-f)         TRUNC_LEN_F="${2:?missing value for --trunc-len-f}"; TRUNC_LEN_F_CLI="${2}"; shift 2 ;;
    --trunc-len-r)         TRUNC_LEN_R="${2:?missing value for --trunc-len-r}"; TRUNC_LEN_R_CLI="${2}"; shift 2 ;;
    --expected-amplicon-len) EXPECTED_AMPLICON_LENGTH="${2:?missing value for --expected-amplicon-len}"; shift 2 ;;
    --min-samples)        MIN_SAMPLES="${2:?missing value for --min-samples}"; shift 2 ;;
    --target-domain)      TARGET_DOMAIN="${2:?missing value for --target-domain}"; shift 2 ;;
    --conda-sh)           CONDA_SH="${2:?missing value for --conda-sh}"; shift 2 ;;
    --qiime2-env)         QIIME2_ENV="${2:?missing value for --qiime2-env}"; shift 2 ;;
    --microeco-env)       R_MICROECO_ENV="${2:?missing value for --microeco-env}"; shift 2 ;;
    --threads)            CUTADAPT_THREADS="${2}"; DADA2_THREADS="${2}"; CLASSIFIER_JOBS="${2}"; PHYLOGENY_THREADS="${2}"; shift 2 ;;
    --resume)             RESUME="${2:?missing value for --resume}"; shift 2 ;;
    --force)              FORCE="yes"; shift ;;
    --init-only)          DO_INIT="yes"; shift ;;
    --no-init)            NO_INIT="yes"; shift ;;
    -h|--help)            usage ;;
    *) echo "ERROR: unknown option: $1" >&2; usage ;;
  esac
done

# ---- validate basics --------------------------------------------------------
[[ "${SEQUENCING_MODE}" == "paired" || "${SEQUENCING_MODE}" == "single" ]] || {
  echo "ERROR: --mode must be paired or single" >&2; exit 1; }
[[ "${PROJECT_DIR}" == /* ]] || { echo "ERROR: PROJECT_DIR must be absolute: ${PROJECT_DIR}" >&2; exit 1; }
[[ "${PROJECT_DIR}" == "/path/to/qiime2_project" ]] && {
  echo "ERROR: set --project-dir (or PROJECT_DIR in config.local.sh)" >&2; exit 1; }
[[ -d "${FASTQ_DIR}" ]] || { echo "ERROR: FASTQ_DIR not found: ${FASTQ_DIR}" >&2; exit 1; }

# ---- resolve region -> primers ---------------------------------------------
if [[ -n "${REGION}" && -f "${SCRIPT_DIR}/primers.tsv" ]]; then
  norm="$(printf '%s' "${REGION}" | tr '[:lower:]' '[:upper:]' | tr -d ' _-')"
  row="$(awk -F '\t' -v want="${norm}" '!/^#/ {
      r=$1; a=$2; gsub(/[ _-]/, "", r); gsub(/[ _-]/, "", a);
      n=split(a, aliases, ",");
      if (toupper(r)==want) {print; exit}
      for (i=1; i<=n; i++) if (toupper(aliases[i])==want) {print; exit}
    }' "${SCRIPT_DIR}/primers.tsv")"
  if [[ -n "${row}" ]]; then
    IFS=$'\t' read -r _rname _ralias r_fwd r_rev r_min r_max _rkw _rnotes <<< "${row}"
    FORWARD_PRIMER="${FORWARD_PRIMER:-${r_fwd}}"
    REVERSE_PRIMER="${REVERSE_PRIMER:-${r_rev}}"
    EXPECTED_AMPLICON_LENGTH="${EXPECTED_AMPLICON_LENGTH:-$(( (r_min + r_max) / 2 ))}"
    echo "Resolved REGION=${REGION}: F=${FORWARD_PRIMER} R=${REVERSE_PRIMER} expected_len=${EXPECTED_AMPLICON_LENGTH}"
  else
    echo "WARNING: REGION '${REGION}' not in primers.tsv; supply --forward-primer/--reverse-primer" >&2
  fi
fi

# ---- write per-project config.local.sh -------------------------------------
if [[ "${NO_INIT}" != "yes" ]]; then
  CFG="${SCRIPT_DIR}/config.local.sh"
  {
    echo "# Auto-generated by run_all.sh on $(date '+%F %T')"
    echo "# Per-project overrides; edit for this project or re-run run_all.sh."
    printf 'CONDA_SH=%q\n' "${CONDA_SH}"
    printf 'CONDA_MODULE=%q\n' "${CONDA_MODULE:-}"
    printf 'QIIME2_ENV=%q\n' "${QIIME2_ENV}"
    printf 'R_MICROECO_ENV=%q\n' "${R_MICROECO_ENV}"
    printf 'RUN_FILE2MECO_VALIDATION=%q\n' "${RUN_FILE2MECO_VALIDATION}"
    printf 'PROJECT_DIR=%q\n' "${PROJECT_DIR}"
    printf 'FASTQ_DIR=%q\n' "${FASTQ_DIR}"
    printf 'METADATA_FILE=%q\n' "${METADATA_FILE:-}"
    printf 'AUTO_GENERATE_METADATA=%q\n' "${AUTO_GENERATE_METADATA}"
    printf 'REGION=%q\n' "${REGION:-}"
    printf 'SEQUENCING_MODE=%q\n' "${SEQUENCING_MODE}"
    printf 'CLASSIFIER=%q\n' "${CLASSIFIER:-}"
    printf 'CLASSIFIER_DIR=%q\n' "${CLASSIFIER_DIR:-}"
    printf 'RUN_CUTADAPT=%q\n' "${RUN_CUTADAPT}"
    printf 'AUTO_PRIMER_TRIM=%q\n' "${AUTO_PRIMER_TRIM}"
    printf 'FORWARD_PRIMER=%q\n' "${FORWARD_PRIMER:-}"
    printf 'REVERSE_PRIMER=%q\n' "${REVERSE_PRIMER:-}"
    printf 'CUTADAPT_ERROR_RATE=%q\n' "${CUTADAPT_ERROR_RATE}"
    printf 'CUTADAPT_MINIMUM_LENGTH=%q\n' "${CUTADAPT_MINIMUM_LENGTH}"
    printf 'CUTADAPT_THREADS=%q\n' "${CUTADAPT_THREADS}"
    printf 'AUTO_TRUNC=%q\n' "${AUTO_TRUNC}"
    printf 'QUALITY_THRESHOLD=%q\n' "${QUALITY_THRESHOLD}"
    printf 'MIN_TRUNC_LEN=%q\n' "${MIN_TRUNC_LEN}"
    printf 'EXPECTED_AMPLICON_LENGTH=%q\n' "${EXPECTED_AMPLICON_LENGTH:-}"
    printf 'MAX_ESTIMATOR_SAMPLES=%q\n' "${MAX_ESTIMATOR_SAMPLES}"
    printf 'MAX_ESTIMATOR_READS=%q\n' "${MAX_ESTIMATOR_READS}"
    printf 'DADA2_THREADS=%q\n' "${DADA2_THREADS}"
    printf 'MIN_SAMPLES=%q\n' "${MIN_SAMPLES:-}"
    printf 'TARGET_DOMAIN=%q\n' "${TARGET_DOMAIN:-}"
    printf 'EXCLUDE_MITOCHONDRIA=%q\n' "${EXCLUDE_MITOCHONDRIA}"
    printf 'EXCLUDE_CHLOROPLAST=%q\n' "${EXCLUDE_CHLOROPLAST}"
    printf 'EXCLUDE_ARCHAEA=%q\n' "${EXCLUDE_ARCHAEA}"
    printf 'EXCLUDE_EUKARYOTA=%q\n' "${EXCLUDE_EUKARYOTA}"
    printf 'EXCLUDE_UNASSIGNED_DOMAIN=%q\n' "${EXCLUDE_UNASSIGNED_DOMAIN}"
    printf 'CLASSIFIER_JOBS=%q\n' "${CLASSIFIER_JOBS}"
    printf 'PHYLOGENY_THREADS=%q\n' "${PHYLOGENY_THREADS}"
    printf 'RUN_CORE_METRICS=%q\n' "${RUN_CORE_METRICS}"
    printf 'SAMPLING_DEPTH=%q\n' "${SAMPLING_DEPTH:-}"
    printf 'RUN_ALPHA_RAREFACTION=%q\n' "${RUN_ALPHA_RAREFACTION}"
    printf 'ALPHA_MAX_DEPTH=%q\n' "${ALPHA_MAX_DEPTH:-}"
    printf 'RUN_TAXA_BARPLOT=%q\n' "${RUN_TAXA_BARPLOT}"
    printf 'RESUME=%q\n' "${RESUME}"
    printf 'CHECK_GZIP_INTEGRITY=%q\n' "${CHECK_GZIP_INTEGRITY}"
    printf 'COUNT_READS=%q\n' "${COUNT_READS}"
  } > "${CFG}"
  echo "Wrote per-project config: ${CFG}"
fi

# Per-project DADA2 parameter overrides. Only explicit CLI values (or config.sh
# defaults) go into the project env; stale values in the global config.local.sh
# are intentionally ignored so projects never pollute each other.
TRIM_LEFT_F="${TRIM_LEFT_F_CLI:-${TRIM_LEFT_F_DEFAULT}}"
TRIM_LEFT_R="${TRIM_LEFT_R_CLI:-${TRIM_LEFT_R_DEFAULT}}"
TRUNC_LEN_F="${TRUNC_LEN_F_CLI:-${TRUNC_LEN_F_DEFAULT}}"
TRUNC_LEN_R="${TRUNC_LEN_R_CLI:-${TRUNC_LEN_R_DEFAULT}}"
MAX_EE="${MAX_EE_CLI:-${MAX_EE_DEFAULT}}"
mkdir -p "${PROJECT_DIR}/work"
{
  echo "# Auto-generated by run_all.sh on $(date '+%F %T')"
  echo "# Per-project DADA2 parameter overrides. Edit here or pass --trim-left-*/--trunc-len-* to run_all.sh."
  printf 'export TRIM_LEFT_F=%q\n' "${TRIM_LEFT_F:-}"
  printf 'export TRIM_LEFT_R=%q\n' "${TRIM_LEFT_R:-}"
  printf 'export TRUNC_LEN_F=%q\n' "${TRUNC_LEN_F:-}"
  printf 'export TRUNC_LEN_R=%q\n' "${TRUNC_LEN_R:-}"
  printf 'export MAX_EE=%q\n' "${MAX_EE}"
} > "${PROJECT_DIR}/work/dada2_params.env"
echo "Wrote per-project DADA2 params: ${PROJECT_DIR}/work/dada2_params.env"

if [[ "${DO_INIT}" == "yes" ]]; then
  echo "init-only: config written, pipeline not run."
  echo "Next: bash ${SCRIPT_DIR}/run_all.sh   (or edit ${SCRIPT_DIR}/config.local.sh first)"
  exit 0
fi

mkdir -p "${PROJECT_DIR}/results" "${PROJECT_DIR}/work/tmp"
# 让 q2cli 调试日志（qiime2-q2cli-err-*.log）落在项目目录而非计算节点的 /tmp，
# 失败后可以直接在项目里查看完整报错。
export TMPDIR="${PROJECT_DIR}/work/tmp"
LOG="${PROJECT_DIR}/results/pipeline.log"
echo "=== run_all.sh started $(date '+%F %T') ===" | tee -a "${LOG}"

marker_for() {
  case "$1" in
    00) printf '%s' "${PROJECT_DIR}/results/qc/input_check.ok" ;;
    01) printf '%s' "${PROJECT_DIR}/work/manifest.tsv" ;;
    02) printf '%s' "${PROJECT_DIR}/results/qc/demux.qzv" ;;
    03) printf '%s' "${PROJECT_DIR}/work/demux-for-dada2.qza" ;;
    08) printf '%s' "${PROJECT_DIR}/work/dada2_auto.env" ;;
    04) printf '%s' "${PROJECT_DIR}/results/dada2/.step04.done" ;;
    05) printf '%s' "${PROJECT_DIR}/results/final/taxonomy.qza" ;;
    06) printf '%s' "${PROJECT_DIR}/results/final/rooted-tree.qza" ;;
    07) printf '%s' "${PROJECT_DIR}/results/microeco_input/file2meco_validation.tsv" ;;
    09) printf '%s' "${PROJECT_DIR}/results/summary/summary_report.tsv" ;;
    *)  printf '' ;;
  esac
}

run_step() {
  local num="$1" script="$2"
  local marker
  marker="$(marker_for "${num}")"
  if [[ "${FORCE}" != "yes" && "${RESUME}" == "yes" && -n "${marker}" && -e "${marker}" ]]; then
    echo "[skip] step ${num} (${script}) output exists: ${marker}" | tee -a "${LOG}"
    return 0
  fi
  echo "[run ] step ${num} (${script}) $(date '+%F %T')" | tee -a "${LOG}"
  if ! bash "${SCRIPT_DIR}/${script}" 2>&1 | tee -a "${LOG}"; then
    echo "ERROR: step ${num} (${script}) failed; see ${LOG}" | tee -a "${LOG}" >&2
    exit 1
  fi
  echo "[done] step ${num} (${script})" | tee -a "${LOG}"
}

run_step 00 00_check_input.sh
run_step 01 01_make_manifest.sh
run_step 02 02_import_and_qc.sh
run_step 03 03_cutadapt_optional.sh
run_step 08 08_auto_dada2_params.sh
run_step 04 04_dada2.sh
run_step 05 05_taxonomy_filter.sh
run_step 06 06_phylogeny.sh
run_step 07 07_export_microeco.sh
run_step 09 09_summary.sh

echo
echo "=== Pipeline finished $(date '+%F %T') ===" | tee -a "${LOG}"
echo "Results:"
echo "  ${PROJECT_DIR}/results/summary/README_summary.md"
echo "  ${PROJECT_DIR}/results/microeco_input/"
echo "  ${PROJECT_DIR}/results/final/"
echo "Log: ${LOG}"
