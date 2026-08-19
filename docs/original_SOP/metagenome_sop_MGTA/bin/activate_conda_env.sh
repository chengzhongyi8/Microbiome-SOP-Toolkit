#!/usr/bin/env bash
# Purpose: initialize Conda, idempotently activate one configured environment, and verify commands.
# Usage: source bin/activate_conda_env.sh "${ENV_NAME}" command1 [command2 ...]
# Output: active environment and first-use entries in ${RESULT_DIR}/software_versions.tsv.
# Software/resources: Conda; negligible resources.
set -euo pipefail

CONDA_REQUESTED_ENV="${1:-}"
[[ -n "${CONDA_REQUESTED_ENV}" ]] || { echo "ERROR: no Conda environment name supplied" >&2; exit 1; }
shift

# conda 的 activate/deactivate 脚本会引用 CONDA_BACKUP_* 等未定义变量，
# 与脚本的 set -u(nounset) 冲突会直接报 "unbound variable" 退出，
# 所以在调用 conda 时临时关闭 nounset（这是 conda+set -u 的标准兼容做法）。
if [[ -n "${CONDA_MODULE:-}" ]]; then
  command -v module >/dev/null 2>&1 || { echo "ERROR: configured CONDA_MODULE but module command is unavailable" >&2; exit 1; }
  set +u
  module load "${CONDA_MODULE}"
  set -u
fi
[[ -f "${CONDA_SH}" ]] || {
  echo "ERROR: 找不到 Conda 初始化脚本：${CONDA_SH}" >&2
  echo "请在 metagenome_sop/config.sh 中修改 CONDA_SH（服务器上 conda info --base 得到）。" >&2
  exit 1
}
source "${CONDA_SH}"
if [[ "${CONDA_DEFAULT_ENV:-}" != "${CONDA_REQUESTED_ENV}" ]]; then
  set +u
  conda activate "${CONDA_REQUESTED_ENV}"
  set -u
fi

mkdir -p "${RESULT_DIR:-${PROJECT_DIR}/results}"
CONDA_VERSIONS_FILE="${RESULT_DIR:-${PROJECT_DIR}/results}/software_versions.tsv"
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
