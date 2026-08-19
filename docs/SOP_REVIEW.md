# SOP Review — issues found and decisions made

This document records everything that was **found** while auditing the two
original SOPs and **decided** while packaging them into this toolkit.  The
core analysis logic of both pipelines is preserved; changes listed here are
parameterization, portability, and reproducibility fixes.  Nothing in the
original SOP directories (`~/Desktop/QIIME2_analysis_SOP`,
`~/Desktop/宏基因组数据分析 SOP 构建`) was modified.

Format per issue: **Issue / Current implementation / Why it matters /
Suggested modification / Priority** (Critical · Recommended · Optional).

---

## A. 16S workflow (`QIIME2_analysis_SOP/qiime2_amplicon/`)

### A1. Metadata template ends with a blank line that breaks sample-ID checks

- **Issue**: `metadata_template.tsv` has a trailing empty line, and
  `01_make_manifest.sh` did not skip empty rows when extracting metadata
  sample IDs (`awk 'NR>1 && $1 !~ /^#/ …'`).
- **Current implementation**: an empty string is treated as a sample ID →
  `comm` reports a manifest/metadata mismatch → the pipeline errors out even
  with the bundled template.
- **Why it matters**: first-time users following the docs hit an immediate,
  confusing failure.
- **Suggested modification**: skip empty rows (`NF` guard) in the awk; ship a
  clean template.
- **Status**: FIXED in `workflows/16s/steps/01_make_manifest.sh` and
  `examples/16s/metadata_template.tsv`.  Priority: **Critical**.

### A2. One-shot runner ignored DADA2 parameters edited into `config.local.sh`

- **Issue**: `run_all.sh` deliberately ignored `TRIM_LEFT_*`/`TRUNC_LEN_*`
  in `config.local.sh` (only CLI values or `config.sh` defaults were used),
  which contradicted the manual-mode docs ("fill config.sh/config.local.sh").
- **Current implementation**: two competing entry points with different
  behaviour → DADA2 overrides silently not applied in one-shot mode.
- **Why it matters**: a reproducibility foot-gun for manual users.
- **Suggested modification**: one documented parameter entry point — CLI flags
  and the YAML config file.  Per-project config is still written (into
  `<project>/work/`), but DADA2 overrides should go through flags/YAML.
- **Status**: FIXED by design in `bin/run_16s.sh` (`--config` + flags only;
  documented in `docs/PARAMETERS.md`).  Priority: **Critical**.

### A3. `config.local.sh` was written into the shared toolkit directory

- **Issue**: the one-shot runner wrote `config.local.sh` next to the scripts,
  so running two projects from the same checkout overwrote each other's
  config.
- **Current implementation**: per-project config lived in a shared dir.
- **Suggested modification**: write per-project config into
  `<project>/work/config.local.sh`.
- **Status**: FIXED in `bin/run_16s.sh`; step scripts also source the
  project-level file.  Priority: **Recommended**.

### A4. Final taxonomy artifact loses the confidence column

- **Issue**: after ID synchronization the taxonomy is re-imported with
  `HeaderlessTSVTaxonomyFormat` (feature-id + taxonomy only); per-ASV
  confidence remains only in `taxonomy-unfiltered.qzv`.
- **Current implementation**: confidence is not lost from the analysis, but a
  user reading `results/final/taxonomy.qza` sees no confidence.
- **Why it matters**: minor surprise; confidence is still available.
- **Suggested modification**: document it (done in `docs/16S_SOP.md`).
  Priority: **Optional** (documented, not changed).

### A5. `--p-include Bacteria` makes some `EXCLUDE_*` options redundant

- **Issue**: `q2-taxa` matches are substring-based; `--p-include Bacteria`
  already excludes Archaea/Eukaryota/Unassigned, so
  `EXCLUDE_ARCHAEA/EUKARYOTA/UNASSIGNED_DOMAIN` are semantically redundant in
  the default configuration.
