# 16S rRNA Amplicon Workflow (QIIME2)

This document describes the **16S amplicon workflow** step by step: what each
step does, which software it calls, what it consumes and what it produces.

**Quick entry points**

| Command | What it does |
|---|---|
| `microbiome-toolkit 16s --help` | one-command pipeline (import → … → summary) |
| `bash bin/run_16s.sh --help` | same pipeline, plain driver |
| `microbiome-toolkit 16s --input DIR --region 16S_V4 --classifier CLS.qza --submit` | PBS submission (`qiime2-sop` is a compatibility alias) |
| two-stage manual mode | `bash workflows/16s/run_qc.sh` then, after inspecting `results/qc/demux.qzv`, `bash workflows/16s/run_after_qc.sh` |

---

## Pipeline overview

```
Raw FASTQ (paired or single)
   │ 00 input check
   ▼
manifest.tsv ── 01 make manifest ──► results/qc/input_check.ok
   │
   ▼
02 import + demux quality summary ──► results/qc/demux.qza/.qzv   ◄── manual QC checkpoint
   │
   ▼
03 primer trimming (cutadapt, auto-detected) ──► work/demux-for-dada2.qza
   │
   ▼
08 auto DADA2 parameters ──► work/dada2_auto.env
   │
   ▼
04 DADA2 denoising ──► results/dada2/table, rep-seqs, stats
   │
   ▼
05 taxonomy classification + filtering ──► results/final/{feature-table, rep-seqs, taxonomy}.qza
   │
   ├──► 06 phylogeny (MAFFT + FastTree) ──► results/final/rooted-tree.qza
   │
   └──► 07 export for microeco ──► results/microeco_input/ (file2meco-ready)
                 │
                 ▼
              09 summary report ──► results/summary/
```

---

## Step 00 — Input check

- **Purpose**: validate configuration, FASTQ readability (optional gzip
  integrity), metadata header, and required system commands before anything
  expensive runs.
- **Input**: `config.sh` / per-project config, `FASTQ_DIR`, `METADATA_FILE`.
- **Software**: bash utilities only (no QIIME2).
- **Important parameters**: `CHECK_GZIP_INTEGRITY` (default `no`; `yes` runs
  `gzip -t` on every file — slow on TB-scale data).
- **Output**: `results/qc/input_check.ok` (marker) and a console report.

## Step 01 — Make manifest

- **Purpose**: discover FASTQ files, validate sample IDs (duplicates, illegal
  characters), pair R1/R2, compare against metadata, and optionally generate a
  minimal metadata table.
- **Input**: `FASTQ_DIR`, suffix arrays in `config.sh`, `METADATA_FILE`.
- **Software**: bash/awk/comm/uniq only.
- **Important parameters**: `SEQUENCING_MODE`, `AUTO_GENERATE_METADATA`.
- **Output**: `work/manifest.tsv` (QIIME2 manifest), `work/generated.env`,
  `results/qc/*_samples.txt` (ID consistency reports).

## Step 02 — Import and QC

- **Purpose**: import FASTQ into a QIIME2 artifact and produce the demux
  quality visualization.
- **Software**: `qiime tools import`, `qiime demux summarize`,
  `qiime tools export`.
- **Important parameters**: `SEQUENCING_MODE`, `COUNT_READS`.
- **Output**: `results/qc/demux.qza`, `results/qc/demux.qzv`,
  `results/qc/sample-sequence-counts.tsv`.
- **Manual checkpoint**: open `demux.qzv` and review quality curves, read
  depth and overlap **before** continuing (two-stage mode stops here).

## Step 03 — Primer trimming (optional, auto-detected)

- **Purpose**: trim residual primers at read 5′-ends before DADA2.
- **Software**: `qiime cutadapt trim-paired` / `trim-single` (q2-cutadapt),
  plus `bin/estimate_dada2_params.py --detect-primers` (stdlib Python).
- **Logic**: `RUN_CUTADAPT=yes` → always trim; else `AUTO_PRIMER_TRIM=yes`
  → detect primers in a sample of reads and trim only when found (both ends
  for paired data).
- **Important parameters**: `FORWARD_PRIMER`, `REVERSE_PRIMER`,
  `CUTADAPT_ERROR_RATE` (0.1), `CUTADAPT_MINIMUM_LENGTH` (1),
  `CUTADAPT_THREADS`.
- **Output**: `work/demux-for-dada2.qza`, `work/primers.env`
  (`PRIMER_DETECTED_F/R`, `CUTADAPT_RAN`).

## Step 08 — Auto DADA2 parameters

- **Purpose**: estimate DADA2 `trim-left` / `trunc-len` from the quality
  profile when manual values are not given (`AUTO_TRUNC=yes`).
- **Software**: `qiime tools export` + `bin/estimate_dada2_params.py`
  (samples ≤ `MAX_ESTIMATOR_SAMPLES` × `MAX_ESTIMATOR_READS` reads).
- **Important parameters**: `QUALITY_THRESHOLD` (20), `MIN_TRUNC_LEN` (50),
  `EXPECTED_AMPLICON_LENGTH` (overlap check), primer lengths for trim-left.
- **Output**: `work/dada2_auto.env` (`TRIM_LEFT_{F,R}_AUTO`,
  `TRUNC_LEN_{F,R}_AUTO`, diagnostics).
- **Caution**: auto values are *suggestions*.  For degraded or atypical
  libraries, review `demux.qzv` and set manual values.

## Step 04 — DADA2 denoising

- **Purpose**: resolve reads into ASVs (amplicon sequence variants) and
  optionally filter by sample prevalence.
