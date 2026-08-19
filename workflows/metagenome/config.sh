#!/usr/bin/env bash
# ============================================================================
# config.sh — metagenome workflow default parameters
#
# Usage:
#   1) bin/run_metagenome.sh sources this file, then CLI flags override values;
#   2) a YAML config file (--config FILE.yaml) is applied before CLI flags;
#   3) environment variables with the same names are also honoured
#      (e.g. export CONDA_SH=/path/to/conda.sh before running).
#
# This file ships with NEUTRAL placeholders only.  It contains no personal
# paths, no passwords, and no tokens.  On your cluster you normally do NOT
# edit this file: pass values via CLI flags or a per-project YAML config
# (see config/metagenome_config.example.yaml).
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Project paths (required at runtime; set via CLI or config file)
# ---------------------------------------------------------------------------
PROJECT_DIR="${PROJECT_DIR:-/path/to/metagenome_project}"   # output root (results/ work/ logs/)
FASTQ_DIR="${FASTQ_DIR:-/path/to/fastq}"                    # raw/clean reads (_1.fq.gz / _2.fq.gz)

# ---------------------------------------------------------------------------
# Input naming convention (paired-end only; suffixes auto-detected)
# ---------------------------------------------------------------------------
SEQUENCING_MODE="paired"
R1_SUFFIXES=("_1.fq.gz" "_1.fastq.gz" "_R1.fq.gz" "_R1.fastq.gz" ".1.fq.gz" ".1.fastq.gz" ".R1.fq.gz" ".R1.fastq.gz" "_1.fq" "_1.fastq" "_R1.fq" "_R1.fastq" ".1.fq" ".1.fastq" ".R1.fq" ".R1.fastq")
R2_SUFFIXES=("_2.fq.gz" "_2.fastq.gz" "_R2.fq.gz" "_R2.fastq.gz" ".2.fq.gz" ".2.fastq.gz" ".R2.fq.gz" ".R2.fastq.gz" "_2.fq" "_2.fastq" "_R2.fq" "_R2.fastq" ".2.fq" ".2.fastq" ".R2.fq" ".R2.fastq")

# ---------------------------------------------------------------------------
# QC / host removal
# ---------------------------------------------------------------------------
# QC_NEEDED=yes : run kneaddata (Trimmomatic + Bowtie2) QC and host removal
# QC_NEEDED=no  : clean data already; only remove host (or pass through)
QC_NEEDED="yes"

# Host genome (either):
#   HOST_GENOME : bowtie2 index prefix, e.g. /db/host_db/wheat/wheat
#   HOST_FASTA  : host genome FASTA; the pipeline runs bowtie2-build once into
#                 ${HOST_DB_DIR}/${HOST_NAME}/ and reuses the index later
# Both empty = no host removal.
HOST_GENOME=""
HOST_FASTA=""
HOST_NAME=""
# Host genomes live OUTSIDE the pipeline directory (so syncing the repo never
# clobbers them).  Override with --host-db-dir or HOST_DB_DIR.
HOST_DB_DIR="${HOST_DB_DIR:-/path/to/databases/host_db}"

# Adapters / trimmomatic options (used when QC_NEEDED=yes).
# Leave ADAPTERS empty to skip ILLUMINACLIP (kneaddata defaults are used);
# point it at e.g. $CONDA_PREFIX/share/trimmomatic-*/adapters/TruSeq3-PE-2.fa
# when adapter contamination is expected.
ADAPTERS=""
TRIMMOMATIC_DIR=""                 # optional; empty lets kneaddata use its own
TRIMMOMATIC_OPTS="SLIDINGWINDOW:4:20 MINLEN:50"
# bowtie2 host-removal options (default --very-sensitive; do not add --dovetail
# unless your library is known to overlap).
BOWTIE2_OPTS="--very-sensitive"

# ---------------------------------------------------------------------------
# Assembly (MEGAHIT)
# ---------------------------------------------------------------------------
# per-sample: assemble each sample separately
# co-assembly: assemble all samples together (or per group when --group-file)
# both: do both
ASSEMBLY_MODE="per-sample"
MEGAHIT_K_MIN="21"
MEGAHIT_K_MAX="141"
MEGAHIT_K_STEP="10"
MEGAHIT_MIN_CONTIG_LEN="200"

