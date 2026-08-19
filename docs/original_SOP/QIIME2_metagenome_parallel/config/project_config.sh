#!/usr/bin/env bash
# Purpose: central project strategy, thresholds, safety switches, and resource contract.
# Input: user edits only. Output: shell variables sourced by module scripts.
# Software/resources: none; parameter file only.

PROJECT_DIR="/path/to/metagenome_project"
SAMPLES_TSV="/path/to/this/pipeline/config/samples.tsv"
METAGENOME_READ_DIR="/path/to/metagenome_reads"
METATRANSCRIPTOME_READ_DIR="/path/to/metatranscriptome_reads"

# single: assemble each sample independently; coassembly: pool reads by group.
ASSEMBLY_STRATEGY="single"
MEGAHIT_MIN_CONTIG_LEN="500"
MEGAHIT_K_MIN="21"
MEGAHIT_K_MAX="141"
MEGAHIT_K_STEP="10"
GENE_MIN_CONTIG_LEN="500"
BIN_MIN_CONTIG_LEN="1500"
VIRUS_MIN_CONTIG_LEN="5000"

# Resource contract: concurrent_jobs * threads_per_job must not exceed total_threads.
TOTAL_THREADS="32"
CONCURRENT_JOBS="2"
THREADS_PER_JOB="16"
MEMORY_GB="128"

# Never delete intermediate results unless both values are exactly yes.
ALLOW_DELETE_INTERMEDIATES="no"
CONFIRM_DELETE_INTERMEDIATES="no"

# Optional host removal.
RUN_HOST_REMOVAL="no"
HOST_REFERENCE=""

# Gene catalog: mmseqs2 (recommended for very large catalogs) or cd-hit-est (legacy-compatible).
GENE_CLUSTERER="mmseqs2"
GENE_MIN_IDENTITY="0.95"
GENE_MIN_COVERAGE="0.90"

# MAG modules. Comma-separated subset: metabat2,maxbin2,concoct.
MAG_BINNERS="metabat2,maxbin2,concoct"
RUN_MAG_REASSEMBLY="no"
MAG_MIN_COMPLETENESS="50"
MAG_MAX_CONTAMINATION="10"
DREP_PRIMARY_ANI="0.90"
DREP_SECONDARY_ANI="0.99"

# Virus modules: genomad or virsorter2. Supplementary tools remain opt-in.
VIRUS_PRIMARY="genomad"
RUN_DEEPVIRFINDER="no"
RUN_VIBRANT="no"
RUN_COBRA="no"
RUN_VRHYME="no"
VOTU_IDENTITY="0.95"
VOTU_COVERAGE="0.85"

# Quantification thresholds.
MIN_READ_IDENTITY="95"
MIN_READ_ALIGNED_PERCENT="90"

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CONFIG_DIR}/conda_envs.sh"
