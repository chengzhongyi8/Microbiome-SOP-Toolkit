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
