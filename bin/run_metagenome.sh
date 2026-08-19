#!/usr/bin/env bash
# ============================================================================
# run_metagenome.sh — shotgun metagenomics pipeline driver (module 01-08).
#
# Pure-CLI parameterized driver for the metagenome workflow.  All parameters
# can be passed on the command line; config.sh provides neutral defaults and
# a YAML config file (--config FILE.yaml) may supply defaults as well.
#
# Examples:
#   bash run_metagenome.sh \
#     --project-dir /data/proj/mg1 --input /data/proj/mg1/seq \
#     --qc-needed yes --host-genome /db/host_db/wheat/wheat \
#     --assembly co-assembly --binning metawrap --threads 28 --jobs 8
#   microbiome-toolkit metagenome --config config/metagenome_config.yaml
#
# Required:
#   --project-dir DIR    output root (results/ work/ logs/)
#   --input DIR          reads directory (*_1.fq.gz / *_2.fq.gz)
#
# Common options:
#   --qc-needed yes|no         kneaddata QC (yes) or clean data (no)     [yes]
#   --host-genome PREFIX       bowtie2 index prefix (or --host-fasta)
#   --host-fasta FILE          host genome FASTA; auto bowtie2-build
#   --host-name NAME           species dir name for the auto-built index
#   --adapters FILE            trimmomatic adapter file (ILLUMINACLIP)
#   --group-file FILE          sample_id<TAB>group; co-assembly per group
#   --assembly MODE            per-sample | co-assembly | both            [per-sample]
#   --min-contig-len N         gene prediction contigs >= N bp            [1000]
#   --bin-min-contig-len N     binning contigs >= N bp                    [1500]
#   --cluster TOOL             mmseqs2 | cd-hit-est                       [mmseqs2]
#   --quant TOOL               salmon | bwa                               [salmon]
#   --taxonomy TOOL            nr-megan | kraken2 | none                  [nr-megan]
#   --function TOOL            eggnog | none                              [eggnog]
#   --binning TOOL             metawrap | none                            [none]
#   --metawrap-reads-mode MODE plain | gz
#   --mag-annotate yes|no      GTDB-Tk+Prodigal+KofamScan on MAGs         [no]
#   --mag-quant yes|no         coverM MAG abundance                       [no]
#   --mag-quant-methods LIST   extra coverM methods, e.g. "rpkm tpm"
#   --gtdbtk-db DIR            GTDB reference database dir
#   --gtdbtk-pplacer-cpus N    pplacer threads (1 default; 2-4 if RAM allows)
#   --kofam-profile DIR / --kofam-ko-list FILE  KofamScan database paths
#   --binners LIST             metabat2,maxbin2,concoct
#   --binning-refine yes|no / --binning-reassemble yes|no / --run-drep yes|no
#   --drep-ignore-quality yes|no
#   --mag-filter yes|no        CheckM2 quality filter (filtered_genomes/)
#   --mag-min-completeness N / --mag-max-contamination N
#   --checkm2-db DIR           CheckM2 database
#   --nr-db PATH               NR diamond database (nr-megan)
#   --megan-map PATH           MEGAN accession->taxid mapping (nr-megan)
#   --taxa-filter all|bacteria [all]
#   --eggnog-db DIR            eggNOG database directory
#   --contig-coverage yes|no   extra contig depth table                   [no]
#   --kegg-module-def FILE / --kegg-pathway-def FILE / --kegg-module-name FILE
#   --kegg-complete-threshold N [0.9]
#
# Conda / resources:
#   --conda-sh PATH            path to conda.sh (server: conda info --base)
#   --qc-env NAME ...          per-module env names (--assembly-env/--gene-env/
#                              --mmseqs-env/--cdhit-env/--salmon-env/--bwa-env/
#                              --diamond-env/--megan-env/--kraken2-env/
#                              --eggnog-env/--metawrap-env/--checkm2-env/--drep-env)
#   --threads N / --jobs N / --memory-gb N
#
# Runtime:
#   --config FILE.yaml         YAML defaults (CLI flags override)
#   --resume yes|no            skip completed steps                       [yes]
#   --force                    rerun everything
#   --check-only               validate inputs/params and exit
#   -h|--help                  this help
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/../workflows/metagenome" && pwd)"
source "${WORKFLOW_DIR}/config.sh"

