#!/usr/bin/env bash
# Purpose: initialize Conda and idempotently activate the configured QIIME2 environment.
# Input: CONDA_SH, optional CONDA_MODULE, QIIME2_ENV, PROJECT_DIR from config.sh.
# Output: active environment plus one software_versions.tsv entry per project.
# Software/resources: Conda and qiime; negligible resources.

# Conda activation/deactivation hooks (e.g. conda-forge gxx_linux-64 compilers)
# reference backup variables that may be unset, which breaks under `set -u`.
# Temporarily disable nounset while initializing/activating conda.
set +u

if [[ -n "${CONDA_MODULE:-}" ]]; then
  command -v module >/dev/null 2>&1 || { echo "ERROR: configured CONDA_MODULE but module command is unavailable" >&2; exit 1; }
  module load "${CONDA_MODULE}"
fi

[[ -f "${CONDA_SH}" ]] || {
  echo "ERROR: 找不到 Conda 初始化脚本：${CONDA_SH}" >&2
  echo "请在 config.sh 中把 CONDA_SH 改为服务器上的实际路径。" >&2
  exit 1
}

source "${CONDA_SH}"
if [[ "${CONDA_DEFAULT_ENV:-}" != "${QIIME2_ENV}" ]]; then
  conda activate "${QIIME2_ENV}"
fi
set -u

command -v qiime >/dev/null 2>&1 || {
  echo "ERROR: 激活 ${QIIME2_ENV} 后仍未找到 qiime 命令" >&2
  exit 1
}

if [[ -n "${PROJECT_DIR:-}" ]]; then
  mkdir -p "${PROJECT_DIR}/results"
  versions_file="${PROJECT_DIR}/results/software_versions.tsv"
  [[ -f "${versions_file}" ]] || printf 'software\tconda_env\texecutable\tversion\n' > "${versions_file}"
  if ! awk -F '\t' '$1=="qiime" && $2==env {found=1} END {exit !found}' env="${QIIME2_ENV}" "${versions_file}"; then
    qiime_version="$(qiime --version 2>&1 | head -n 1 || true)"
    printf 'qiime\t%s\t%s\t%s\n' "${QIIME2_ENV}" "$(command -v qiime)" "${qiime_version}" >> "${versions_file}"
  fi
fi

