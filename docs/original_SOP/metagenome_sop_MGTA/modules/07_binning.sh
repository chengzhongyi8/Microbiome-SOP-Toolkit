#!/usr/bin/env bash
# ============================================================================
# 07_binning.sh — MAG binning（底层工具直跑，绕开 metaWRAP 不认 gz 的问题）
#
# 输入:
#   ${WORK_DIR}/binning/<asm_id>.fa         (>= BIN_MIN_CONTIG_LEN，02 生成)
#   ${WORK_DIR}/qc/clean/<sample>_{1,2}.fq.gz   (gz 原始文件，原生读取，零解压)
# 输出:
#   ${RESULT_DIR}/mags/refined_bins/*.fa
#   ${RESULT_DIR}/mags/drep/dereplicated_genomes/*.fa
#   ${RESULT_DIR}/mags/checkm2/quality_report.tsv
#   ${RESULT_DIR}/mags/MAG_list.txt / MAG_quality.tsv
#
# 逻辑:
#   bowtie2(原生支持 gz) 比对 -> samtools BAM -> jgi_summarize_bam_contig_depths
#   -> MetaBAT2 / MaxBin2 / CONCOCT 分箱（按 MAG_BINNERS 选择）
#   -> (可选) metawrap bin_refinement 整合(不涉及 reads，无 gz 问题)
#   -> dRep 去冗余 -> CheckM2 质检
# 注意:
#   - 全程 reads 用 gz，零解压、零额外空间；
#   - BAM 是中间文件，深度/CONCOCT 用完后自动删除省空间。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

SAMPLES_TSV="${WORK_DIR}/samples.tsv"
CLEAN_DIR="${WORK_DIR}/qc/clean"
BIN_CONTIGS="${WORK_DIR}/binning"
BIN_WORK="${WORK_DIR}/binning/native"
MAG_RESULT="${RESULT_DIR}/mags"

[[ "${BINNING_TOOL:-none}" == "none" ]] && { echo "binning 已跳过 (--binning none)"; exit 0; }
[[ "${BINNING_TOOL}" == "metawrap" ]] || { echo "ERROR: --binning 必须是 metawrap|none" >&2; exit 1; }
mkdir -p "${MAG_RESULT}"

