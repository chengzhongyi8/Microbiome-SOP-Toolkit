# Databases

Large reference databases are **never committed to this repository**.  You
download them once on your server and point the workflow at them via CLI
flags, the YAML config, or environment variables.  This page lists every
database the workflows use, what it is for, recommended versions, and how to
set its path.

General rule: keep databases outside the pipeline directory (e.g.
`/path/to/databases/...`) so that syncing/updating the pipeline never
overwrites them.

### One place to set database paths per server

Copy `config/microbiome-toolkit.conf.example` to `~/.microbiome-toolkit.conf`
and set every database path once.  Both workflows source this file
automatically, so per-project YAML configs only need the project-specific
bits.  Precedence: CLI flags > project YAML (`--config`) > `~/.microbiome-toolkit.conf`
> `config.sh` defaults.

---

## 16S workflow

### SILVA classifier

| | |
|---|---|
| Purpose | taxonomy classification of 16S ASVs (`classify-sklearn`) |
| Files | `silva-138-99-515-806-nb-classifier.qza` (V4), or matching classifiers for your region |
| Recommended | SILVA 138.1, 99% identity, region-specific NB classifier (QIIME2 `.qza`) |
| Required | **yes** (or any classifier compatible with your amplicon region) |
| Download | https://docs.qiime2.org → “Data resources” → “Taxonomic classifiers” (also the QIIME2 forum / `resources.q2f.org`) |
| Set path | `--classifier /path/to/silva-138-99-515-806-nb-classifier.qza` or `classifier:` in YAML, or `CLASSIFIER` env |
| Notes | the classifier must match the amplification region/primer orientation (e.g. V4 data ↔ 515F/806R classifier).  `--classifier-dir` auto-discovers by region keywords. |

---

## Metagenome workflow

### Host genomes (for host removal)

| | |
|---|---|
| Purpose | remove host (plant/animal/human) reads with bowtie2 |
| Files | host genome FASTA (`.fna`/`.fa`); bowtie2 index is built automatically |
| Recommended | RefSeq / Ensembl Genomes assembly for your organism |
| Required | only if you want host removal (module 01) |
| Download | https://www.ncbi.nlm.nih.gov/genome/ · https://ensemblgenomes.org/ |
| Set path | `--host-fasta <file> --host-name <species>` (auto-build) or `--host-genome <index prefix>` |
| Notes | keep in `host_db_dir` (default `/path/to/databases/host_db`); genomes > 4 Gb get `--large-index` automatically |

### NR protein database (DIAMOND)

| | |
|---|---|
| Purpose | gene-level taxonomy: `diamond blastp` of catalog proteins vs NR, then MEGAN LCA |
| Files | `nr.dmnd` (DIAMOND-formatted NR) |
| Recommended | current NR release (2023–2026 builds are fine; ~140–200 Gb) |
| Required | **yes** for `--taxonomy nr-megan` |
| Download | https://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz → `diamond makedb --in nr.gz --db nr` (memory-heavy; or download a community `.dmnd`) |
| Set path | `--nr-db /path/to/nr.dmnd` or `nr_db:` in YAML, or `NR_DMND` env |

### MEGAN accession → taxid mapping

| | |
|---|---|
| Purpose | map DIAMOND accessions to taxonomy for `blast2lca` |
| Files | `prot_acc2tax-*.abin` (or `.map`) |
| Recommended | a recent `prot_acc2tax` mapping from MEGAN (e.g. Jul-2022 or newer) |
| Required | **yes** for `--taxonomy nr-megan` |
| Download | https://software-ab.informatik.uni-tuebingen.de/download/megan6/ (also `megan-map` on Bioconda mirrors) |
| Set path | `--megan-map /path/to/prot_acc2tax.abin` or `megan_map:` in YAML |

### MEGAN blast2lca (standalone tool)

| | |
|---|---|
| Purpose | LCA computation (not a database, but required for `nr-megan`) |
| Files | `blast2lca` script (MEGAN community edition) |
| Recommended | MEGAN 6.x tools |
| Required | **yes** for `--taxonomy nr-megan`; **not installable via conda** |
| Download | https://software-ab.informatik.uni-tuebingen.de/download/megan6/ (the MEGAN `.zip` includes `tools/blast2lca`) |
| Set path | `BLAST2LCA=/path/to/blast2lca` env or edit `workflows/metagenome/config.sh`; falls back to PATH |

### Kraken2 database (reserved alternative)

| | |
|---|---|
| Purpose | read-level taxonomy (`--taxonomy kraken2`) |
| Files | standard Kraken2 DB directory |
| Recommended | Standard (archaea+bacteria+viral) or PlusPF, current build |
| Required | only if you use `--taxonomy kraken2` |
| Download | https://benlangmead.github.io/aws-indexes/k2 |
| Set path | `--kraken2-db /path/to/kraken2_db` or `kraken2_db:` in YAML |

### eggNOG database (eggNOG-mapper)

