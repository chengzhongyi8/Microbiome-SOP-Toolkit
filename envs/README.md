# Conda environments

This directory contains reproducible Conda environment definitions for both
workflows.  Each environment is created with:

```bash
conda env create -f envs/<file>.yml
```

All channels are `conda-forge` / `bioconda` (Linux x86_64).  Versions are
expressed as floors (`>=`) so Conda resolves the newest compatible build while
the workflows' tested behaviour is preserved; QIIME2 is the exception — it is
pinned to the official **2020.11.1** core distribution (the version installed
on the production server the SOPs were developed on).

## Which environment for which step?

### 16S workflow (`microbiome-toolkit 16s`)

| Env file | Env name | Used by | Notes |
|---|---|---|---|
| `16s.yml` | `qiime2` | every QIIME2 step (02–07) | Official QIIME2 **2020.11.1** core distribution (Python 3.6), vendored from `https://data.qiime2.org/distro/core/qiime2-2020.11-py36-linux-conda.yml` (fully pinned, 432 deps). Includes q2-dada2, q2-feature-classifier, q2-taxa, q2-phylogeny, q2-cutadapt, q2-alignment, q2-diversity, MAFFT, FastTree, biom-format. If your server already has QIIME2, point `--qiime2-env` at it and skip creating this environment. |
| `microeco.yml` | `microeco` | final `file2meco` validation (step 07, optional) | R + phyloseq/dada2; `file2meco`/`microeco` are installed from GitHub (see below). |

```bash
conda env create -n qiime2 --file envs/16s.yml
conda env create -f envs/microeco.yml
conda activate microeco
Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")'
Rscript -e 'remotes::install_github("ChiLiubio/file2meco")'
Rscript -e 'remotes::install_github("ChiLiubio/microeco")'
```

`file2meco` and `microeco` are not on Conda channels; they must be installed
from GitHub with `remotes`.  The 16S pipeline only needs the `microeco` env
when `optional.run_file2meco_validation` is enabled (`yes`/`auto`).

### Metagenome workflow (`microbiome-toolkit metagenome`)

| Env file | Env name | Module(s) | Tools |
|---|---|---|---|
| `metagenome_qc.yml` | `metagenome_qc` | 01 QC/dehost | kneaddata, Trimmomatic, bowtie2, FastQC, MultiQC |
| `metagenome_base.yml` | `metagenome_base` | 02–05 (+07/08 helpers) | MEGAHIT, seqkit, Prodigal, CD-HIT, MMseqs2, Salmon, BWA, SAMtools, DIAMOND, fastANI, python |
| `metagenome_eggnog.yml` | `metagenome_eggnog` | 06 function | eggNOG-mapper (`emapper.py`), DIAMOND, MMseqs2 |
| `metawrap.yml` | `metawrap` | 07 binning | metaWRAP, MetaBAT2, MaxBin2, CONCOCT |
| `das_tool.yml` | `das_tool` | 07 refinement (optional) | DAS_Tool (R + diamond) |
| `drep.yml` | `drep` | 07 dereplication | dRep, fastANI, checkm, mash |
| `checkm2.yml` | `checkm2` | 07 MAG quality | CheckM2 (+ diamond, prodigal) |
| `gtdbtk.yml` | `gtdbtk` | 08 MAG taxonomy | GTDB-Tk, pplacer, fastANI, mash |
| `mag_annotation.yml` | `mag_annotation` | 08 MAG abundance/annotation | coverM, KofamScan, HMMER |

```bash
for f in envs/metagenome_qc.yml envs/metagenome_base.yml envs/metagenome_eggnog.yml \
         envs/metawrap.yml envs/das_tool.yml envs/drep.yml envs/checkm2.yml \
         envs/gtdbtk.yml envs/mag_annotation.yml; do
  conda env create -f "$f"
done
```

The environment names above are the defaults in
`workflows/metagenome/config.sh`; if you name yours differently, pass
`--qc-env NAME`, `--assembly-env NAME`, … or set them in the YAML config
(`conda.qc_env: ...`).

## Software and versions per environment

Version floors (`>=`) in the files let Conda resolve the newest compatible
build; the "latest known" column shows what was available on conda-forge /
bioconda at packaging time.  The pipeline records the actually-installed
versions at runtime in `<project>/results/software_versions.tsv`.

