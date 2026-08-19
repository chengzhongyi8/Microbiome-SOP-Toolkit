#!/usr/bin/env bash
# bin/lib.sh — 共享函数库（被模块脚本 source）
# 目前包含：run_pool —— 不依赖 GNU parallel 的轻量任务池。
#
# run_pool <并发数> <worker脚本> [item...]
#   对每个 item 调起一个 `bash <worker> <item>`，最多同时跑 <并发数> 个；
#   任一任务失败则整个函数返回非 0（配合 set -e 会让模块失败退出）。
# 说明：worker 的 stdout 直接输出；如需按任务分开收集输出，请调用方自行重定向。
set -euo pipefail

run_pool() {
  local n="$1"; shift
  local worker="$1"; shift
  local items=("$@")
  local pids=() failed=0 i pid
  [[ "${n}" -ge 1 ]] || n=1

  for i in "${!items[@]}"; do
    bash "${worker}" "${items[$i]}" &
    pids+=($!)
    if [[ "${#pids[@]}" -ge "${n}" ]]; then
      for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
      pids=()
    fi
  done
  if [[ "${#pids[@]}" -gt 0 ]]; then
    for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
  fi
  [[ "${failed}" -eq 0 ]]
}

# run_py3 <script> [args...]：用可用的 python3 运行脚本
# 优先当前 PATH 里的 python3；若当前 conda 环境没有（如 eggnog 环境），
# 退回 conda base 的 python3（服务器 base 一定有）。
resolve_python3() {
  if command -v python3 >/dev/null 2>&1; then command -v python3; return 0; fi
  if command -v python >/dev/null 2>&1 && \
     python -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
    command -v python; return 0
  fi
  local base
  if [[ -n "${CONDA_SH:-}" && -f "${CONDA_SH}" ]]; then
    base="$(source "${CONDA_SH}" 2>/dev/null && conda info --base 2>/dev/null | tr -d '\r' | tail -n 1)"
    if [[ -n "${base}" && -x "${base}/bin/python3" ]]; then echo "${base}/bin/python3"; return 0; fi
  fi
  echo "ERROR: 找不到 python3（当前 PATH 和 conda base 都没有）" >&2
  return 1
}

run_py3() {
  local py
  py="$(resolve_python3)" || return 1
  "${py}" "$@"
}

# resolve_tool <VAR>：返回工具实际可执行路径
#   - 变量值含 "/" 且文件存在 -> 原样返回
#   - 否则回退到 PATH 里的命令 -> 返回绝对路径
#   - 都找不到 -> 打印 ERROR 并返回非 0
resolve_tool() {
  local v="$1"
  local p
  p="${!v:-}"
  if [[ "${p}" == */* && -x "${p}" ]]; then echo "${p}"; return 0; fi
  local found
  found="$(command -v "${p}" 2>/dev/null || true)"
  if [[ -z "${found}" && "${p}" == */* ]]; then
    # 配置的是绝对路径但不存在时，再按命令名在 PATH 里找
    found="$(command -v "$(basename "${p}")" 2>/dev/null || true)"
  fi
  if [[ -n "${found}" ]]; then echo "${found}"; return 0; fi
  echo "ERROR: ${v} 找不到（配置: ${p}，且不在 PATH 中）" >&2
  return 1
}