| | |
|---|---|
| Purpose | functional annotation (module 06) |
| Files | eggNOG data dir (e.g. `eggnog_2022_12_4`, ~50–70 Gb) with `eggnog.db`, `*.dmnd` etc. |
| Recommended | eggNOG 5.0 latest release (e.g. 2022-12-04); must match `emapper.py` version ≥ 2.1 |
| Required | **yes** for `--function eggnog` |
| Download | `emapper.py --data_dir /path/to/eggnog -i empty.faa` auto-downloads, or https://github.com/eggnogdb/eggnog-mapper/wiki/eggNOG-mapper-v2.1.5-–-user-manual#downloading-eggnog-databases |
| Set path | `--eggnog-db /path/to/eggnog_data_dir` or `eggnog_db:` in YAML, or `EGGNOG_DATA_DIR` env |
| Notes | `--eggnog-shm yes` copies the DB to `/dev/shm` before annotating (much faster; check space) |

### KEGG definition files (optional, module 06)

| | |
|---|---|
| Purpose | KEGG Module / Pathway completeness matrices |
| Files | `module.ko`, `module` (names), `ko00001.keg` |
| Recommended | current KEGG release |
| Required | no — without them module 06 outputs detection tables only |
| Download | `wget ftp://ftp.genome.jp/pub/kegg/module/module.ko`, `.../module`, `wget ftp://ftp.genome.jp/pub/kegg/brite/ko/ko00001.keg` |
| Set path | `--kegg-module-def/--kegg-pathway-def/--kegg-module-name` or `kegg.*` in YAML |
| Notes | free for non-commercial academic use |

### CheckM2 database

| | |
|---|---|
| Purpose | MAG completeness/contamination (module 07) |
| Files | `uniref100.KO.1.dmnd` (CheckM2 DB; ~8–12 Gb) |
| Recommended | CheckM2 v1.0.2+ database |
| Required | **yes** for `--binning metawrap` (module 07) |
| Download | `checkm2 database --download` or https://data.ace.uq.edu.au/public/CheckM2_database/ |
| Set path | `--checkm2-db /path/to/checkm2_db` (directory or `.dmnd` file) or `checkm2_db:` in YAML, or `CHECKM2_DB` env |

### dRep / checkm (bundled, module 07)

| | |
|---|---|
| Purpose | dRep ANI dereplication; checkm for dRep's optional quality filter |
| Files | none (checkm database only if you keep dRep's quality filter on) |
| Recommended | dRep ≥ 3.4, fastANI, checkm-genome in the `drep` env |
| Required | dRep: **yes** when `--run-drep yes`; checkm DB: only if `--drep-ignore-quality no` |
| Download | `conda env create -f envs/drep.yml` (tools); checkm DB via `checkm data setRoot` if used |
| Set path | `--drep-ignore-quality yes` to skip checkm filtering (recommended; CheckM2 evaluates quality later) |

### GTDB reference database (GTDB-Tk)

| | |
|---|---|
| Purpose | MAG taxonomy (module 08, `--mag-annotate yes`) |
| Files | GTDB reference data dir (e.g. `gtdbtk_r220`; ~100+ Gb) |
| Recommended | GTDB r214 or r220+ matching your `gtdbtk` version (v2.4.x ↔ r220) |
| Required | **yes** for `--mag-annotate yes` |
| Download | `gtdbtk` conda package ships a downloader; see https://ecogenomics.github.io/GTDBTk/ (or `wget https://data.ace.uq.edu.au/public/gtdb/data/releases/...`) |
| Set path | `--gtdbtk-db /path/to/gtdbtk_data` or `gtdbtk_db:` in YAML, or export `GTDBTK_DATA_PATH` |
| Notes | keep `--gtdbtk-pplacer-cpus` small (1 default; ≤ 4) to avoid pplacer memory blowup |

### KofamScan database

| | |
|---|---|
| Purpose | KEGG KO annotation of MAG proteins (module 08, `--mag-annotate yes`) |
| Files | `profiles/` (HMM profiles) + `ko_list` |
| Recommended | current KEGG release (kofam_scan 1.3.0) |
| Required | **yes** for `--mag-annotate yes` |
| Download | `wget ftp://ftp.genome.jp/pub/db/kofam/ko_list.gz` and `profiles.tar.gz` (KEGG FTP; free for academic use) |
| Set path | `--kofam-profile /path/to/kofam/profiles --kofam-ko-list /path/to/kofam/ko_list` or `kofam_*` in YAML |

---

## Checklist before first run

| Database / tool | Needed when | Config key |
|---|---|---|
| SILVA classifier | 16S workflow (always) | `classifier` |
| host genome (+index) | metagenome, host removal wanted | `host_genome` / `host_fasta` |
| NR `.dmnd` + MEGAN map + blast2lca | `--taxonomy nr-megan` | `nr_db`, `megan_map`, `BLAST2LCA` |
| eggNOG data dir | `--function eggnog` | `eggnog_db` |
| CheckM2 DB | `--binning metawrap` | `checkm2_db` |
| GTDB data dir | `--mag-annotate yes` | `gtdbtk_db` |
| KofamScan profiles + ko_list | `--mag-annotate yes` | `kofam_profile`, `kofam_ko_list` |
| KEGG module.ko etc. | optional completeness | `kegg.*` |
| Kraken2 DB | `--taxonomy kraken2` only | `kraken2_db` |
