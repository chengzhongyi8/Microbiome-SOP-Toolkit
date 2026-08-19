# Metagenome workflow — example inputs

## FASTQ layout

The `--input` directory must contain paired-end reads at its **top level**:

```
/path/to/fastq/
├── Sample1_1.fq.gz
├── Sample1_2.fq.gz
├── Sample2_1.fq.gz
├── Sample2_2.fq.gz
└── ...
```

Accepted paired-end suffixes: `_1/_2`, `_R1/_R2`, `.1/.2`, `.R1/.R2` with
`.fq.gz`, `.fastq.gz`, `.fq` or `.fastq`.  (The metagenome workflow is
paired-end only.)

## samples.tsv (informational)

`run_metagenome.sh` auto-discovers samples from the reads directory and writes
`<project>/work/samples.tsv`; you normally do **not** need to supply one.

## group file (optional, for per-group co-assembly)

`groups.tsv.example` is the `--group-file` format (`sample_id<TAB>group`).
When `--assembly co-assembly` is combined with a group file, one co-assembly
per group is produced.

## Host genome

Place host genomes **outside** this repository, e.g.
`/path/to/databases/host_db/<species>/`.  First use with a FASTA:
`--host-fasta <file> --host-name <species>` (the pipeline runs
`bowtie2-build` once; >4 Gb genomes get `--large-index` automatically).
Later runs just pass `--host-genome <index prefix>`.  See
`docs/DATABASES.md`.

## Run

```bash
microbiome-toolkit metagenome \
    --input /path/to/fastq \
    --project-dir /path/to/project \
    --qc-needed yes \
    --host-genome /path/to/databases/host_db/wheat/wheat \
    --assembly co-assembly \
    --threads 28 --jobs 8
```

Or use the YAML config file (recommended for the many optional flags):

```bash
microbiome-toolkit metagenome --config config/metagenome_config.yaml
```

See `docs/Metagenome_SOP.md` and `docs/PARAMETERS.md` for all options.