- **Current implementation**: options remain, all harmless.
- **Why it matters**: confusing option semantics; not a bug.
- **Suggested modification**: keep as-is (they matter when
  `TARGET_DOMAIN` is changed/emptied), document the interaction.
  Priority: **Optional**.

### A6. Auto-trunc step leaves no resume marker when disabled

- **Issue**: with `AUTO_TRUNC=no`, `08_auto_dada2_params.sh` exits without
  writing `dada2_auto.env`, so the step re-runs on every `--resume` pass.
- **Current implementation**: harmless (cheap step) but noisy logging.
- **Suggested modification**: write an empty marker when disabled.
- **Status**: left as-is (cheap step); documented.  Priority: **Optional**.

### A7. `qiime2-sop` defaults inconsistent with `config.sh`

- **Issue**: the wrapper defaulted `--min-samples 2`, `--threads 32` and
  hard-coded a personal conda path / PBS node name.
- **Current implementation**: defaults differed from the pipeline config and
  contained personal server paths.
- **Suggested modification**: sanitize defaults, keep wrapper thin, personal
  defaults only via `~/.qiime2-sop.conf`.
- **Status**: FIXED in `bin/qiime2-sop`.  Priority: **Recommended**.

### A8. QIIME2 version follows the server installation

- **Issue**: the original README mentioned a specific future distribution;
  the pipeline must work with the QIIME2 version actually installed on the
  production server.
- **Current implementation**: the server runs **QIIME2 2020.11.1** (core
  distribution, Python 3.6).  All QIIME2 commands used by this pipeline
  (import, demux summarize, cutadapt trim-paired, dada2 denoise-paired,
  classify-sklearn, taxa filter-table/filter-seqs, phylogeny
  align-to-tree-mafft-fasttree, diversity actions, tools peek/export) exist in
  2020.11.1.
- **Suggested modification**: pin `envs/16s.yml` to the official
  `qiime2-2020.11-py36-linux-conda.yml` (vendor of
  `https://data.qiime2.org/distro/core/qiime2-2020.11-py36-linux-conda.yml`)
  so fresh installs match the server; users with an existing QIIME2
  environment just set `--qiime2-env`.
- **Status**: DONE (`envs/16s.yml` = official 2020.11 core distro, fully pinned).
  Priority: **Recommended**.

---

## B. Metagenome workflow (`宏基因组数据分析 SOP 构建/metagenome_sop/`)

### B1. Server-specific absolute paths in `config.sh` / `run_metagenome.pbs` / `mg-sop`

- **Issue**: ~25 hard-coded personal paths
  (`/public/zycheng/…`, `/public/home/zycheng/…`, `node47`, `dastool117`,
  `METABOLIC_v4.0`, `eggnog2.0.1`, `gtdbtk-2.7.2`, `kofam`, …).
- **Current implementation**: config defaults pointed at a specific server.
- **Why it matters**: unusable and unsafe to publish.
- **Suggested modification**: neutral placeholders; all paths via CLI / YAML /
  env; conda env names defaulted to this repository's `envs/*` names.
- **Status**: FIXED in `workflows/metagenome/config.sh`,
  `run_metagenome.pbs.template`, `bin/mg-sop`.  Priority: **Critical**.

### B2. eggNOG module: `/dev/shm` copy and parallel CPU overbooking

- **Issue**: `EGGNOG_SHM=yes` copies the DB into `/dev/shm` (must check
  space); parallel `emapper` chunks each get `THREADS` — the worker now caps
  each chunk at `THREADS/CONCURRENT_JOBS`.
- **Current implementation**: chunk CPU already capped in the worker
  (`06_emapper.sh`); shm copy guarded by a space check.
- **Suggested modification**: keep guards, document `--eggnog-shm`.
- **Status**: preserved and documented.  Priority: **Recommended** (kept).

### B3. dRep/checkm interplay

- **Issue**: dRep's quality filter needs checkm + its DB; CheckM2 already
  evaluates MAG quality downstream.
- **Current implementation**: `--drep-ignore-quality yes` skips the checkm
  filter (dRep still dereplicates by ANI); otherwise `CHECKM_BIN_DIR` can be
  pointed at a checkm env.