# Filtering thresholds
GENE_MIN_CONTIG_LEN="1000"          # gene prediction: contigs >= N bp
BIN_MIN_CONTIG_LEN="1500"           # binning: contigs >= N bp

# ---------------------------------------------------------------------------
# Gene prediction + non-redundant gene catalog
# ---------------------------------------------------------------------------
GENE_SPLIT_SEQS="100000"            # prodigal chunk size (seqkit split2 -s)
GENE_CLUSTERER="mmseqs2"            # mmseqs2 (linclust) or cd-hit-est
GENE_MIN_IDENTITY="0.95"
GENE_MIN_COVERAGE="0.90"
TRANSLATE_TRIM="yes"

# ---------------------------------------------------------------------------
# Gene quantification
# ---------------------------------------------------------------------------
QUANT_TOOL="salmon"                 # salmon (default) or bwa
SALMON_K="31"

# ---------------------------------------------------------------------------
# Taxonomy annotation
# ---------------------------------------------------------------------------
TAXONOMY_TOOL="nr-megan"            # nr-megan (default); kraken2 reserved; none to skip
# blast2lca is MEGAN's standalone Java tool (not in conda).  Give a full path
# (BLAST2LCA) or leave as command name to be resolved from PATH.
BLAST2LCA="blast2lca"
NR_DMND=""                          # DIAMOND NR database (required for nr-megan)
MEGAN_MAP=""                        # MEGAN accession->taxid mapping (required for nr-megan)
DIAMOND_MAX_TARGET_SEQS="10"
DIAMOND_EVALUE="0.0001"
MEGAN_MIN_SUPPORT="50"
MEGAN_MIN_EVALUE="0.000001"
TAXA_FILTER="all"                   # all=keep all domains; bacteria=bacteria only

# Kraken2 (reserved; requires KRAKEN2_DB to be configured)
KRAKEN2_DB="/path/to/kraken2_db"

# ---------------------------------------------------------------------------
# Functional annotation (eggNOG-mapper)
# ---------------------------------------------------------------------------
FUNCTION_TOOL="eggnog"              # eggnog or none
EGGNOG_DATA_DIR=""                  # eggNOG database directory (required for eggnog)
EGGNOG_PROT_MIN_LEN="150"
EGGNOG_SPLIT_SEQS="2000000"
# Copy the eggNOG DB into /dev/shm before annotating (much faster, needs
# /dev/shm >= DB size).  Set EGGNOG_SHM=yes only when you verified space.
EGGNOG_SHM="no"

# ---------------------------------------------------------------------------
# KEGG Pathway / Module completeness (optional, run inside module 06)
# ---------------------------------------------------------------------------
# Definition files from KEGG FTP (free for non-commercial use):
#   module.ko:    ftp://ftp.genome.jp/pub/kegg/module/module.ko
#   module:       ftp://ftp.genome.jp/pub/kegg/module/module        (names, optional)
#   ko00001.keg:  ftp://ftp.genome.jp/pub/kegg/brite/ko/ko00001.keg
# Leave empty to degrade to "detection tables" (emapper KEGG_Module/KEGG_Pathway columns).
KEGG_MODULE_DEF=""
KEGG_MODULE_NAME=""
KEGG_PATHWAY_DEF=""
KEGG_COMPLETE_THRESHOLD="0.9"

# ---------------------------------------------------------------------------
# Contig coverage table (optional, inside module 04)
# ---------------------------------------------------------------------------
# CONTIG_COVERAGE=yes: map clean reads back to contigs with bowtie2 and report
# mean per-contig depth (results/quant/contig.depth.tsv). Extra full alignment;
# off by default.
CONTIG_COVERAGE="no"

