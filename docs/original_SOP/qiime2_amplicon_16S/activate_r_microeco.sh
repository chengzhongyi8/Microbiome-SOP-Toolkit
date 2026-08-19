#!/usr/bin/env bash
# Purpose: activate the separate R environment used only for file2meco validation.
# Input: initialized Conda plus R_MICROECO_ENV and PROJECT_DIR from config.sh.
# Output: active R environment and a version-log entry.
# Software/resources: R, file2meco, microeco; negligible resources.

# Same `set -u` workaround as activate_qiime2.sh (conda hooks are not nounset-safe).
set +u
[[ -f "${CONDA_SH}" ]] || { echo "ERROR: 找不到 Conda 初始化脚本：${CONDA_SH}" >&2; exit 1; }
source "${CONDA_SH}"
if [[ "${CONDA_DEFAULT_ENV:-}" != "${R_MICROECO_ENV}" ]]; then
  conda activate "${R_MICROECO_ENV}"
fi
set -u
command -v Rscript >/dev/null 2>&1 || { echo "ERROR: ${R_MICROECO_ENV} 中未找到 Rscript" >&2; exit 1; }
Rscript -e 'stopifnot(requireNamespace("file2meco", quietly=TRUE), requireNamespace("microeco", quietly=TRUE))'

mkdir -p "${PROJECT_DIR}/results"
versions_file="${PROJECT_DIR}/results/software_versions.tsv"
[[ -f "${versions_file}" ]] || printf 'software\tconda_env\texecutable\tversion\n' > "${versions_file}"
if ! awk -F '\t' '$1=="R/file2meco" && $2==env {found=1} END {exit !found}' env="${R_MICROECO_ENV}" "${versions_file}"; then
  r_version="$(Rscript -e 'cat(as.character(getRversion()))')"
  file2meco_version="$(Rscript -e 'cat(as.character(packageVersion("file2meco")))')"
  printf 'R/file2meco\t%s\t%s\tR %s; file2meco %s\n' "${R_MICROECO_ENV}" "$(command -v Rscript)" "${r_version}" "${file2meco_version}" >> "${versions_file}"
fi
