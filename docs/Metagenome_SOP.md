# Shotgun Metagenome Workflow

This document describes the **metagenome workflow** (modules 01–08) step by
step: purpose, software, inputs, outputs and the main parameters of each
module.

**Quick entry points**

| Command | What it does |
|---|---|
| `microbiome-toolkit metagenome --help` | one-command pipeline (module 01–08) |
| `bash bin/run_metagenome.sh --help` | plain driver |
| `microbiome-toolkit metagenome --input DIR ... --submit` | PBS submission (`mg-sop` is a compatibility alias) |
| `bash bin/run_metagenome.sh --check-only` | validate inputs/params without running modules |

---

## Pipeline overview

```
Raw/clean paired reads
   │ 01 QC + host removal (kneaddata/Trimmomatic + bowtie2)
   ▼
clean reads ────────────────────────────► results/qc/ (counts, FastQC, MultiQC)
   │
   ▼ 02 assembly (MEGAHIT; per-sample / co-assembly / both)
contigs ────► results/assembly/assembly.fa + stats
   │
   ▼ 03 gene catalog (Prodigal + MMseqs2/CD-HIT)
gene_catalog.fna/.faa ────► results/gene_catalog/
   │
   ▼ 04 quantification (Salmon or BWA; optional contig depth)
gene.count.tsv / gene.TPM.tsv (or FPKM) ────► results/quant/
   │
   ├──► 05 taxonomy (DIAMOND vs NR + MEGAN blast2lca; kraken2 reserved)
   │        Table_taxa_{Domain..Species}.tsv ────► results/taxonomy/
   │
   ├──► 06 function (eggNOG-mapper + KEGG completeness)
   │        KO/CAZy/COG + completeness tables ────► results/function/
   │
   └──► 07 binning (MetaBAT2/MaxBin2/CONCOCT → DAS_Tool → dRep → CheckM2)
            MAGs + quality ────► results/mags/
                 │
                 ▼ 08 MAG downstream (optional: coverM / GTDB-Tk / Prodigal / KofamScan)
                 results/mags/abundance/ + annotations/
```

---

## Module 01 — QC and host removal

- **Purpose**: standardize read QC and remove host (e.g. plant/animal) reads.
- **Software**: kneaddata (Trimmomatic + Bowtie2), FastQC, MultiQC;
  `kneaddata_read_count_table`; or plain `bowtie2 --un-conc-gz` when
  `QC_NEEDED=no`.
- **Input**: `work/samples.tsv` (auto-discovered), raw reads, host index.
- **Main parameters**: `QC_NEEDED`, `HOST_GENOME`/`HOST_FASTA`/`HOST_NAME`,
  `HOST_DB_DIR`, `ADAPTERS`, `TRIMMOMATIC_OPTS`, `BOWTIE2_OPTS`, `THREADS`,
  `CONCURRENT_JOBS`.
- **Output**: `work/qc/clean/<sample>_{1,2}.fq.gz` (standardized names),
  `results/qc/read_counts.tsv`, `kneaddata_summary.txt`,
  `host_removal_summary.txt`, `fastqc/`, `multiqc_report.html`.
- **Notes**: paired-end name consistency is verified on a sample of reads
  (`--reorder` for kneaddata, automatic check in the workers).

## Module 02 — Assembly

- **Purpose**: assemble clean reads with MEGAHIT.
- **Software**: MEGAHIT, seqkit.
- **Input**: `work/qc/clean/`, `work/samples.tsv`.
- **Main parameters**: `ASSEMBLY_MODE` (`per-sample`|`co-assembly`|`both`),
  `GROUP_FILE` (per-group co-assembly), `MEGAHIT_K_MIN/K_MAX/K_STEP`,
  `MEGAHIT_MIN_CONTIG_LEN`, `GENE_MIN_CONTIG_LEN`, `BIN_MIN_CONTIG_LEN`,
  `THREADS`, `CONCURRENT_JOBS`.
- **Output**: `work/assembly/{per_sample,coassembly}/.../final.contigs.fa`,
  `results/assembly/<asm>.contigs.fa` (filtered + renamed with
  `<asm_id>|` prefix), `assembly.fa` (merged), `assembly.stats.tsv`,
  `assemblies.list`, `work/binning/<asm>.fa` (for module 07).
