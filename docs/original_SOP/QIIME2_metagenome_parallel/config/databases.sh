#!/usr/bin/env bash
# Purpose: central executable names and database paths; no project absolute paths belong elsewhere.
# Input: user edits only. Output: shell variables sourced by module scripts.
# Software/resources: none; parameter file only.

# Executables may be command names in PATH or absolute paths.
MEGAHIT="megahit"
SEQKIT="seqkit"
PRODIGAL="prodigal"
MMSEQS="mmseqs"
CD_HIT_EST="cd-hit-est"
SALMON="salmon"
EMAPPER="emapper.py"
KAIJU="kaiju"
KAIJU2TABLE="kaiju2table"
COVERM="coverm"
CHECKM2="checkm2"
DREP="dRep"
GTDBTK="gtdbtk"
GENOMAD="genomad"
VIRSORTER2="virsorter"
CHECKV="checkv"
IPHOP="iphop"
DRAMV="DRAM-v.py"

# Database locations. Leave empty until the corresponding module is used.
EGGNOG_DB=""
KAIJU_NODES=""
KAIJU_NAMES=""
KAIJU_FMI=""
CHECKM2_DB=""
GTDBTK_DATA_PATH=""
GENOMAD_DB=""
VIRSORTER2_DB=""
CHECKV_DB=""
IPHOP_DB=""
DRAM_DB=""