| Env file | Software (floor → latest known) |
|---|---|
| `16s.yml` (qiime2) | **fully pinned official 2020.11.1 core distro**: qiime2 2020.11.1, q2cli 2020.11.1, q2-dada2 2020.11.1, q2-feature-classifier 2020.11.1, q2-taxa 2020.11.1, q2-phylogeny 2020.11.1, q2-cutadapt 2020.11.1, q2-alignment 2020.11.1, q2-demux 2020.11.1, q2-types 2020.11.1, q2-feature-table 2020.11.1, q2-metadata 2020.11.1, q2-diversity 2020.11.1, q2-quality-filter 2020.11.1 · python 3.6.12 · biom-format 2.1.10 · cutadapt 3.1 · mafft 7.475 · fasttree 2.1.10 · scikit-learn 0.23.1 |
| `microeco.yml` | r-base ≥4.2, r-remotes, r-data.table, r-ape, r-vegan, r-igraph, r-ggpubr, bioconductor-phyloseq, bioconductor-dada2 · file2meco + microeco (GitHub latest, installed via remotes) |
| `metagenome_qc.yml` | kneaddata ≥0.12.0 (0.12.4) · fastqc ≥0.12.1 (0.12.1) · multiqc ≥1.20 (1.35) · trimmomatic ≥0.39 (0.41) · bowtie2 ≥2.5 (2.5.5) · samtools ≥1.17 (1.24) |
| `metagenome_base.yml` | python ≥3.8 · megahit ≥1.2.9 (1.2.9) · seqkit ≥2.5.0 (2.13.0) · prodigal ≥2.6.3 (2.6.3) · cd-hit ≥4.8.1 (4.8.1) · mmseqs2 ≥15.3 (17.b804f) · salmon ≥1.10 (2.5.1) · bwa ≥0.7.17 (0.7.19) · samtools ≥1.17 (1.24) · diamond ≥2.1 (2.2.5) · fastani ≥1.33 (1.34) |
| `metagenome_eggnog.yml` | python ≥3.8 · eggnog-mapper ≥2.1.9 (2.1.15) · diamond ≥2.1 (2.2.5) · mmseqs2 ≥15.3 · biopython |
| `metawrap.yml` | metawrap ≥1.2 (1.2) · metabat2 (2.18) · maxbin2 (2.2.7) · concoct (1.1.0) · bowtie2 ≥2.5 · samtools ≥1.17 |
| `das_tool.yml` | das_tool ≥1.1.6 (1.1.7) · r-base · r-docopt · diamond ≥2.1 · prodigal ≥2.6 |
| `drep.yml` | drep ≥3.4 (3.7.1) · fastani ≥1.33 (1.34) · checkm-genome ≥1.2 (1.2.5) · mash ≥2.3 |
| `checkm2.yml` | checkm2 ≥1.0.2 (1.1.0) · diamond ≥2.1 · prodigal ≥2.6 |
| `gtdbtk.yml` | gtdbtk ≥2.4.1 (2.7.2) · pplacer · fastani ≥1.33 · mash ≥2.3 |
| `mag_annotation.yml` | python ≥3.8 · coverm ≥0.7 (0.8.0) · kofamscan ≥1.3.0 (1.3.0) · hmmer ≥3.3 |

Not in any Conda package (install separately, set path in config):

| Tool | Version note | Used by |
|---|---|---|
| MEGAN `blast2lca` | MEGAN 6.x standalone Java tool | metagenome module 05 (`--taxonomy nr-megan`) — set `BLAST2LCA` |
| SILVA classifier `.qza` | SILVA 138.1 99% region-specific NB classifier | 16S step 05 — set `--classifier` |

## Design notes

- **Environments are intentionally split.** eggNOG-mapper pins its own Python
  and search-tool versions; metaWRAP/GTDB-Tk/CheckM2/dRep/coverM each have
  conflicting or heavy dependency trees.  Forcing them into one environment
  produces unresolvable or broken installs — the workflow activates the right
  environment per module automatically (`activate_conda_env.sh`).
- **No version over-pinning.** Only QIIME2 is fully pinned (official distro).
  The other files use `>=` floors; if a specific known-good combo is needed
  (e.g. `metawrap=1.3.2`), pin it in your own copy.
- **`blast2lca` (MEGAN)** is a standalone Java tool — it is NOT in any Conda
  package.  Download MEGAN's `blast2lca` script/tools and set `BLAST2LCA`
  (see `docs/DATABASES.md`).
- **Python helper scripts** in `workflows/metagenome/bin/*.py` use the Python
  standard library only (Python ≥ 3.6); no extra pip packages are needed.
- The `16s.yml` file is the unmodified official
  `qiime2-2020.11-py36-linux-conda.yml` (QIIME2 2020.11.1, core distribution)
  from https://data.qiime2.org/distro/core/.  It is vendored so the repository
  is reproducible without extra network access to QIIME2.
