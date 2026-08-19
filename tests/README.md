# Tests

Three test suites are provided.  **None of them requires a bioinformatics
installation** — they use stub tools, fake data and stdlib Python.

```bash
bash tests/run_static_checks.sh     # syntax, YAML, CLI, 16S smoke (fast)
bash tests/run_small_tests.sh       # Python-helper numerics + drivers (fast)
bash tests/run_e2e_stub.sh          # full 8-module metagenome dry run (stubs)
```

## What each suite verifies

| Suite | Coverage |
|---|---|
| `run_static_checks.sh` | `bash -n` on all shell scripts; `py_compile` on all Python; YAML parse of `envs/` + `config/`; `--help`/`--version`/`list` of every entry point; `run_16s.sh --init-only` writes per-project config; 16S steps 00+01 create a real manifest from fake FASTQ; `yaml2env` roundtrip on the example configs |
| `run_small_tests.sh` | numerical correctness of `bwa_counts_to_matrix.py`, `taxonomy_abundance.py`, `summarize_eggnog.py`, `kegg_completeness.py` (incl. legacy v1 headers and no-header probing), `contig_coverage.py`; `run_metagenome.sh --check-only` sample discovery + `generated.env`; `yaml2env` keys |
| `run_e2e_stub.sh` | end-to-end run of all 8 metagenome modules using the stub tools in `tests/stub_bin/` (they emulate kneaddata, MEGAHIT, Prodigal, MMseqs2, Salmon, DIAMOND, emapper.py, MetaBAT2/MaxBin2/CONCOCT, DAS_Tool, dRep, CheckM2, coverM, GTDB-Tk, KofamScan, ...). Verifies module wiring, resume markers, `generated.env`, conda activation, the Python helpers, key result files, and that resume does not rewrite markers |

## What is NOT covered here

- Real QIIME2, kneaddata, MEGAHIT, … executions (they need the Conda
  environments in `envs/` and real databases — see `docs/DATABASES.md`).
- Full-size data; the fixtures are tiny by design.
- `tests/stub_bin/` is a verbatim copy of the stub tools originally developed
  for the source SOP (`metagenome_sop/tests/stub_bin/`), kept for regression
  value; do not edit them casually.