usage() {
  sed -n '2,100p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---- pre-scan --config -------------------------------------------------------
CONFIG_FILE=""
_pending=""
for _a in "$@"; do
  if [[ -n "${_pending}" ]]; then CONFIG_FILE="${_a}"; _pending=""; continue; fi
  [[ "${_a}" == "--config" ]] && _pending="yes"
done
if [[ -n "${CONFIG_FILE}" ]]; then
  [[ -f "${CONFIG_FILE}" ]] || { echo "ERROR: --config file not found: ${CONFIG_FILE}" >&2; exit 1; }
  eval "$(python3 "${WORKFLOW_DIR}/../../bin/yaml2env.py" metagenome "${CONFIG_FILE}")"
  echo "Loaded config file: ${CONFIG_FILE}"
fi

# ---- parse command line ------------------------------------------------------
FORCE="no"; CHECK_ONLY="no"; GROUP_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)         shift 2 ;;
    --project-dir)    PROJECT_DIR="${2:?missing --project-dir}"; shift 2 ;;
    --input)          FASTQ_DIR="${2:?missing --input}"; shift 2 ;;
    --fastq-dir)      FASTQ_DIR="${2:?missing --fastq-dir}"; shift 2 ;;
    --group-file)     GROUP_FILE="${2:?missing --group-file}"; shift 2 ;;
    --qc-needed)      QC_NEEDED="${2:?missing --qc-needed}"; shift 2 ;;
    --host-genome)    HOST_GENOME="${2:?missing --host-genome}"; shift 2 ;;
    --host-fasta)     HOST_FASTA="${2:?missing --host-fasta}"; shift 2 ;;
    --host-name)      HOST_NAME="${2:?missing --host-name}"; shift 2 ;;
    --host-db-dir)    HOST_DB_DIR="${2:?missing --host-db-dir}"; shift 2 ;;
    --adapters)       ADAPTERS="${2:?missing --adapters}"; shift 2 ;;
    --trimmomatic-dir) TRIMMOMATIC_DIR="${2:?missing --trimmomatic-dir}"; shift 2 ;;
    --trimmomatic-opts) TRIMMOMATIC_OPTS="${2:?missing --trimmomatic-opts}"; shift 2 ;;
    --bowtie2-opts)   BOWTIE2_OPTS="${2:?missing --bowtie2-opts}"; shift 2 ;;
    --assembly)       ASSEMBLY_MODE="${2:?missing --assembly}"; shift 2 ;;
    --min-contig-len) GENE_MIN_CONTIG_LEN="${2:?missing --min-contig-len}"; shift 2 ;;
    --bin-min-contig-len) BIN_MIN_CONTIG_LEN="${2:?missing --bin-min-contig-len}"; shift 2 ;;
    --cluster)        GENE_CLUSTERER="${2:?missing --cluster}"; shift 2 ;;
    --quant)          QUANT_TOOL="${2:?missing --quant}"; shift 2 ;;
    --taxonomy)       TAXONOMY_TOOL="${2:?missing --taxonomy}"; shift 2 ;;
    --function)       FUNCTION_TOOL="${2:?missing --function}"; shift 2 ;;
    --binning)        BINNING_TOOL="${2:?missing --binning}"; shift 2 ;;
    --metawrap-reads-mode) METAWRAP_READS_MODE="${2:?missing --metawrap-reads-mode}"; shift 2 ;;
    --binners)        MAG_BINNERS="${2:?missing --binners}"; shift 2 ;;
    --binning-refine) RUN_BINNING_REFINE="${2:?missing --binning-refine}"; shift 2 ;;
    --binning-reassemble) RUN_BINNING_REASSEMBLE="${2:?missing --binning-reassemble}"; shift 2 ;;
    --run-drep)       RUN_DREP="${2:?missing --run-drep}"; shift 2 ;;
    --drep-ignore-quality) DREP_IGNORE_QUALITY="${2:?missing --drep-ignore-quality}"; shift 2 ;;
    --mag-filter)     MAG_FILTER="${2:?missing --mag-filter}"; shift 2 ;;
    --mag-min-completeness) MAG_MIN_COMPLETENESS="${2:?missing --mag-min-completeness}"; shift 2 ;;
    --mag-max-contamination) MAG_MAX_CONTAMINATION="${2:?missing --mag-max-contamination}"; shift 2 ;;
    --checkm2-threads)    CHECKM2_THREADS="${2:?missing --checkm2-threads}"; shift 2 ;;
    --mag-annotate)       MAG_ANNOTATE="${2:?missing --mag-annotate}"; shift 2 ;;
    --mag-quant)          MAG_QUANT="${2:?missing --mag-quant}"; shift 2 ;;
    --mag-quant-methods)  MAG_QUANT_METHODS="${2:?missing --mag-quant-methods}"; shift 2 ;;
    --gtdbtk-db)          GTDBTK_DATA_PATH="${2:?missing --gtdbtk-db}"; shift 2 ;;
    --gtdbtk-pplacer-cpus) GTDBTK_PPLACER_CPUS="${2:?missing --gtdbtk-pplacer-cpus}"; shift 2 ;;
    --kofam-profile)      KOFAM_PROFILE="${2:?missing --kofam-profile}"; shift 2 ;;
    --kofam-ko-list)      KOFAM_KO_LIST="${2:?missing --kofam-ko-list}"; shift 2 ;;
    --checkm2-db)     CHECKM2_DB="${2:?missing --checkm2-db}"; shift 2 ;;
    --nr-db)          NR_DMND="${2:?missing --nr-db}"; shift 2 ;;
    --megan-map)      MEGAN_MAP="${2:?missing --megan-map}"; shift 2 ;;
    --max-target-seqs) DIAMOND_MAX_TARGET_SEQS="${2:?missing --max-target-seqs}"; shift 2 ;;
    --taxa-filter)    TAXA_FILTER="${2:?missing --taxa-filter}"; shift 2 ;;
    --kraken2-db)     KRAKEN2_DB="${2:?missing --kraken2-db}"; shift 2 ;;
    --eggnog-db)      EGGNOG_DATA_DIR="${2:?missing --eggnog-db}"; shift 2 ;;
    --eggnog-shm)     EGGNOG_SHM="${2:?missing --eggnog-shm}"; shift 2 ;;
    --contig-coverage) CONTIG_COVERAGE="${2:?missing --contig-coverage}"; shift 2 ;;
    --kegg-module-def)  KEGG_MODULE_DEF="${2:?missing --kegg-module-def}"; shift 2 ;;
    --kegg-pathway-def) KEGG_PATHWAY_DEF="${2:?missing --kegg-pathway-def}"; shift 2 ;;
    --kegg-module-name) KEGG_MODULE_NAME="${2:?missing --kegg-module-name}"; shift 2 ;;
    --kegg-complete-threshold) KEGG_COMPLETE_THRESHOLD="${2:?missing --kegg-complete-threshold}"; shift 2 ;;
    --conda-sh)       CONDA_SH="${2:?missing --conda-sh}"; shift 2 ;;
    --conda-module)   CONDA_MODULE="${2:?missing --conda-module}"; shift 2 ;;
    --qc-env)         ENV_QC="${2:?missing --qc-env}"; shift 2 ;;
    --assembly-env)   ENV_ASSEMBLY="${2:?missing --assembly-env}"; shift 2 ;;
    --gene-env)       ENV_GENE="${2:?missing --gene-env}"; shift 2 ;;
    --mmseqs-env)     ENV_CLUSTER_MMSEQS="${2:?missing --mmseqs-env}"; shift 2 ;;
    --cdhit-env)      ENV_CLUSTER_CDHIT="${2:?missing --cdhit-env}"; shift 2 ;;
    --salmon-env)     ENV_SALMON="${2:?missing --salmon-env}"; shift 2 ;;
    --bwa-env)        ENV_BWA="${2:?missing --bwa-env}"; shift 2 ;;
    --diamond-env)    ENV_DIAMOND="${2:?missing --diamond-env}"; shift 2 ;;
    --megan-env)      ENV_MEGAN="${2:?missing --megan-env}"; shift 2 ;;
    --kraken2-env)    ENV_KRAKEN2="${2:?missing --kraken2-env}"; shift 2 ;;
    --eggnog-env)     ENV_EGGNOG="${2:?missing --eggnog-env}"; shift 2 ;;
    --metawrap-env)   ENV_METAWRAP="${2:?missing --metawrap-env}"; shift 2 ;;
    --checkm2-env)    ENV_CHECKM2="${2:?missing --checkm2-env}"; shift 2 ;;
    --drep-env)       ENV_DREP="${2:?missing --drep-env}"; shift 2 ;;
    --threads)        THREADS="${2:?missing --threads}"; shift 2 ;;
    --jobs)           CONCURRENT_JOBS="${2:?missing --jobs}"; shift 2 ;;
    --memory-gb)      MEMORY_GB="${2:?missing --memory-gb}"; shift 2 ;;
    --resume)         RESUME="${2:?missing --resume}"; shift 2 ;;
    --force)          FORCE="yes"; shift ;;
    --check-only)     CHECK_ONLY="yes"; shift ;;
    -h|--help)        usage ;;
    *) echo "ERROR: unknown option: $1" >&2; usage ;;
  esac
