#!/usr/bin/env bash
# Static and CLI checks — no bioinformatics software required.
#
#   1. bash -n on every shell script
#   2. python compile() on every Python script
#   3. YAML sanity of envs/ and config/ (python: well-formedness via yaml if
#      available, otherwise a lightweight structural check)
#   4. CLI: --help / list / --version of every entry point
#   5. run_16s.sh --init-only smoke test (writes per-project config)
#   6. yaml2env roundtrip on the example configs
#
#   bash tests/run_static_checks.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# ---- 1. bash -n -------------------------------------------------------------
echo "[test] bash -n on all shell scripts"
sh_failed=0
while IFS= read -r f; do
  if ! bash -n "${f}" 2> /dev/null; then
    echo "  bash -n FAILED: ${f}"
    sh_failed=$((sh_failed+1))
  fi
done < <(find "${ROOT}" -type f \( -name '*.sh' -o -name 'microbiome-toolkit' -o -name 'qiime2-sop' -o -name 'mg-sop' \) -not -path '*/docs/original_SOP/*')
if [[ "${sh_failed}" -eq 0 ]]; then ok "bash -n: all shell scripts parse"; else fail "bash -n: ${sh_failed} files failed"; fi

# ---- 2. python compile --------------------------------------------------------
echo "[test] python compile() on all Python scripts"
py_failed=0
while IFS= read -r f; do
  if ! python3 -c 'import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)' "${f}" 2> /dev/null; then
    echo "  py compile FAILED: ${f}"
    py_failed=$((py_failed+1))
  fi
done < <(find "${ROOT}" -type f -name '*.py' -not -path '*/docs/original_SOP/*' -not -path '*/tests/stub_bin/*')
if [[ "${py_failed}" -eq 0 ]]; then ok "python compile: all scripts parse"; else fail "python compile: ${py_failed} failed"; fi
# stub_bin scripts share one implementation
python3 -c 'import py_compile; py_compile.compile("'"${HERE}"'/stub_bin/stub.py", doraise=True)' \
  && ok "stub.py compiles" || fail "stub.py compile failed"