# ---------------------------------------------------------------------------
# MAG binning (MetaWRAP-style binners + dRep + CheckM2)
# ---------------------------------------------------------------------------
BINNING_TOOL="none"                 # metawrap or none
MAG_BINNERS="metabat2,maxbin2,concoct"
RUN_BINNING_REFINE="yes"
RUN_BINNING_REASSEMBLE="no"
RUN_DREP="yes"
DREP_PRIMARY_ANI="0.90"
DREP_SECONDARY_ANI="0.99"
MAG_MIN_COMPLETENESS="50"
MAG_MAX_CONTAMINATION="10"
MAG_FILTER="no"                     # yes=filter MAGs after CheckM2 (filtered_genomes/)
CHECKM2_DB=""                       # CheckM2 database: dir (auto-find *.dmnd) or .dmnd path
# metaWRAP reads input mode:
#   plain: decompress clean reads to plain *.fastq for metaWRAP (compat, default)
#   gz:    symlink *.fastq.gz (metaWRAP >= 1.0.4 usually supports gz)
METAWRAP_READS_MODE="plain"
# DAS_Tool (multi-binner integration).  Leave empty to resolve from PATH.
DAS_TOOL=""
DAS_TOOL_DB=""
# dRep needs checkm for its quality filter; point CHECKM_BIN_DIR at the checkm
# env bin dir, or set DREP_IGNORE_QUALITY=yes (quality is evaluated by CheckM2 later).
CHECKM_BIN_DIR=""
# conda base bin dir (CheckM2 needs prodigal/diamond on PATH)
BASE_BIN_DIR=""
DREP_IGNORE_QUALITY="no"
CHECKM2_THREADS=""
S2B_TOOL=""                         # Fasta_to_Scaffolds2Bin.sh (resolved from PATH)

# ---------------------------------------------------------------------------
# MAG downstream annotation (module 08, optional; needs 07 first)
# ---------------------------------------------------------------------------
MAG_ANNOTATE="no"                   # yes=GTDB-Tk + Prodigal + KofamScan on dRep MAGs
MAG_QUANT="no"                      # yes=coverM MAG abundance (MAG x sample matrix)
MAG_QUANT_METHODS=""                # extra coverM --methods, e.g. "rpkm tpm"
ENV_GTDBTK="gtdbtk"
GTDBTK_DATA_PATH=""                 # GTDB reference database directory (required for annotate)
GTDBTK_PPLACER_CPUS="1"             # 1=serial (memory-safest); 2-4 faster, do not exceed 4
ENV_MAG_PRODIGAL="metagenome_base"
ENV_KOFAM="mag_annotation"
ENV_COVERM="mag_annotation"
KOFAM_PROFILE=""                    # KofamScan profiles dir (required for annotate)
KOFAM_KO_LIST=""                    # KofamScan ko_list (required for annotate)

# ---------------------------------------------------------------------------
# Conda (set on your server: `conda info --base` + /etc/profile.d/conda.sh)
# ---------------------------------------------------------------------------
CONDA_SH="/path/to/anaconda3/etc/profile.d/conda.sh"
CONDA_MODULE=""                     # e.g. miniconda; leave empty unless confirmed

# Per-module conda environment names (defaults match envs/ in this repository).
ENV_QC="metagenome_qc"              # kneaddata + fastqc + multiqc + bowtie2 + trimmomatic
ENV_ASSEMBLY="metagenome_base"      # megahit + seqkit
ENV_GENE="metagenome_base"          # prodigal + seqkit
ENV_CLUSTER_MMSEQS="metagenome_base"
ENV_CLUSTER_CDHIT="metagenome_base"
ENV_SALMON="metagenome_base"
ENV_BWA="metagenome_base"           # bwa + samtools
ENV_DIAMOND="metagenome_base"
ENV_MEGAN="metagenome_base"         # blast2lca is standalone (BLAST2LCA), not conda
ENV_KRAKEN2="metagenome_base"       # reserved
ENV_EGGNOG="metagenome_eggnog"      # emapper.py
ENV_METAWRAP="metawrap"
ENV_CHECKM2="checkm2"
ENV_DREP="drep"

# Standalone tools not on the conda PATH (defaults are command names resolved
# from PATH; set an absolute path only for custom installs)
SALMON="salmon"
BWA="bwa"
SAMTOOLS="samtools"
BOWTIE2="bowtie2"
DIAMOND="diamond"
COVERM="coverm"

# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------
THREADS="16"                # CPUs per task
CONCURRENT_JOBS="4"         # parallel tasks (THREADS*CONCURRENT_JOBS <= node cores)
MEMORY_GB="64"

# ---------------------------------------------------------------------------
# Runtime behaviour
# ---------------------------------------------------------------------------
RESUME="yes"                # skip steps whose outputs already exist
LOG_DIR="${LOG_DIR:-${PROJECT_DIR}/logs}"
WORK_DIR="${WORK_DIR:-${PROJECT_DIR}/work}"
RESULT_DIR="${RESULT_DIR:-${PROJECT_DIR}/results}"