done

# ---- basic validation --------------------------------------------------------
[[ "${PROJECT_DIR}" == /* ]] || { echo "ERROR: --project-dir must be an absolute path: ${PROJECT_DIR}" >&2; exit 1; }
[[ "${PROJECT_DIR}" == "/path/to/metagenome_project" ]] && { echo "ERROR: --project-dir not set" >&2; exit 1; }
[[ -d "${FASTQ_DIR}" ]] || { echo "ERROR: --input directory does not exist: ${FASTQ_DIR}" >&2; exit 1; }
[[ "${FASTQ_DIR}" == "/path/to/fastq" ]] && { echo "ERROR: --input not set" >&2; exit 1; }

for v in QC_NEEDED RUN_BINNING_REFINE RUN_BINNING_REASSEMBLE RUN_DREP RESUME CONTIG_COVERAGE; do
  val="${!v:-}"
  [[ -z "${val}" || "${val}" == "yes" || "${val}" == "no" ]] || {
    echo "ERROR: ${v} must be yes or no (got: ${val})" >&2; exit 1; }
done
case "${ASSEMBLY_MODE}" in per-sample|co-assembly|both) : ;; *) echo "ERROR: --assembly must be per-sample|co-assembly|both" >&2; exit 1 ;; esac
case "${GENE_CLUSTERER}" in mmseqs2|cd-hit-est) : ;; *) echo "ERROR: --cluster must be mmseqs2|cd-hit-est" >&2; exit 1 ;; esac
case "${QUANT_TOOL}" in salmon|bwa) : ;; *) echo "ERROR: --quant must be salmon|bwa" >&2; exit 1 ;; esac
case "${TAXONOMY_TOOL}" in nr-megan|kraken2|none) : ;; *) echo "ERROR: --taxonomy must be nr-megan|kraken2|none" >&2; exit 1 ;; esac
case "${FUNCTION_TOOL}" in eggnog|none) : ;; *) echo "ERROR: --function must be eggnog|none" >&2; exit 1 ;; esac
case "${BINNING_TOOL}" in metawrap|none) : ;; *) echo "ERROR: --binning must be metawrap|none" >&2; exit 1 ;; esac
case "${TAXA_FILTER}" in all|bacteria) : ;; *) echo "ERROR: --taxa-filter must be all|bacteria" >&2; exit 1 ;; esac
[[ -f "${CONDA_SH}" ]] || { echo "ERROR: --conda-sh file not found: ${CONDA_SH} (get it with: conda info --base | xargs -I{} echo {}/etc/profile.d/conda.sh)" >&2; exit 1; }
[[ "${THREADS}" =~ ^[0-9]+$ && "${CONCURRENT_JOBS}" =~ ^[0-9]+$ ]] || { echo "ERROR: --threads/--jobs must be numbers" >&2; exit 1; }

# ---- directories (recompute from final PROJECT_DIR, overriding config.sh) ----
WORK_DIR="${PROJECT_DIR}/work"
RESULT_DIR="${PROJECT_DIR}/results"
LOG_DIR="${PROJECT_DIR}/logs"
export PROJECT_DIR FASTQ_DIR WORK_DIR RESULT_DIR LOG_DIR
mkdir -p "${PROJECT_DIR}" "${WORK_DIR}" "${RESULT_DIR}" "${LOG_DIR}" \
         "${WORK_DIR}/markers" "${RESULT_DIR}/summary"
LOG_FILE="${LOG_DIR}/pipeline.log"
say() { printf '%s\n' "$*" | tee -a "${LOG_FILE}"; }
say "==== $(date '+%F %T') run_metagenome.sh started ===="
say "    project dir: ${PROJECT_DIR}"

# ---- sample discovery ---------------------------------------------------------
echo "==> discovering samples (${FASTQ_DIR})"
printf 'sample_id\tR1\tR2\n' > "${WORK_DIR}/samples.tsv"
found=0
for i in "${!R1_SUFFIXES[@]}"; do
  s1="${R1_SUFFIXES[$i]}"; s2="${R2_SUFFIXES[$i]}"
  for f in "${FASTQ_DIR}"/*"${s1}"; do
    [[ -e "${f}" ]] || continue
    sample="$(basename "${f}" "${s1}")"
    r2="${FASTQ_DIR}/${sample}${s2}"
    [[ -e "${r2}" ]] || { echo "WARNING: ${sample} missing R2 (${s2}); skipped" >&2; continue; }
    printf '%s\t%s\t%s\n' "${sample}" "$(cd "$(dirname "${f}")" && pwd)/$(basename "${f}")" \
        "$(cd "$(dirname "${r2}")" && pwd)/$(basename "${r2}")" >> "${WORK_DIR}/samples.tsv"
    found=$((found+1))
  done
done
[[ "${found}" -gt 0 ]] || { echo "ERROR: no *_1.fq.gz / *_2.fq.gz pairs found in ${FASTQ_DIR}" >&2; exit 1; }
sort -u -o "${WORK_DIR}/samples.tsv" "${WORK_DIR}/samples.tsv"
echo "    found ${found} samples: $(cut -f1 "${WORK_DIR}/samples.tsv" | tr '\n' ' ')"

if [[ -n "${GROUP_FILE:-}" ]]; then
  [[ -s "${GROUP_FILE}" ]] || { echo "ERROR: --group-file missing or empty: ${GROUP_FILE}" >&2; exit 1; }
  while read -r sid _; do
    [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
    grep -qxF "${sid}" <(cut -f1 "${WORK_DIR}/samples.tsv") || {
      echo "ERROR: sample ${sid} in group-file is not in the reads directory" >&2; exit 1; }
  done < "${GROUP_FILE}"
fi

# ---- host genome preparation ---------------------------------------------------
if [[ -n "${HOST_FASTA:-}" ]]; then
  [[ -s "${HOST_FASTA}" ]] || { echo "ERROR: --host-fasta not found: ${HOST_FASTA}" >&2; exit 1; }
  [[ -z "${HOST_NAME:-}" ]] && HOST_NAME="$(basename "${HOST_FASTA}" | sed -E 's/\.(fa|fna|fasta)(\.gz)?$//')"
  HOST_GENOME="${HOST_DB_DIR}/${HOST_NAME}/${HOST_NAME}"
  mkdir -p "$(dirname "${HOST_GENOME}")"
  if [[ ! -e "${HOST_GENOME}.1.bt2" && ! -e "${HOST_GENOME}.1.bt2l" ]]; then
    echo "==> building host index: ${HOST_GENOME}"
    source "${WORKFLOW_DIR}/bin/activate_conda_env.sh" "${ENV_QC}" bowtie2 bowtie2-build
    build_args=(--threads "${THREADS}")
    if [[ "$(stat -c %s "${HOST_FASTA}" 2>/dev/null || stat -f %z "${HOST_FASTA}" 2>/dev/null || echo 0)" -gt 4000000000 ]]; then
      echo "    large genome (>4Gb) detected; adding --large-index"
      build_args+=(--large-index)
    fi
    bowtie2-build "${build_args[@]}" "${HOST_FASTA}" "${HOST_GENOME}"
  fi
fi
if [[ -n "${HOST_GENOME:-}" ]]; then
  ok="no"
  for f in "${HOST_GENOME}"*.bt2 "${HOST_GENOME}"*.bt2l; do [[ -e "${f}" ]] && ok="yes"; done
  [[ "${ok}" == "yes" ]] || { echo "ERROR: host index not found: ${HOST_GENOME}" >&2; exit 1; }
  echo "    host removal: using index ${HOST_GENOME}"
else
  echo "    host removal: no host genome configured (skipped)"
fi

# ---- write generated.env (modules source this) ---------------------------------
echo "==> writing ${WORK_DIR}/generated.env"
{
  for v in PROJECT_DIR WORK_DIR RESULT_DIR LOG_DIR FASTQ_DIR GROUP_FILE QC_NEEDED HOST_GENOME HOST_FASTA HOST_NAME \
           HOST_DB_DIR ADAPTERS TRIMMOMATIC_DIR TRIMMOMATIC_OPTS BOWTIE2_OPTS \
           ASSEMBLY_MODE GENE_MIN_CONTIG_LEN BIN_MIN_CONTIG_LEN \
           GENE_SPLIT_SEQS GENE_CLUSTERER GENE_MIN_IDENTITY GENE_MIN_COVERAGE TRANSLATE_TRIM \
           QUANT_TOOL SALMON_K TAXONOMY_TOOL NR_DMND MEGAN_MAP DIAMOND_MAX_TARGET_SEQS \
           DIAMOND_EVALUE MEGAN_MIN_SUPPORT MEGAN_MIN_EVALUE TAXA_FILTER KRAKEN2_DB \
           FUNCTION_TOOL EGGNOG_DATA_DIR EGGNOG_PROT_MIN_LEN EGGNOG_SPLIT_SEQS EGGNOG_SHM \
           KEGG_MODULE_DEF KEGG_MODULE_NAME KEGG_PATHWAY_DEF KEGG_COMPLETE_THRESHOLD \
           CONTIG_COVERAGE BOWTIE2 \
           BINNING_TOOL MAG_BINNERS RUN_BINNING_REFINE RUN_BINNING_REASSEMBLE RUN_DREP \
           DREP_PRIMARY_ANI DREP_SECONDARY_ANI MAG_MIN_COMPLETENESS MAG_MAX_CONTAMINATION \
           CHECKM2_DB METAWRAP_READS_MODE DREP_IGNORE_QUALITY CHECKM2_THREADS \
           MAG_FILTER \
           MAG_ANNOTATE MAG_QUANT MAG_QUANT_METHODS ENV_GTDBTK GTDBTK_DATA_PATH GTDBTK_PPLACER_CPUS ENV_MAG_PRODIGAL ENV_KOFAM \
           ENV_COVERM KOFAM_PROFILE KOFAM_KO_LIST CONDA_SH CONDA_MODULE \
           ENV_QC ENV_ASSEMBLY ENV_GENE ENV_CLUSTER_MMSEQS ENV_CLUSTER_CDHIT ENV_SALMON \
           ENV_BWA ENV_DIAMOND ENV_MEGAN ENV_KRAKEN2 ENV_EGGNOG ENV_METAWRAP ENV_CHECKM2 \
           ENV_DREP THREADS CONCURRENT_JOBS MEMORY_GB RESUME; do
    printf '%s=%q\n' "${v}" "${!v:-}"
  done
} > "${WORK_DIR}/generated.env"

[[ "${CHECK_ONLY}" == "yes" ]] && { echo "==> check-only finished, no modules were run"; exit 0; }

# ---- module execution ----------------------------------------------------------
run_module() {
  local name="$1"
  local script="$2"
  local marker="${WORK_DIR}/markers/${name}.ok"
  if [[ "${RESUME}" == "yes" && -f "${marker}" && "${FORCE}" != "yes" ]]; then
    say "---- [skip] ${name} already done (${marker})"
    return 0
  fi
  say "==== [${name}] $(date '+%F %T') start: ${script}"
  local t0=$SECONDS
  if bash "${script}" 2>&1 | tee -a "${LOG_FILE}"; then
    touch "${marker}"
    say "==== [${name}] $(date '+%F %T') done (${SECONDS}s elapsed)"
  else
    say "==== [${name}] $(date '+%F %T') FAILED (${SECONDS}s) -- see ${LOG_FILE}"
    exit 1
  fi
}

run_module 01_qc_dehost     "${WORKFLOW_DIR}/modules/01_qc_dehost.sh"
run_module 02_assembly      "${WORKFLOW_DIR}/modules/02_assembly.sh"
run_module 03_gene_catalog  "${WORKFLOW_DIR}/modules/03_gene_catalog.sh"
run_module 04_quant         "${WORKFLOW_DIR}/modules/04_quant.sh"
[[ "${TAXONOMY_TOOL}" == "none" ]] || run_module 05_taxonomy "${WORKFLOW_DIR}/modules/05_taxonomy.sh"
[[ "${FUNCTION_TOOL}" == "none" ]] || run_module 06_function "${WORKFLOW_DIR}/modules/06_function.sh"
[[ "${BINNING_TOOL}" == "none" ]] || run_module 07_binning "${WORKFLOW_DIR}/modules/07_binning.sh"
[[ "${MAG_ANNOTATE}" == "yes" || "${MAG_QUANT}" == "yes" ]] && run_module 08_mag_annotation "${WORKFLOW_DIR}/modules/08_mag_annotation.sh"

# ---- summary report -------------------------------------------------------------
echo "==> generating summary report"
SUMMARY="${RESULT_DIR}/summary/README_summary.md"
{
  echo "# Metagenome analysis summary"
  echo
  echo "- Generated: $(date '+%F %T')"
  echo "- Project dir: ${PROJECT_DIR}"
  echo "- Reads dir: ${FASTQ_DIR}"
  echo "- Samples: $(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!=""' "${WORK_DIR}/samples.tsv" | wc -l | tr -d ' ')"
  echo
  echo "## Module outputs"
  echo
  echo "| Module | Status | Main outputs |"
  echo "|---|---|---|"
  for m in 01_qc_dehost 02_assembly 03_gene_catalog 04_quant 05_taxonomy 06_function 07_binning; do
    if [[ -f "${WORK_DIR}/markers/${m}.ok" ]]; then st="done"; else st="-"; fi
    echo "| ${m} | ${st} | see below |"
  done
  echo
  echo "## QC"
  echo "- per-sample read counts: results/qc/read_counts.tsv"
  echo "- kneaddata summary: results/qc/kneaddata_summary.txt (if any)"
  echo "- MultiQC: results/qc/multiqc_report.html (if any)"
  echo
  echo "## Assembly"
  echo "- stats: results/assembly/assembly.stats.tsv"
  echo "- merged contigs: results/assembly/assembly.fa"
  echo "- assembly list: results/assembly/assemblies.list"
  echo
  echo "## Gene catalog"
  echo "- stats: results/gene_catalog/catalog.stats.tsv"
  echo "- nucleotide catalog: results/gene_catalog/catalog/gene_catalog.fna"
  echo "- protein sequences: results/gene_catalog/catalog/gene_catalog.faa"
  echo
  echo "## Quantification (${QUANT_TOOL})"
  echo "- count matrix: results/quant/gene.count.tsv"
  if [[ "${QUANT_TOOL}" == "bwa" ]]; then
    echo "- FPKM matrix: results/quant/gene.FPKM.tsv"
  else
    echo "- TPM matrix: results/quant/gene.TPM.tsv"
  fi
  [[ "${CONTIG_COVERAGE:-no}" == "yes" ]] && echo "- contig depth table: results/quant/contig.depth.tsv"
  echo
  echo "## Taxonomy (${TAXONOMY_TOOL})"
  echo "- per-rank abundance tables: results/taxonomy/Table_taxa_*.tsv"
  echo "- gene-taxonomy mapping: results/taxonomy/gene_taxonomy.tsv"
  echo
  echo "## Function (${FUNCTION_TOOL})"
  echo "- annotations: results/function/eggnog.annotations.tsv"
  echo "- KO/CAZy/COG abundance: results/function/KO.tsv, CAZy.tsv, COG.tsv"
  echo "- KEGG completeness: results/function/KEGG_module_completeness.tsv / KEGG_pathway_completeness.tsv (or *_detected.tsv)"
  echo
  echo "## Binning (${BINNING_TOOL})"
  echo "- MAG list: results/mags/MAG_list.txt"
  echo "- quality table: results/mags/MAG_quality.tsv"
  if [[ "${MAG_FILTER:-no}" == "yes" ]]; then
    echo "- filtered genomes: results/mags/filtered_genomes/ (completeness>=${MAG_MIN_COMPLETENESS} contamination<=${MAG_MAX_CONTAMINATION})"
  fi
  if [[ "${MAG_QUANT:-no}" == "yes" ]]; then
    echo "- MAG abundance: results/mags/abundance/MAG_abundance.tsv (coverM)"
  fi
  if [[ "${MAG_ANNOTATE:-no}" == "yes" ]]; then
    echo "- GTDB-Tk taxonomy: results/mags/annotations/gtdb/"
    echo "- Prodigal genes: results/mags/annotations/prodigal/"
    echo "- KofamScan KO: results/mags/annotations/kofam/ + kofam_summary.tsv"
  fi
  echo
  echo "## Software versions"
  echo "- results/software_versions.tsv"
} > "${SUMMARY}"

# parameter snapshot
{
  for v in PROJECT_DIR WORK_DIR RESULT_DIR LOG_DIR FASTQ_DIR GROUP_FILE QC_NEEDED HOST_GENOME HOST_FASTA ASSEMBLY_MODE \
           GENE_MIN_CONTIG_LEN BIN_MIN_CONTIG_LEN GENE_CLUSTERER QUANT_TOOL TAXONOMY_TOOL \
           TAXA_FILTER FUNCTION_TOOL BINNING_TOOL MAG_BINNERS RUN_DREP CHECKM2_DB \
           CONTIG_COVERAGE KEGG_MODULE_DEF KEGG_PATHWAY_DEF \
           THREADS CONCURRENT_JOBS MEMORY_GB; do
    printf '%s\t%s\n' "${v}" "${!v:-}"
  done
} > "${RESULT_DIR}/summary/params.tsv"

say ""
say "==== $(date '+%F %T') pipeline finished ===="
say "summary report: ${SUMMARY}"
say "pipeline log: ${LOG_FILE}"