- **Suggested modification**: document both modes; default the env file to
  include `checkm-genome` for dRep.
- **Status**: preserved; `envs/drep.yml` includes `checkm-genome`.
  Priority: **Optional**.

### B4. DAS_Tool in its own environment

- **Issue**: DAS_Tool needs R + docopt + diamond; forcing it into the
  metaWRAP env risks conflicts.
- **Current implementation**: the SOP already ran DAS_Tool from a separate
  env (`dastool117`); the toolkit ships `envs/das_tool.yml`.
- **Suggested modification**: keep DAS_Tool in its own env; config defaults to
  resolving `DAS_Tool` from PATH.
- **Status**: preserved.  Priority: **Optional**.

### B5. MaxBin2 contig-header normalization

- **Issue**: MaxBin2 replaces `|` in contig names with `_`; refinement tools
  need `|` back.
- **Current implementation**: module 07 rewrites the first `_` back to `|`
  when a bin lacks `|`.
- **Suggested modification**: keep; regression-tested in `tests/`.
- **Status**: preserved.  Priority: **Optional**.

### B6. CONCOCT output naming varies by version

- **Issue**: `clustering_gt1000.csv` vs `clustering.csv` vs prefixed names.
- **Current implementation**: module 07 auto-matches the CSV and errors with a
  directory listing if none found.
- **Status**: preserved.  Priority: **Optional**.

### B7. Resource defaults

- **Issue**: original defaults `THREADS=28`, `JOBS=8` (~224 cores) can exceed
  smaller nodes.
- **Current implementation**: toolkit defaults lowered to `THREADS=16`,
  `JOBS=4`, `MEMORY_GB=64`; documented that `threads*jobs` must fit the node.
- **Status**: CHANGED (safe defaults, user overrides).  Priority: **Recommended**.

---

## C. Third pipeline discovered inside `QIIME2_analysis_SOP/metagenome/`

- **Issue**: the "16S" SOP folder also contains a **second, parallel
  metagenome pipeline** (soybean-rhizosphere lineage: SLURM-based,
  samples.tsv-driven, no forced run-all, with **virome / virus-host / metaT /
  AMG / microbe-traits** modules, Kaiju taxonomy, geNomad/VirSorter2/CheckV,
  iPHoP, DRAM-v).
- **Current implementation**: it is not superseded by the MGTA-based
  `metagenome_sop` — the two are maintained in parallel for different
  projects (evidence: README rewrite table, `legacy_code/` isolation, current
  tool choices).
- **Why it matters**: a unified public toolkit must have one metagenome
  entry; silently merging both would change both pipelines.
- **Decision**: the unified `metagenome` workflow of this toolkit is the
  MGTA-based 8-module pipeline (the folder the user designated as the
  metagenome SOP).  The parallel soybean pipeline is preserved **verbatim**
  (sanitized) under `docs/original_SOP/QIIME2_metagenome_parallel/` with its
  own README, and its unique modules are listed in
  `docs/original_SOP/QIIME2_metagenome_parallel/README.md` so nothing is lost.
  Priority: **Critical (decision, no code change)**.

## D. What was deliberately NOT changed

- All core software choices (QIIME2 2020.11.1 pipeline; kneaddata → MEGAHIT →
  Prodigal → MMseqs2/CD-HIT → Salmon/BWA → DIAMOND+MEGAN → eggNOG → MetaWRAP
  binning → dRep → CheckM2 → GTDB-Tk/KofamScan/CoverM).
- All QC thresholds and filtering logic (DADA2 defaults, `MAX_EE=2.0`,
  cluster identity/coverage 0.95/0.90, bin quality ≥50/≤10, dRep ANI
  0.90/0.99, KEGG completeness 0.9, …).
- Step ordering and resume semantics of both pipelines.
- The two-stage manual QC checkpoint of the 16S workflow.
- Standalone-tool resolution (`blast2lca`, DAS_Tool) and the per-module conda
  environment model (multiple environments instead of one big one).
