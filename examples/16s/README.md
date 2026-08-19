# 16S workflow — example inputs

## FASTQ layout

The `--input` directory must contain the raw reads at its **top level**
(no sub-directories are scanned):

```
/path/to/fastq/
├── Sample1_R1.fastq.gz
├── Sample1_R2.fastq.gz
├── Sample2_R1.fastq.gz
├── Sample2_R2.fastq.gz
└── ...
```

Accepted paired-end suffixes: `_R1/_R2`, `.R1/.R2`, `_1/_2` with `.fastq.gz`
or `.fq.gz`.  Single-end files (`.fastq.gz` / `.fq.gz` only) are accepted
with `--mode single`.

## Metadata

`metadata_template.tsv` — optional sample metadata.  The first column header
must be `#SampleID` (or `sample-id` / `sample_name`) and the sample IDs must
match the FASTQ file names exactly (minus the suffix).  If you do not pass
`--metadata`, a minimal metadata table is generated automatically — replace
it with real grouping columns before any group-comparison analysis.

## Run

```bash
microbiome-toolkit 16s \
    --input /path/to/fastq \
    --region 16S_V4 \
    --classifier /db/silva-138-99-515-806-nb-classifier.qza \
    --metadata examples/16s/metadata_template.tsv \
    --output /path/to/project \
    --threads 16
```

See `docs/16S_SOP.md` and `docs/PARAMETERS.md` for all options.