SAMPLES=(); while IFS= read -r l; do SAMPLES+=("$l"); done < <(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!="" {print $1}' "${SAMPLES_TSV}")
[[ -d "${BIN_CONTIGS}" ]] || { echo "ERROR: ${BIN_CONTIGS} 不存在（先运行 02_assembly）" >&2; exit 1; }
[[ "${#SAMPLES[@]}" -gt 0 ]] || { echo "ERROR: 没有样本" >&2; exit 1; }

# 解析组装 -> 样本 的对应关系
samples_of_asm() {   # 输出某组装对应的样本名（每行一个）
  local asm="$1" sid gid gg
  for s in "${SAMPLES[@]}"; do
    [[ "${s}" == "${asm}" ]] && { echo "${s}"; return; }
  done
  if [[ "${asm}" == "coassembly" ]]; then
    printf '%s\n' "${SAMPLES[@]}"; return
  fi
  if [[ -n "${GROUP_FILE:-}" && -s "${GROUP_FILE}" ]]; then
    while IFS=$'\t' read -r sid gid; do
      [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
      gg="$(printf '%s' "${gid:-coassembly}" | tr -c 'A-Za-z0-9._-' '_')"
      [[ "${gg}" == "${asm}" ]] && echo "${sid}"
    done < "${GROUP_FILE}"
  fi
}

# 工具解析：bowtie2/samtools 支持独立路径；metawrap 环境应含分箱工具
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_METAWRAP}" \
    bowtie2 samtools jgi_summarize_bam_contig_depths metabat2
BOWTIE2_BIN="$(resolve_tool BOWTIE2)"
SAMTOOLS_BIN="$(resolve_tool SAMTOOLS)"
JGI="$(command -v jgi_summarize_bam_contig_depths)"
METABAT2="$(command -v metabat2)"

# ---- 1. 逐组装：比对 + 深度 + 分箱 ------------------------------------------
for asm_fa in "${BIN_CONTIGS}"/*.fa; do
  [[ -s "${asm_fa}" ]] || continue
  asm_id="$(basename "${asm_fa}" .fa)"
  echo "==> [${asm_id}] bowtie2 比对 + 分箱"

  # 读取该组装对应的样本
  ASM_SAMPLES=(); while IFS= read -r s; do ASM_SAMPLES+=("$s"); done < <(samples_of_asm "${asm_id}")
  [[ "${#ASM_SAMPLES[@]}" -gt 0 ]] || { echo "ERROR: ${asm_id} 没有对应样本" >&2; exit 1; }

  A="${BIN_WORK}/${asm_id}"
  IDX="${A}/index/assembly"
  mkdir -p "${A}/bam" "${A}/depth" "${A}/bins"

  # ---- 1a. 建组装索引（大组装 >4Gb 自动 --large-index）----
  if [[ ! -e "${IDX}.1.bt2" && ! -e "${IDX}.1.bt2l" ]]; then
    echo "  -> bowtie2-build 组装索引"
    build_args=(--threads "${THREADS}")
    fa_bytes="$(stat -c %s "${asm_fa}" 2>/dev/null || stat -f %z "${asm_fa}" 2>/dev/null || echo 0)"
    if [[ "${fa_bytes}" -gt 4000000000 ]]; then
      echo "    检测到大组装(>4Gb)，自动加 --large-index"
      build_args+=(--large-index)
    fi
    mkdir -p "$(dirname "${IDX}")"
    bowtie2-build "${build_args[@]}" "${asm_fa}" "${IDX}"
  fi

  # ---- 1b. 每样本 bowtie2 比对（并行 run_pool，gz 原生读取）-> BAM ----
  # 注意资源：CONCURRENT_JOBS 个比对同时跑，每个用 THREADS 线程，
  # 需保证 THREADS*CONCURRENT_JOBS <= 节点总核数。
  echo "  -> bowtie2 比对（并行 ${CONCURRENT_JOBS}，每任务 ${THREADS} 线程；reads 为 gz 不解压）"
  export ASM_ID="${asm_id}" IDX="${IDX}" CLEAN_DIR BAM_DIR="${A}/bam" THREADS
  run_pool "${CONCURRENT_JOBS}" "${PIPELINE_DIR}/bin/workers/07_map.sh" "${ASM_SAMPLES[@]}"
  BAMS=()
  for s in "${ASM_SAMPLES[@]}"; do
    bam="${A}/bam/${s}.bam"
    [[ -s "${bam}" ]] || { echo "ERROR: ${s} 比对失败（见 ${A}/bam/${s}.bowtie2.log）" >&2; exit 1; }
    BAMS+=("${bam}")
  done

  # ---- 1c. 深度矩阵（MetaBAT2 输入）----
  DEPTH="${A}/depth/depth.txt"
  if [[ ! -s "${DEPTH}" ]]; then
    echo "  -> jgi_summarize_bam_contig_depths"
    "${JGI}" --outputDepth "${DEPTH}" "${BAMS[@]}"
  fi

  # ---- 1d. 分箱 ----
  # MetaBAT2
  if [[ ",${MAG_BINNERS}," == *",metabat2,"* ]]; then
    if [[ -z "$(ls "${A}/bins/metabat2"/*.fa 2>/dev/null)" ]]; then
      echo "  -> MetaBAT2"
      mkdir -p "${A}/bins/metabat2"
      "${METABAT2}" -i "${asm_fa}" -a "${DEPTH}" -m "${BIN_MIN_CONTIG_LEN}" \
          -t "${THREADS}" -o "${A}/bins/metabat2/bin"
    fi
  fi

  # MaxBin2（每个样本一个 abundance 文件）
  if [[ ",${MAG_BINNERS}," == *",maxbin2,"* ]]; then
    if [[ -z "$(ls "${A}/bins/maxbin2"/*.fasta "${A}/bins/maxbin2"/*.fa 2>/dev/null)" ]]; then
      echo "  -> MaxBin2"
      mkdir -p "${A}/bins/maxbin2" "${A}/depth/maxbin2"
      ABUND_LIST="${A}/depth/maxbin2/abund_list.txt"
      : > "${ABUND_LIST}"
      # depth.txt 表头: contig, contigLen, totalAvgDepth, <s1>.bam, <s1>.bam-var, <s2>.bam, ...
      # 第 k 个样本的深度列 = 3 + 2*k - 1 = 2*k + 2
      k=1
      for s in "${ASM_SAMPLES[@]}"; do
        col=$((2*k + 2))
        abund="${A}/depth/maxbin2/${s}.abund"
        tail -n +2 "${DEPTH}" | cut -f1,"${col}" > "${abund}"
        echo "${abund}" >> "${ABUND_LIST}"
        k=$((k+1))
      done
      run_MaxBin.pl -contig "${asm_fa}" -abund_list "${ABUND_LIST}" \
          -out "${A}/bins/maxbin2/bin" -thread "${THREADS}"
    fi
  fi

  # CONCOCT
  if [[ ",${MAG_BINNERS}," == *",concoct,"* ]]; then
    if [[ -z "$(ls "${A}/bins/concoct"/*.fa 2>/dev/null)" ]]; then
      echo "  -> CONCOCT"
      mkdir -p "${A}/bins/concoct" "${A}/concoct"
      cut_up_fasta.py "${asm_fa}" -c 10000 -o 0 --merge_last \
          -b "${A}/concoct/contigs_10K.bed" > "${A}/concoct/contigs_10K.fa"
      concoct_coverage_table.py "${A}/concoct/contigs_10K.bed" "${BAMS[@]}" \
          > "${A}/concoct/coverage_table.tsv"
      ( cd "${A}/concoct" && \
        concoct --composition_file contigs_10K.fa \
            --coverage_file coverage_table.tsv -b concoct_out -t "${THREADS}" )
      # CONCOCT 不同版本输出名不同（clustering_gt1000.csv / clustering.csv / 带前缀），自动匹配
      CLUST_CSV=""
      for cand in "${A}/concoct"/concoct_out/*.csv "${A}/concoct"/*.csv; do
        [[ -s "${cand}" ]] && { CLUST_CSV="${cand}"; break; }
      done
      if [[ -z "${CLUST_CSV}" ]]; then
        echo "ERROR: 找不到 CONCOCT 聚类输出 csv（ls ${A}/concoct/）" >&2
        ls -la "${A}/concoct/" "${A}/concoct/concoct_out/" 2>/dev/null || true
        exit 1
      fi
      echo "  -> merge_cutup_clustering (${CLUST_CSV})"
      merge_cutup_clustering.py "${CLUST_CSV}" \
          > "${A}/concoct/clustering_merged.csv"
      extract_fasta_bins.py "${asm_fa}" "${A}/concoct/clustering_merged.csv" \
          --output_path "${A}/bins/concoct"
    fi
  fi

  # ---- 1e. 整合 refine（DAS_Tool 优先；对含 | 的 contig 名比 metawrap 更稳）----
  # 生成各 binner 的 scaffolds2bin 表 -> DAS_Tool 整合 -> DASTool_bins
  gen_scaffolds2bin() {
    local bdir="$1" out="$2"
    # 优先用 DAS_Tool 自带脚本（更标准）；找不到再退回 awk
    local s2b_tool ext
    s2b_tool="${S2B_TOOL:-}"
    [[ -n "${s2b_tool}" && -x "${s2b_tool}" ]] || s2b_tool="$(command -v Fasta_to_Scaffolds2Bin.sh 2>/dev/null || true)"
    [[ -z "${s2b_tool}" ]] && s2b_tool="$(resolve_in_base Fasta_to_Scaffolds2Bin.sh || true)"
    if [[ -n "${s2b_tool}" ]]; then
      # 扩展名判断兼容三款 binner：metabat2=.fa / maxbin2=.fasta / concoct=无 bin 前缀 .fa
      if ls "${bdir}"/*.fasta >/dev/null 2>&1; then ext=fasta; else ext=fa; fi
      "${s2b_tool}" -i "${bdir}" -e "${ext}" > "${out}"
    else
      : > "${out}"
      for f in "${bdir}"/*.fa "${bdir}"/*.fasta "${bdir}"/*.fna; do
        [[ -s "${f}" ]] || continue
        local binid
        binid="$(basename "${f}")"
        awk -v b="${binid}" '/^>/{print substr($1,2) "\t" b}' "${f}" >> "${out}"
      done
    fi
  }

  REFINE_OK="no"
  # DAS_Tool / diamond 可能不在 metawrap 环境，而在 conda base：找不到时退回 base 查找
  resolve_in_base() {
    # 注意：set -e 下子 shell 里任何命令失败都会让整个子 shell 退出，
    # 所以每步都加 || true 兜底，保证总能返回 0 并输出路径。
    local cmd="$1" out=""
    if [[ -n "${CONDA_SH:-}" && -f "${CONDA_SH}" ]]; then
      out="$( ( source "${CONDA_SH}" 2>/dev/null || true
                conda activate base 2>/dev/null || true
                command -v "${cmd}" 2>/dev/null || true ) 2>/dev/null || true )"
    else
      out="$(command -v "${cmd}" 2>/dev/null || true)"
    fi
    printf '%s' "${out}"
  }
  DAS_TOOL_BIN="${DAS_TOOL:-}"
  [[ -n "${DAS_TOOL_BIN}" && -x "${DAS_TOOL_BIN}" ]] || DAS_TOOL_BIN="$(command -v DAS_Tool 2>/dev/null || true)"
  [[ -z "${DAS_TOOL_BIN}" && -n "${DAS_TOOL:-}" && -x "${DAS_TOOL}" ]] && DAS_TOOL_BIN="${DAS_TOOL}"
  if [[ -z "${DAS_TOOL_BIN}" ]]; then
    DAS_TOOL_BIN="$(resolve_in_base DAS_Tool || true)"
  fi
  [[ -n "${DAS_TOOL_BIN}" ]] && echo "    找到 DAS_Tool: ${DAS_TOOL_BIN}"
  if [[ "${RUN_BINNING_REFINE:-yes}" == "yes" && -n "${DAS_TOOL_BIN}" ]]; then
    echo "  -> DAS_Tool 整合分箱结果"
    # 关键：DAS_Tool 内部调用 Rscript/diamond，必须用 DAS_Tool 所在环境（dastool117）的，
    # 否则会用到 metawrap 环境的 R（没有 docopt 等 R 包）。把 dastool117/bin 放 PATH 最前。
    export PATH="$(dirname "${DAS_TOOL_BIN}"):${PATH}"
    echo "    已加入 DAS_Tool 环境 PATH: $(dirname "${DAS_TOOL_BIN}")"
    mkdir -p "${A}/das"
    s2b_list=(); label_list=()
    for bdir in metabat2 maxbin2 concoct; do
      # 兼容三款 binner 输出命名：metabat2=bin.*.fa / maxbin2=bin.*.fasta / concoct=*.fa(无 bin 前缀)
      [[ -n "$(ls "${A}/bins/${bdir}"/*.fa "${A}/bins/${bdir}"/*.fasta "${A}/bins/${bdir}"/*.fna 2>/dev/null)" ]] || continue
      gen_scaffolds2bin "${A}/bins/${bdir}" "${A}/das/${bdir}.tsv"
      s2b_list+=("${A}/das/${bdir}.tsv"); label_list+=("${bdir}")
    done
    if [[ "${#s2b_list[@]}" -ge 2 ]]; then
      # diamond 引擎：dastool117/bin 自带 diamond（PATH 已加）；此处仅兜底
      if ! command -v diamond >/dev/null 2>&1; then
        DIAMOND_BIN="$(resolve_tool DIAMOND 2>/dev/null || true)"
        [[ -z "${DIAMOND_BIN}" ]] && DIAMOND_BIN="$(resolve_in_base diamond || true)"
        [[ -n "${DIAMOND_BIN}" ]] && export PATH="$(dirname "${DIAMOND_BIN}"):${PATH}"
      fi
      dargs=(-i "$(IFS=,; echo "${s2b_list[*]}")" -l "$(IFS=,; echo "${label_list[*]}")"
             -c "${asm_fa}" -o "${A}/das/DASTool"
             --search_engine diamond --write_bins -t "${THREADS}")
      # DAS_Tool 1.1.7 参数：--write_bins 是 flag(不带值)；数据库目录是驼峰 --dbDirectory
      [[ -n "${DAS_TOOL_DB:-}" ]] && dargs+=(--dbDirectory "${DAS_TOOL_DB}")
      if "${DAS_TOOL_BIN}" "${dargs[@]}" > "${A}/das/das.log" 2>&1 \
         && [[ -d "${A}/das/DASTool_DASTool_bins" ]]; then
        REFINE_OK="yes"
        src_bins="${A}/das/DASTool_DASTool_bins"
      else
        echo "WARN: DAS_Tool 失败（见 ${A}/das/das.log），将合并三款 binner 结果继续" >&2
      fi
    else
      echo "WARN: 不足 2 个 binner 有结果，跳过 DAS_Tool 整合" >&2
    fi
  fi
  if [[ "${REFINE_OK}" != "yes" ]]; then
    # 未整合（DAS_Tool 不可用/失败/不足2个binner）：优先用单一 binner，否则合并三款
    if [[ -n "$(ls "${A}/bins/metabat2"/*.fa 2>/dev/null)" ]] \
       && [[ -z "$(ls "${A}/bins/maxbin2"/*.fasta 2>/dev/null)" ]] \
       && [[ -z "$(ls "${A}/bins/concoct"/*.fa 2>/dev/null)" ]]; then
      src_bins="${A}/bins/metabat2"
    else
      COMBINED="${A}/bins/combined"
      mkdir -p "${COMBINED}"
      for bdir in metabat2 maxbin2 concoct; do
        # 三种扩展名都收（metabat2=.fa maxbin2=.fasta concoct=*.fa 无 bin 前缀）
        for f in "${A}/bins/${bdir}"/*.fa "${A}/bins/${bdir}"/*.fasta "${A}/bins/${bdir}"/*.fna; do
          [[ -s "${f}" ]] || continue
          cp -n "${f}" "${COMBINED}/${bdir}.$(basename "${f}")"
        done
      done
      src_bins="${COMBINED}"
    fi
    echo "    使用未整合 bins: ${src_bins}"
  fi

  # ---- 1e2. 规范化 maxbin2 的 contig 头（MaxBin2 把 | 换成了 _，metawrap refine 需要 |）----
  #   >sample1_k141_4500  ->  >sample1|k141_4500（无 | 时把第一个 _ 恢复为 |）
  if [[ -d "${A}/bins/maxbin2" ]]; then
    for f in "${A}/bins/maxbin2"/bin.*.fasta "${A}/bins/maxbin2"/bin.*.fa; do
      [[ -s "${f}" ]] || continue
      if ! grep -q '|' "${f}"; then
        sed -i '0,/^\([^_]*\)_/s//\1|/' "${f}" 2>/dev/null || \
        sed -i.bak '0,/^\([^_]*\)_/s//\1|/' "${f}" 2>/dev/null || true
      fi
    done
  fi

  # ---- 1f. 收集 bins（加 asm 前缀防重名）----
  echo "  -> 收集 bins"
  mkdir -p "${MAG_RESULT}/refined_bins"
  if [[ -d "${src_bins}" ]]; then
    for f in "${src_bins}"/*.fa "${src_bins}"/*.fasta "${src_bins}"/*.fna; do
      [[ -e "${f}" ]] || continue
      cp -n "${f}" "${MAG_RESULT}/refined_bins/${asm_id}.$(basename "${f}")"
    done
  fi

  # ---- 1g. 深度已提取、CONCOCT 已用，删除 BAM 省空间 ----
  rm -f "${A}"/bam/*.bam "${A}"/bam/*.bam.bai 2>/dev/null || true
done

# ---- 2. dRep 去冗余 ----------------------------------------------------------
# 注意 pipefail：ls 任一 glob 不匹配会非零退出，必须加 || true
n_bins=$(ls "${MAG_RESULT}/refined_bins"/*.fa "${MAG_RESULT}/refined_bins"/*.fasta "${MAG_RESULT}/refined_bins"/*.fna 2>/dev/null | wc -l | tr -d ' ' || true)
if [[ "${n_bins}" -eq 0 ]]; then
  echo "WARNING: 没有产出任何 bin，跳过 dRep 与 CheckM2"
  echo "07_binning.sh 完成（0 个 MAG）：${MAG_RESULT}"
  exit 0
fi
if [[ "${RUN_DREP:-yes}" == "yes" ]]; then
  echo "==> dRep dereplicate (${n_bins} 个 bins)"
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_DREP}" dRep
  # dRep 内部调用 checkm（评估），需把 checkm 环境加进 PATH。
  # 注意：只能【追加到末尾】——CHECKM_BIN_DIR 若插到最前，会挤掉 drep 环境的
  # dRep/fastANI（checkm 环境里也装了 dRep 且缺 fastANI），导致
  # "ValueError: fastANI isn't working- make sure its installed"。
  if [[ -n "${CHECKM_BIN_DIR:-}" && -d "${CHECKM_BIN_DIR}" ]]; then
    export PATH="${PATH}:${CHECKM_BIN_DIR}"
    echo "    已追加 checkm 路径: ${CHECKM_BIN_DIR}"
  elif ! command -v checkm >/dev/null 2>&1; then
    echo "WARN: checkm 不在 PATH（dRep 需要 checkm 做过滤，可能失败）" >&2
  fi
  # 自检：dRep 与 fastANI 应来自 ${ENV_DREP} 环境
  DREP_ACTUAL="$(command -v dRep || true)"
  echo "    dRep: ${DREP_ACTUAL}"
  if ! command -v fastANI >/dev/null 2>&1; then
    echo "ERROR: fastANI 不在 PATH（dRep 次级聚类必需；请在 ${ENV_DREP} 环境安装 fastani）" >&2
    exit 1
  fi
  echo "    fastANI: $(command -v fastANI)"
  if [[ ! -d "${MAG_RESULT}/drep/dereplicated_genomes" ]]; then
    # -g 收集三种扩展名（metabat2=.fa maxbin2=.fasta concoct=.fa）；不匹配的 glob 不能传字面量，逐个过滤
    DREP_GENOMES=()
    for f in "${MAG_RESULT}/refined_bins"/*.fa "${MAG_RESULT}/refined_bins"/*.fasta "${MAG_RESULT}/refined_bins"/*.fna; do
      [[ -s "${f}" ]] && DREP_GENOMES+=("${f}")
    done
    drep_args=(-g "${DREP_GENOMES[@]}"
               -p "${THREADS}"
               -pa "${DREP_PRIMARY_ANI}" -sa "${DREP_SECONDARY_ANI}")
    if [[ "${DREP_IGNORE_QUALITY:-no}" == "yes" ]]; then
      echo "    跳过 checkm 质量过滤（--ignoreGenomeQuality，后续由 CheckM2 评估）"
      drep_args+=(--ignoreGenomeQuality)
    else
      drep_args+=(-comp "${MAG_MIN_COMPLETENESS}" -con "${MAG_MAX_CONTAMINATION}")
    fi
    dRep dereplicate "${MAG_RESULT}/drep" "${drep_args[@]}" \
        > "${MAG_RESULT}/drep.log" 2>&1
  fi
  MAG_INPUT="${MAG_RESULT}/drep/dereplicated_genomes"
  # dRep 输出保留输入扩展名（.fa/.fasta/.fna）。统一成 .fa：
  # 否则 CheckM2 -x fa 会跳过 .fasta MAG，08 的 *.fa glob 与 GTDB-Tk --extension fa 也会漏掉。
  for f in "${MAG_INPUT}"/*.fasta; do [[ -s "${f}" ]] && mv -f "${f}" "${f%.fasta}.fa"; done
  for f in "${MAG_INPUT}"/*.fna;   do [[ -s "${f}" ]] && mv -f "${f}" "${f%.fna}.fa";   done
else
  MAG_INPUT="${MAG_RESULT}/refined_bins"
fi

# ---- 3. CheckM2 质检 ---------------------------------------------------------
echo "==> CheckM2 predict"
source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_CHECKM2}" checkm2
# CheckM2 独立线程（小内存节点可调低，默认 THREADS）
CM2_THREADS="${CHECKM2_THREADS:-${THREADS}}"
# checkm2 内部调用 prodigal/diamond（base 环境有），确保在 PATH
if [[ -n "${BASE_BIN_DIR:-}" && -d "${BASE_BIN_DIR}" ]]; then
  export PATH="${BASE_BIN_DIR}:${PATH}"
  echo "    已加入 base 工具路径: ${BASE_BIN_DIR}"
fi
# CheckM2 数据库：CHECKM2_DB 可为目录（自动找 *.dmnd）或 dmnd 文件路径。
# 注意：CheckM2 运行时优先读 CHECKM2DB 环境变量（其次才是 checkm2 database --setdblocation 写入的配置），
#       该变量必须指向 dmnd 文件，否则 CheckM2 把目录当数据库丢给 DIAMOND -> "Is a directory"。
CM2_DB_FILE=""
if [[ -d "${CHECKM2_DB}" ]]; then
  CM2_DB_FILE="$(find "${CHECKM2_DB}" -maxdepth 1 -name '*.dmnd' -type f 2>/dev/null | head -1)"
  [[ -n "${CM2_DB_FILE}" ]] || { echo "ERROR: ${CHECKM2_DB} 目录下找不到 *.dmnd（CheckM2 数据库需 uniref100.KO.1.dmnd）" >&2; exit 1; }
elif [[ -f "${CHECKM2_DB}" ]]; then
  CM2_DB_FILE="${CHECKM2_DB}"
else
  echo "ERROR: CheckM2 数据库不存在: ${CHECKM2_DB}" >&2; exit 1
fi
echo "    使用 CheckM2 数据库: ${CM2_DB_FILE}"
if [[ ! -s "${MAG_RESULT}/checkm2/quality_report.tsv" ]]; then
  # 上次失败残留的非空输出目录会让 CheckM2 困惑：重跑前先清掉
  rm -rf "${MAG_RESULT}/checkm2"
  # -x fa：CheckM2 默认只认 .fna，我们的 MAG 是 .fa
  CHECKM2DB="${CM2_DB_FILE}" checkm2 predict --threads "${CM2_THREADS}" \
      --input "${MAG_INPUT}" -x fa \
      --output-directory "${MAG_RESULT}/checkm2" \
      > "${MAG_RESULT}/checkm2.log" 2>&1
fi

# ---- 4. CheckM2 后按质量筛选（可选，--mag-filter yes）-------------------------
# 把 Completeness>=MAG_MIN_COMPLETENESS 且 Contamination<=MAG_MAX_CONTAMINATION 的
# MAG 复制到 filtered_genomes/；MAG_list.txt 与后续 08 均改用筛选结果。
FILTERED_DIR="${MAG_RESULT}/filtered_genomes"
MAG_FILTER_APPLIED="no"
if [[ "${MAG_FILTER:-no}" == "yes" && -s "${MAG_RESULT}/checkm2/quality_report.tsv" ]]; then
  echo "==> CheckM2 质量筛选（completeness>=${MAG_MIN_COMPLETENESS}, contamination<=${MAG_MAX_CONTAMINATION}）"
  # 动态探测列位：表头找 Completeness/Contamination，找不到按第 2/3 列兜底
  QREP="${MAG_RESULT}/checkm2/quality_report.tsv"
  HDR="$(head -1 "${QREP}")"
  COMP_COL="$(head -1 "${QREP}" | tr '\t' '\n' | grep -niE '^completeness' | head -1 | cut -d: -f1)"
  CONT_COL="$(head -1 "${QREP}" | tr '\t' '\n' | grep -niE '^contamination' | head -1 | cut -d: -f1)"
  [[ -n "${COMP_COL}" ]] || COMP_COL=2
  [[ -n "${CONT_COL}" ]] || CONT_COL=3
  rm -rf "${FILTERED_DIR}"; mkdir -p "${FILTERED_DIR}"
  KEPT=0; TOTAL=0
  while IFS=$'\t' read -r -a F; do
    [[ -z "${F[0]}" || "${F[0]}" == "Name" ]] && continue
    TOTAL=$((TOTAL+1))
    COMP="${F[$((COMP_COL-1))]}"; CONT="${F[$((CONT_COL-1))]}"
    if awk -v c="${COMP}" -v x="${CONT}" -v mc="${MAG_MIN_COMPLETENESS}" -v mx="${MAG_MAX_CONTAMINATION}" \
        'BEGIN{exit !(c+0 >= mc+0 && x+0 <= mx+0)}'; then
      for cand in "${MAG_INPUT}/${F[0]}.fa" "${MAG_INPUT}/${F[0]}.fasta" "${MAG_INPUT}/${F[0]}.fna"; do
        [[ -s "${cand}" ]] && { cp -n "${cand}" "${FILTERED_DIR}/"; KEPT=$((KEPT+1)); break; }
      done
    fi
  done < "${QREP}"
  if [[ "${KEPT}" -gt 0 ]]; then
    MAG_INPUT="${FILTERED_DIR}"
    MAG_FILTER_APPLIED="yes"
  fi
  echo "    保留 ${KEPT}/${TOTAL} 个 MAG（Completeness>=${MAG_MIN_COMPLETENESS} 且 Contamination<=${MAG_MAX_CONTAMINATION}）"
  [[ "${KEPT}" -gt 0 ]] || echo "WARN: 无 MAG 通过筛选，仍使用未筛选全集（dereplicated_genomes）" >&2
fi

# ---- 5. 汇总 ----------------------------------------------------------------
ls "${MAG_INPUT}"/*.fa "${MAG_INPUT}"/*.fasta "${MAG_INPUT}"/*.fna > "${MAG_RESULT}/MAG_list.txt" 2>/dev/null || true
if [[ -s "${MAG_RESULT}/checkm2/quality_report.tsv" ]]; then
  cp -f "${MAG_RESULT}/checkm2/quality_report.tsv" "${MAG_RESULT}/MAG_quality.tsv"
  if [[ "${MAG_FILTER_APPLIED}" == "yes" ]]; then
    # 保留一份筛选后的质量表，方便对照
    head -1 "${MAG_RESULT}/checkm2/quality_report.tsv" > "${MAG_RESULT}/MAG_quality.filtered.tsv"
    while IFS=$'\t' read -r -a F; do
      [[ -z "${F[0]}" || "${F[0]}" == "Name" ]] && continue
      if [[ -s "${FILTERED_DIR}/${F[0]}.fa" || -s "${FILTERED_DIR}/${F[0]}.fasta" || -s "${FILTERED_DIR}/${F[0]}.fna" ]]; then
        printf '%s\n' "$(IFS=$'\t'; echo "${F[*]}")" >> "${MAG_RESULT}/MAG_quality.filtered.tsv"
      fi
    done < "${MAG_RESULT}/checkm2/quality_report.tsv"
  fi
fi
echo "MAG 数量: $(wc -l < "${MAG_RESULT}/MAG_list.txt" 2>/dev/null || echo 0)"
echo "07_binning.sh 完成：${MAG_RESULT}"