- **Notes**: contig IDs are prefixed with the assembly id so IDs stay unique
  across assemblies; MEGAHIT intermediate files are cleaned to save disk.

## Module 03 — Gene catalog

- **Purpose**: predict genes (Prodigal, metagenomic mode) and build a
  non-redundant gene catalog.
- **Software**: Prodigal, seqkit (`split2`, `translate`), MMseqs2
  (`easy-linclust`, default) or CD-HIT-EST.
- **Input**: `results/assembly/assembly.fa`.
- **Main parameters**: `GENE_SPLIT_SEQS`, `GENE_CLUSTERER`,
  `GENE_MIN_IDENTITY` (0.95), `GENE_MIN_COVERAGE` (0.90), `THREADS`.
- **Output**: `results/gene_catalog/prediction/{genes.fna,proteins.faa,genes.gff}`,
  `catalog/gene_catalog.fna` (non-redundant), `catalog/gene_catalog.faa`
  (translated), `catalog.stats.tsv`.
- **Notes**: splitting is always record-aware (`seqkit split2`); never
  `split -l` on FASTA.  IDs are renamed `UnigeneN` consistently between
  nucleotide and protein files.

## Module 04 — Gene quantification

- **Purpose**: quantify the gene catalog in every sample.
- **Software**: Salmon (`index` + `quant --meta` + `quantmerge`, default) or
  BWA (`mem` → `samtools view -F 0x904` → `sort/index/idxstats`), optional
  bowtie2 + `samtools depth` for contig coverage.
- **Input**: `catalog/gene_catalog.fna`, `work/qc/clean/`.
- **Main parameters**: `QUANT_TOOL`, `SALMON_K`, `THREADS`,
  `CONTIG_COVERAGE` (default `no`).
- **Output**: `results/quant/gene.count.tsv` + `gene.TPM.tsv` (Salmon) or
  `gene.FPKM.tsv` (BWA); `contig.depth.tsv` when enabled.
- **Notes**: BWA path filters secondary/supplementary/unmapped alignments so
  multi-mappers are not double counted.

## Module 05 — Taxonomy

- **Purpose**: taxonomic annotation of genes and per-rank abundance tables.
- **Software**: DIAMOND (`blastp` vs NR), MEGAN `blast2lca` (standalone Java
  tool), Python `taxonomy_abundance.py` (stdlib).  Kraken2 is a reserved
  alternative.
- **Input**: `catalog/gene_catalog.faa`, abundance matrix, `NR_DMND`,
  `MEGAN_MAP`.
- **Main parameters**: `TAXONOMY_TOOL` (`nr-megan`|`kraken2`|`none`),
  `NR_DMND`, `MEGAN_MAP`, `DIAMOND_MAX_TARGET_SEQS`, `DIAMOND_EVALUE`,
  `MEGAN_MIN_SUPPORT`, `MEGAN_MIN_EVALUE`, `TAXA_FILTER`
  (`all`|`bacteria`), `KRAKEN2_DB` (kraken2 only).
- **Output**: `results/taxonomy/gene_taxonomy.tsv`,
  `Table_taxa_{Domain,Phylum,Class,Order,Family,Genus,Species}.tsv`.
- **Notes**: with `--taxonomy none` the module is skipped.  Kraken2 requires
  a configured database and will fail clearly if it is missing.

## Module 06 — Function

- **Purpose**: functional annotation of the gene catalog with eggNOG-mapper
  and optional KEGG Module/Pathway completeness.
- **Software**: eggNOG-mapper (`emapper.py` two-phase: `--no_annot` parallel
  DIAMOND search, then `--annotate_hits_table`), seqkit, Python
  `summarize_eggnog.py` + `kegg_completeness.py` (stdlib).
- **Input**: `catalog/gene_catalog.faa`, abundance matrix, `EGGNOG_DATA_DIR`,
  optional KEGG definition files.
- **Main parameters**: `FUNCTION_TOOL`, `EGGNOG_DATA_DIR`, `EGGNOG_SHM`,
  `EGGNOG_PROT_MIN_LEN`, `KEGG_MODULE_DEF`, `KEGG_PATHWAY_DEF`,
  `KEGG_MODULE_NAME`, `KEGG_COMPLETE_THRESHOLD`.