- **Software**: `qiime dada2 denoise-paired` / `denoise-single` (q2-dada2),
  `qiime feature-table filter-features/filter-seqs`, `qiime metadata tabulate`,
  `qiime feature-table summarize/tabulate-seqs`.
- **Important parameters**: `TRIM_LEFT_{F,R}`, `TRUNC_LEN_{F,R}` (manual wins;
  otherwise auto), `MAX_EE` (2.0), `DADA2_THREADS`, `MIN_SAMPLES`
  (prevalence; empty = none), `METADATA_FILE`.
- **Output**: `results/dada2/table-unfiltered.qza`, `table-prevalence.qza`,
  `rep-seqs-*.qza`, `stats.qza/.qzv`, `table.qzv`, `rep-seqs.qzv`.

## Step 05 — Taxonomy classification and filtering

- **Purpose**: classify ASVs, keep the target domain, exclude organelles /
  non-target lineages, and **synchronize** table, sequences and taxonomy IDs.
- **Software**: `qiime feature-classifier classify-sklearn` (q2-feature-classifier),
  `qiime taxa filter-table/filter-seqs` (q2-taxa), `qiime feature-table
  filter-seqs`, `qiime tools export/import` (ID synchronization).
- **Important parameters**: `CLASSIFIER` (or `CLASSIFIER_DIR` auto-discovery),
  `CLASSIFIER_JOBS`, `TARGET_DOMAIN` (default `Bacteria`),
  `EXCLUDE_MITOCHONDRIA/CHLOROPLAST/ARCHAEA/EUKARYOTA/UNASSIGNED_DOMAIN`.
- **Output**: `results/taxonomy/taxonomy-unfiltered.qza/.qzv`,
  `results/final/feature-table.qza`, `rep-seqs.qza`, `taxonomy.qza/.qzv`.
- **Note**: the final `taxonomy.qza` (HeaderlessTSV) carries feature-id +
  taxonomy only; per-ASV confidence stays in `taxonomy-unfiltered.qzv`.

## Step 06 — Phylogeny

- **Purpose**: multiple alignment and tree building from final ASVs.
- **Software**: `qiime phylogeny align-to-tree-mafft-fasttree`
  (q2-phylogeny; internally MAFFT + FastTree).
- **Important parameters**: `PHYLOGENY_THREADS`.
- **Output**: `results/final/aligned-rep-seqs.qza`, `masked-aligned-rep-seqs.qza`,
  `unrooted-tree.qza`, `rooted-tree.qza` (rooted tree is what file2meco needs).

## Step 07 — Export for microeco

- **Purpose**: assemble the five file2meco inputs (feature table, sample table,
  taxonomy, rooted tree, rep-seqs), plain-text exports, ID consistency checks,
  optional QIIME2 diversity downstream, and optional `file2meco` smoke test.
- **Software**: `qiime tools export/peek`, `biom convert`, awk ID checks,
  optional `qiime diversity core-metrics-phylogenetic` / `alpha-rarefaction`,
  `qiime taxa barplot`, optional R `file2meco::qiime2meco()`.
- **Important parameters**: `RUN_CORE_METRICS` + `SAMPLING_DEPTH`,
  `RUN_ALPHA_RAREFACTION` + `ALPHA_MAX_DEPTH`, `RUN_TAXA_BARPLOT`,
  `RUN_FILE2MECO_VALIDATION` (yes/no/auto).
- **Output**: `results/microeco_input/` (five `.qza` + `metadata.tsv` +
  `feature-table.tsv` + `taxonomy.tsv` + `rooted-tree.nwk` + `rep-seqs.fasta`
  + `denoising-stats.tsv` + `sample-depth.tsv` + `file2meco_validation.tsv`),
  `results/downstream/` (optional).

## Step 09 — Summary report

- **Purpose**: human-readable summary of samples, reads, ASVs, classification
  rate, DADA2 parameters and output map.
- **Software**: bash/awk only.
- **Output**: `results/summary/summary_report.tsv`,
  `results/summary/README_summary.md`, `results/README.md`.

---

## Two-stage manual mode

1. `bash workflows/16s/run_qc.sh` — runs steps 00→01→02 and stops at the
   quality plot.
2. Inspect `results/qc/demux.qzv`; optionally set manual DADA2 parameters
   (CLI flags, YAML config, or `<project>/work/dada2_params.env`).
3. `bash workflows/16s/run_after_qc.sh` — runs steps 03→08→04→05→06→07→09.

## Outputs at a glance

| Path | Contents |
|---|---|
| `results/qc/` | demux artifacts, read counts, input validation |
| `results/dada2/` | DADA2 tables, rep-seqs, stats |
| `results/taxonomy/` | unfiltered taxonomy |
| `results/final/` | synchronized final table / rep-seqs / taxonomy / tree |
| `results/microeco_input/` | file2meco inputs + plain-text exports |
| `results/downstream/` | optional core metrics / rarefaction / barplot |
| `results/summary/` | summary report |
| `results/pipeline.log` | full pipeline log |
| `results/software_versions.tsv` | tool versions actually used |

## Software used

QIIME2 **2020.11.1** core distribution (env `qiime2`; matches the server version the SOP was validated on): q2cli,
q2-demux, q2-cutadapt (cutadapt), q2-dada2 (R dada2), q2-feature-table,
q2-metadata, q2-feature-classifier (scikit-learn), q2-taxa, q2-phylogeny
(MAFFT, FastTree), q2-diversity, biom-format.  Optional R (env `microeco`):
file2meco, microeco.  Python (stdlib): `bin/estimate_dada2_params.py`.

See `envs/README.md` for environment installation.