# ---- 3. YAML sanity -------------------------------------------------------------
echo "[test] YAML sanity of envs/ and config/"
y_failed=0
if python3 -c 'import yaml' 2>/dev/null; then
  for f in "${ROOT}"/envs/*.yml "${ROOT}"/config/*.yaml; do
    [[ -f "${f}" ]] || continue
    python3 - "$f" <<'PY' || { echo "  YAML parse FAILED: ${f}"; y_failed=$((y_failed+1)); }
import sys, yaml
try:
    yaml.safe_load(open(sys.argv[1]))
except Exception as e:
    sys.stderr.write(str(e) + "\n")
    sys.exit(1)
PY
  done
  if [[ "${y_failed}" -eq 0 ]]; then ok "all envs/config YAML parse (pyyaml)"; else fail "YAML: ${y_failed} failed"; fi
else
  # fallback: structural checks (balanced indentation, key: value pattern)
  for f in "${ROOT}"/config/*.yaml; do
    grep -Eq '^[A-Za-z0-9_.-]+:' "${f}" && ok "config ${f##*/} has keys" || { fail "config ${f##*/} looks empty"; y_failed=$((y_failed+1)); }
  done
  if [[ "${y_failed}" -eq 0 ]]; then ok "config YAML structural check (pyyaml not available)"; fi
fi

# ---- 4. CLI help ----------------------------------------------------------------
echo "[test] CLI entry points"
"${ROOT}/bin/microbiome-toolkit" --help > /dev/null 2>&1 && ok "microbiome-toolkit --help" || fail "microbiome-toolkit --help"
"${ROOT}/bin/microbiome-toolkit" --version | grep -q "1.0.0" && ok "microbiome-toolkit --version" || fail "--version"
out="$("${ROOT}/bin/microbiome-toolkit" list 2>&1)" && grep -q "metagenome" <<< "${out}" && ok "microbiome-toolkit list" || fail "list"
"${ROOT}/bin/microbiome-toolkit" 16s --help > /dev/null 2>&1 && ok "16s --help" || fail "16s --help"
"${ROOT}/bin/microbiome-toolkit" metagenome --help > /dev/null 2>&1 && ok "metagenome --help" || fail "metagenome --help"
bash "${ROOT}/bin/run_16s.sh" --help > /dev/null 2>&1 && ok "run_16s.sh --help" || fail "run_16s.sh --help"
bash "${ROOT}/bin/run_metagenome.sh" --help > /dev/null 2>&1 && ok "run_metagenome.sh --help" || fail "run_metagenome.sh --help"
"${ROOT}/bin/qiime2-sop" -h > /dev/null 2>&1 && ok "qiime2-sop -h" || fail "qiime2-sop -h"
"${ROOT}/bin/mg-sop" -h > /dev/null 2>&1 && ok "mg-sop -h" || fail "mg-sop -h"

# ---- 5. run_16s --init-only smoke ------------------------------------------------
echo "[test] run_16s.sh --init-only"
mkdir -p "${TMP}/fastq"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_R1.fastq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${TMP}/fastq/S1_R2.fastq.gz"
bash "${ROOT}/bin/run_16s.sh" \
    --input "${TMP}/fastq" \
    --output "${TMP}/proj16" \
    --region 16S_V4 \
    --conda-sh /path/to/conda.sh \
    --init-only > /dev/null 2>&1
[[ -s "${TMP}/proj16/work/config.local.sh" ]] && ok "16s per-project config written" || fail "16s config.local.sh missing"
[[ -s "${TMP}/proj16/work/dada2_params.env" ]] && ok "16s dada2_params.env written" || fail "dada2_params.env missing"

# ---- 5b. 16S steps 00-01 smoke (no QIIME2 needed) -----------------------------
echo "[test] 16s steps 00+01 (manifest creation, no QIIME2)"
T2="${TMP}/s16"
mkdir -p "${T2}/fastq"
printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > "${T2}/fastq/S1_R1.fastq.gz"
printf '@r2\nACGTACGT\n+\nIIIIIIII\n' > "${T2}/fastq/S1_R2.fastq.gz"
bash "${ROOT}/bin/run_16s.sh" --input "${T2}/fastq" --output "${T2}/proj" \
    --region 16S_V4 --conda-sh /path/to/conda.sh --init-only > /dev/null 2>&1
bash "${ROOT}/workflows/16s/run_qc.sh" --project-dir "${T2}/proj" > /dev/null 2>&1 || true
[[ -s "${T2}/proj/work/manifest.tsv" ]] && ok "16s manifest created" || fail "16s manifest missing"
grep -q "S1" "${T2}/proj/work/manifest.tsv" && ok "16s manifest has sample S1" || fail "16s manifest sample missing"

# ---- 6. yaml2env roundtrip --------------------------------------------------------
echo "[test] yaml2env roundtrip"
python3 "${ROOT}/bin/yaml2env.py" 16s "${ROOT}/config/16s_config.example.yaml" > "${TMP}/e16.env" 2>/dev/null
grep -q 'export FASTQ_DIR=' "${TMP}/e16.env" && ok "yaml2env 16s: FASTQ_DIR" || fail "yaml2env 16s FASTQ_DIR"
grep -q 'export TRIM_LEFT_F=' "${TMP}/e16.env" && ok "yaml2env 16s: TRIM_LEFT_F" || fail "yaml2env 16s TRIM_LEFT_F"
python3 "${ROOT}/bin/yaml2env.py" metagenome "${ROOT}/config/metagenome_config.example.yaml" > "${TMP}/emg.env" 2>/dev/null
grep -q 'export PROJECT_DIR=' "${TMP}/emg.env" && ok "yaml2env mg: PROJECT_DIR" || fail "yaml2env mg PROJECT_DIR"
grep -q 'export GTDBTK_DATA_PATH=' "${TMP}/emg.env" && ok "yaml2env mg: GTDBTK_DATA_PATH" || fail "yaml2env mg GTDBTK"

echo
echo "=============================="
echo "static checks result: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