- **Output**: `results/function/eggnog.annotations.tsv`,
  `gene_annotation.tsv`, `KO.tsv`, `CAZy.tsv`, `COG.tsv`,
  `KEGG_module_completeness.tsv` / `KEGG_pathway_completeness.tsv` (or
  `*_detected.tsv` when definition files are not configured).
- **Notes**: with `--function none` the module is skipped.  When
  `EGGNOG_SHM=yes` the database is copied to `/dev/shm` (check space first).

## Module 07 — MAG binning

- **Purpose**: recover metagenome-assembled genomes.
- **Software**: bowtie2 (map reads to contigs), `jgi_summarize_bam_contig_depths`
  (depth matrix), MetaBAT2 / MaxBin2 / CONCOCT (binners, configurable),
  DAS_Tool (optional integration), dRep (dereplication), CheckM2 (quality).
- **Input**: `work/binning/<asm>.fa` (≥ `BIN_MIN_CONTIG_LEN`),
  `work/qc/clean/`.
- **Main parameters**: `BINNING_TOOL` (`metawrap`|`none`), `MAG_BINNERS`,
  `RUN_BINNING_REFINE`, `RUN_BINNING_REASSEMBLE`, `RUN_DREP`,
  `DREP_PRIMARY_ANI`, `DREP_SECONDARY_ANI`, `MAG_FILTER`,
  `MAG_MIN_COMPLETENESS`, `MAG_MAX_CONTAMINATION`, `CHECKM2_DB`,
  `DREP_IGNORE_QUALITY`, `METAWRAP_READS_MODE`.
- **Output**: `results/mags/refined_bins/`, `drep/dereplicated_genomes/`,
  `checkm2/quality_report.tsv`, `MAG_list.txt`, `MAG_quality.tsv`,
  `MAG_quality.filtered.tsv` (when `MAG_FILTER=yes`), `filtered_genomes/`.
- **Notes**: reads stay gzipped (zero decompression); BAMs are deleted after
  depth extraction to save space.  Large assemblies (>4 Gb) get
  `--large-index` automatically.  dRep can skip its checkm quality filter
  (`--drep-ignore-quality yes`) because CheckM2 evaluates quality anyway.

## Module 08 — MAG downstream annotation (optional)

- **Purpose**: abundance and annotation of dereplicated MAGs.
- **Software**: coverM (`genome`), GTDB-Tk (`classify_wf`), Prodigal
  (`-p single` per MAG), KofamScan (`exec_annotation`), Python
  `merge_coverm.py` + `merge_kofam.py` (stdlib).
- **Input**: `results/mags/drep/dereplicated_genomes/` (or
  `filtered_genomes/`), clean reads.
- **Main parameters**: `MAG_QUANT`, `MAG_ANNOTATE`, `MAG_QUANT_METHODS`,
  `GTDBTK_DATA_PATH`, `GTDBTK_PPLACER_CPUS`, `KOFAM_PROFILE`, `KOFAM_KO_LIST`.
- **Output**: `results/mags/abundance/MAG_abundance.tsv` (coverM),
  `annotations/gtdb/` (GTDB-Tk summaries), `annotations/prodigal/`
  (proteins/genes/gff), `annotations/kofam/` (per-MAG KO detail/final +
  merged long table and KO×bin matrices), `annotations/kofam_summary.tsv`.
- **Notes**: the module only runs when `--mag-quant yes` and/or
  `--mag-annotate yes`.

---

## Software used (summary)

QC: kneaddata, Trimmomatic, bowtie2, FastQC, MultiQC · Assembly: MEGAHIT,
seqkit · Genes: Prodigal, MMseqs2, CD-HIT-EST · Quant: Salmon, BWA, SAMtools,
bowtie2 · Taxonomy: DIAMOND, MEGAN `blast2lca` (standalone), Kraken2
(reserved) · Function: eggNOG-mapper · MAGs: MetaBAT2, MaxBin2, CONCOCT,
DAS_Tool, dRep, fastANI, checkm, CheckM2, GTDB-Tk, coverM, KofamScan, HMMER ·
Python (stdlib): the bundled `workflows/metagenome/bin/*.py` helpers.

See `envs/README.md` for the per-module Conda environments and
`docs/DATABASES.md` for the required reference databases.
