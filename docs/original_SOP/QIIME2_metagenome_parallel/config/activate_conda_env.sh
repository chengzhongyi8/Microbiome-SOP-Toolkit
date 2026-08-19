#!/usr/bin/env bash
# Purpose: initialize Conda, idempotently activate one configured environment, and verify commands.
# Usage: source activate_conda_env.sh "${ENV_NAME}" command1 [command2 ...]
# Output: active environment and first-use entries in results/software_versions.tsv.
# Software/resources: Conda; negligible resources.

CONDA_REQUESTED_ENV="${1:-}"
[[ -n "${CONDA_REQUESTED_ENV}" ]] || { echo "ERROR: no Conda environment name supplied" >&2; exit 1; }
shift

if [[ -n "${CONDA_MODULE:-}" ]]; then
  command -v module >/dev/null 2>&1 || { echo "ERROR: configured CONDA_MODULE but module command is unavailable" >&2; exit 1; }
  module load "${CONDA_MODULE}"
fi
[[ -f "${CONDA_SH}" ]] || {
  echo "ERROR: 找不到 Conda 初始化脚本：${CONDA_SH}" >&2
  echo "请修改 metagenome/config/conda_envs.sh 中的 CONDA_SH。" >&2
  exit 1
}
source "${CONDA_SH}"
if [[ "${CONDA_DEFAULT_ENV:-}" != "${CONDA_REQUESTED_ENV}" ]]; then
  conda activate "${CONDA_REQUESTED_ENV}"
fi

mkdir -p "${PROJECT_DIR}/results"
CONDA_VERSIONS_FILE="${PROJECT_DIR}/results/software_versions.tsv"
[[ -f "${CONDA_VERSIONS_FILE}" ]] || printf 'software\tconda_env\texecutable\tversion\n' > "${CONDA_VERSIONS_FILE}"
for CONDA_REQUIRED_CMD in "$@"; do
  command -v "${CONDA_REQUIRED_CMD}" >/dev/null 2>&1 || {
    echo "ERROR: 激活 ${CONDA_REQUESTED_ENV} 后仍未找到命令：${CONDA_REQUIRED_CMD}" >&2
    exit 1
  }
  CONDA_CMD_LABEL="$(basename "${CONDA_REQUIRED_CMD}")"
  if ! awk -F '\t' '$1==cmd && $2==env {found=1} END {exit !found}' cmd="${CONDA_CMD_LABEL}" env="${CONDA_REQUESTED_ENV}" "${CONDA_VERSIONS_FILE}"; then
    CONDA_CMD_VERSION="$("${CONDA_REQUIRED_CMD}" --version 2>&1 | head -n 1 || true)"
    [[ -n "${CONDA_CMD_VERSION}" ]] || CONDA_CMD_VERSION="$("${CONDA_REQUIRED_CMD}" -v 2>&1 | head -n 1 || true)"
    [[ -n "${CONDA_CMD_VERSION}" ]] || CONDA_CMD_VERSION="version flag not standardized; record manually"
    printf '%s\t%s\t%s\t%s\n' "${CONDA_CMD_LABEL}" "${CONDA_REQUESTED_ENV}" "$(command -v "${CONDA_REQUIRED_CMD}")" "${CONDA_CMD_VERSION}" >> "${CONDA_VERSIONS_FILE}"
  fi
done

