#!/usr/bin/env bash
# Purpose: central Conda initialization and per-tool environment names for metagenome modules.
# Input: user edits to match the server. Output: variables sourced through project_config.sh.
# Software/resources: none; configuration only.

# Current workstation reports /opt/anaconda3, but this must be the SERVER path.
CONDA_SH="/path/to/miniconda3/etc/profile.d/conda.sh"
CONDA_MODULE="" # Optional module name; leave empty unless the cluster administrator confirms it.

ENV_SEQKIT="seqkit"
ENV_HOST_REMOVAL="bowtie2"
ENV_ASSEMBLY="megahit"
ENV_GENE="prodigal"
ENV_CLUSTER_MMSEQS="mmseqs2"
ENV_CLUSTER_CDHIT="cd-hit"
ENV_SALMON="salmon"
ENV_KAIJU="kaiju"
ENV_ANNOTATION="eggnog2.0.1"
ENV_MAPPING="metawrap"
ENV_BINNING="metawrap"
ENV_MAG_QC="checkm2"
ENV_MAG_DEREP="checkm"
ENV_MAG_TAXONOMY="gtdbtk"
ENV_COVERM="METABOLIC_v4.0"
ENV_VIRUS_GENOMAD="genomad"
ENV_VIRUS_VIRSORTER2="vs2"
ENV_CHECKV="checkv"
ENV_VRHYME="vRhyme"
ENV_IPHOP="iphop_env"
ENV_HOST_EVIDENCE="virus_host"
ENV_DRAMV="dramv"
ENV_TRAITS="METABOLIC_v4.0"

