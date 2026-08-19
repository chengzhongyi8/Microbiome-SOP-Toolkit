# Parameter reference

Every parameter of both workflows is listed below with its CLI flag, YAML
config key, default value and an example.  Four ways to set parameters
(precedence low → high):

1. `config.sh` defaults (edit only if you really want new defaults);
2. `~/.microbiome-toolkit.conf` — optional machine-level defaults (database
   paths, CONDA_SH, environment names) applied to every project on that
   server; see `config/microbiome-toolkit.conf.example`;
3. YAML config file: `--config FILE.yaml` (see `config/*.example.yaml`);
4. CLI flags — always win.

Values can also be exported as environment variables with the same names as
the internal variables (e.g. `export CONDA_SH=/path/to/conda.sh`).

---

## Common

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--config FILE` | YAML config file with defaults (both workflows) | no | – | – | `--config config/16s_config.yaml` |
| `--force` | rerun all steps ignoring resume markers | no | off | – | `--force` |
| `--check-only` | (metagenome) validate inputs/params, write `generated.env`, exit | no | off | – | `--check-only` |
| `--init-only` | (16S) write per-project config and exit | no | off | – | `--init-only` |
| `-h`, `--help` | print help | no | – | – | `--help` |

---

## 16S workflow (`microbiome-toolkit 16s` / `run_16s.sh` / `qiime2-sop`)

### Paths & input

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--input DIR` | FASTQ directory (top level; `_R1/_R2` or `_1/_2`, `.fastq.gz`/`.fq.gz`) | **yes** | – | `input` | `--input /data/fastq` |
| `--output DIR` | project/output directory (absolute) | **yes** | – | `output` | `--output /data/qiime2_out` |
| `--metadata FILE` | sample metadata TSV (`#SampleID` first column); empty = auto-generate | no | auto | `metadata` | `--metadata metadata.tsv` |
| `--mode paired\|single` | sequencing mode | no | `paired` | `mode` | `--mode paired` |
| `--region NAME` | amplification region (see `workflows/16s/primers.tsv`) | rec. | – | `region` | `--region 16S_V4` |
| `--forward-primer SEQ` | forward primer (IUPAC ok); overrides region | no | from region | `forward_primer` | `--forward-primer AACMGGATTAGATACCCKG` |
| `--reverse-primer SEQ` | reverse primer; overrides region | no | from region | `reverse_primer` | `--reverse-primer ACGTCATCCCCACCTTCC` |

### Classifier

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--classifier PATH` | taxonomy classifier `.qza` | **yes** (unless `--classifier-dir`) | – | `classifier` | `--classifier /db/silva-138-99-515-806-nb-classifier.qza` |
| `--classifier-dir DIR` | auto-discover a classifier (region keywords or single `.qza`) | no | – | `classifier_dir` | `--classifier-dir /db/qiime2` |

### Primer trimming & DADA2

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--run-cutadapt yes\|no` | always run cutadapt | no | `no` | `run_cutadapt` | `--run-cutadapt yes` |
| `--auto-primer-trim yes\|no` | auto-detect primers and trim when found | no | `yes` | `auto_primer_trim` | `--auto-primer-trim no` |
| `--auto-trunc yes\|no` | auto-estimate DADA2 truncation | no | `yes` | `auto_trunc` | `--auto-trunc no` |
| `--quality-threshold N` | mean-Q cutoff for auto truncation | no | `20` | `quality_threshold` | `--quality-threshold 25` |
| `--min-trunc-len N` | never truncate below N bp | no | `50` | `min_trunc_len` | `--min-trunc-len 60` |
| `--max-ee N` | DADA2 max expected errors per read | no | `2.0` | `max_ee` | `--max-ee 5` |
| `--trim-left-f N` | manual trim-left forward | no | auto | `dada2.trim_left_f` | `--trim-left-f 19` |
| `--trim-left-r N` | manual trim-left reverse | no | auto | `dada2.trim_left_r` | `--trim-left-r 20` |
| `--trunc-len-f N` | manual trunc-len forward | no | auto | `dada2.trunc_len_f` | `--trunc-len-f 250` |
| `--trunc-len-r N` | manual trunc-len reverse | no | auto | `dada2.trunc_len_r` | `--trunc-len-r 220` |
| `--expected-amplicon-len N` | insert length without primers (overlap check) | no | from region | `expected_amplicon_len` | `--expected-amplicon-len 250` |
| `--min-samples N` | prevalence filter: ASV in ≥ N samples | no | none | `min_samples` | `--min-samples 2` |

### Taxonomy filtering & downstream

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--target-domain NAME` | keep only this domain | no | `Bacteria` | `filtering.target_domain` | `--target-domain Bacteria` |
| (no flag) | exclude mitochondria / chloroplast / Archaea / Eukaryota / Unassigned | no | mito yes, chloro yes, arch no, euk yes, unass no | `filtering.exclude_*` | – |
| (no flag) | optional core metrics / rarefaction / barplot + depths | no | off | `optional.*` | `optional.run_core_metrics: yes` |

### Conda & runtime

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--threads N` | cutadapt/DADA2/classifier/phylogeny threads | no | `8` | `threads` | `--threads 32` |
| `--conda-sh PATH` | `conda info --base` + `/etc/profile.d/conda.sh` | **yes on server** | placeholder | `conda.conda_sh` | `--conda-sh /opt/anaconda3/etc/profile.d/conda.sh` |
| `--qiime2-env NAME` | QIIME2 env (from `envs/16s.yml`) | no | `qiime2` | `conda.qiime2_env` | `--qiime2-env qiime2` |
| `--microeco-env NAME` | R microeco env (optional) | no | `microeco` | `conda.microeco_env` | `--microeco-env microeco` |
| `--resume yes\|no` | skip steps whose outputs exist | no | `yes` | `runtime.resume` | `--resume no` |
| (no flag) | gzip integrity check / read counting | no | no / yes | `runtime.check_gzip_integrity`, `runtime.count_reads` | – |

qiime2-sop extra flags: `--submit`, `--pbs-nodes N`, `--pbs-mem MEM`,
`--walltime HH:MM:SS`, `--dry-run`, `--init-config`.

---

## Metagenome workflow (`microbiome-toolkit metagenome` / `run_metagenome.sh` / `mg-sop`)

### Paths & input

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--project-dir DIR` | output root (results/ work/ logs/) | **yes** | – | `project_dir` | `--project-dir /data/proj/mg1` |
| `--input DIR` | reads directory (`*_1.fq.gz` / `*_2.fq.gz`, many suffixes) | **yes** | – | `input` | `--input /data/proj/mg1/seq` |
| `--group-file FILE` | `sample_id<TAB>group`; co-assembly per group | no | – | `group_file` | `--group-file groups.tsv` |

### QC / host removal

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--qc-needed yes\|no` | `yes` kneaddata QC+dehost; `no` only dehost | no | `yes` | `qc_needed` | `--qc-needed no` |
| `--host-genome PREFIX` | bowtie2 index prefix (or `--host-fasta`) | no | none (no dehost) | `host_genome` | `--host-genome /db/host_db/wheat/wheat` |
| `--host-fasta FILE` | host FASTA; auto-build index | no | – | `host_fasta` | `--host-fasta wheat.fna` |
| `--host-name NAME` | species dir name for auto index | no | FASTA basename | `host_name` | `--host-name wheat` |
| `--host-db-dir DIR` | where auto-built host indexes go | no | `/path/to/databases/host_db` | `host_db_dir` | `--host-db-dir /db/host_db` |
| `--adapters FILE` | trimmomatic adapters (ILLUMINACLIP) | no | none | `adapters` | `--adapters TruSeq3-PE-2.fa` |
| (no flag) | trimmomatic options / bowtie2 options | no | `SLIDINGWINDOW:4:20 MINLEN:50` / `--very-sensitive` | `trimmomatic_opts`, `bowtie2_opts` | – |

### Assembly & gene catalog

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--assembly MODE` | `per-sample` \| `co-assembly` \| `both` | no | `per-sample` | `assembly` | `--assembly co-assembly` |
| `--min-contig-len N` | gene-prediction contigs ≥ N bp | no | `1000` | `min_contig_len` | `--min-contig-len 500` |
| `--bin-min-contig-len N` | binning contigs ≥ N bp | no | `1500` | `bin_min_contig_len` | `--bin-min-contig-len 1500` |
| `--cluster TOOL` | `mmseqs2` \| `cd-hit-est` | no | `mmseqs2` | `cluster` | `--cluster cd-hit-est` |
| (no flag) | cluster identity / coverage | no | `0.95` / `0.90` | `gene.identity`, `gene.coverage` | – |

### Quantification

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--quant TOOL` | `salmon` \| `bwa` | no | `salmon` | `quant` | `--quant bwa` |
| `--contig-coverage yes\|no` | extra per-contig depth table | no | `no` | `contig_coverage` | `--contig-coverage yes` |

### Taxonomy

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--taxonomy TOOL` | `nr-megan` \| `kraken2` \| `none` | no | `nr-megan` | `taxonomy` | `--taxonomy none` |
| `--nr-db PATH` | DIAMOND NR database | for nr-megan | – | `nr_db` | `--nr-db /db/nr.dmnd` |
| `--megan-map PATH` | MEGAN accession→taxid map | for nr-megan | – | `megan_map` | `--megan-map /db/prot_acc2tax.abin` |
| `--max-target-seqs N` | DIAMOND hits per gene | no | `10` | `max_target_seqs` | `--max-target-seqs 20` |
| `--taxa-filter all\|bacteria` | keep all domains or bacteria only | no | `all` | `taxa_filter` | `--taxa-filter bacteria` |
| `--kraken2-db DIR` | Kraken2 database | for kraken2 | – | `kraken2_db` | `--kraken2-db /db/kraken2` |

### Function

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--function TOOL` | `eggnog` \| `none` | no | `eggnog` | `function` | `--function none` |
| `--eggnog-db DIR` | eggNOG database directory | for eggnog | – | `eggnog_db` | `--eggnog-db /db/eggnog` |
| `--eggnog-shm yes\|no` | copy DB to `/dev/shm` | no | `no` | `eggnog_shm` | `--eggnog-shm yes` |
| `--kegg-module-def FILE` | KEGG `module.ko` | no | none (detection only) | `kegg.module_def` | `--kegg-module-def /db/kegg/module.ko` |
| `--kegg-pathway-def FILE` | KEGG `ko00001.keg` | no | none | `kegg.pathway_def` | `--kegg-pathway-def /db/kegg/ko00001.keg` |
| `--kegg-module-name FILE` | KEGG module names | no | none | `kegg.module_name` | `--kegg-module-name /db/kegg/module` |
| `--kegg-complete-threshold N` | completeness cutoff (0–1) | no | `0.9` | `kegg.complete_threshold` | `--kegg-complete-threshold 1.0` |

### Binning / MAGs

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--binning TOOL` | `metawrap` \| `none` | no | `none` | `binning` | `--binning metawrap` |
| `--binners LIST` | comma list of binners | no | `metabat2,maxbin2,concoct` | `binners` | `--binners metabat2,concoct` |
| `--binning-refine yes\|no` | DAS_Tool/MetaWRAP refinement | no | `yes` | `binning_refine` | `--binning-refine no` |
| `--binning-reassemble yes\|no` | MetaWRAP reassembly (slow) | no | `no` | `binning_reassemble` | `--binning-reassemble yes` |
| `--run-drep yes\|no` | dRep dereplication | no | `yes` | `run_drep` | `--run-drep no` |
| `--drep-ignore-quality yes\|no` | skip checkm filter inside dRep | no | `no` | `drep_ignore_quality` | `--drep-ignore-quality yes` |
| `--mag-filter yes\|no` | keep MAGs passing thresholds | no | `no` | `mag_filter` | `--mag-filter yes` |
| `--mag-min-completeness N` | completeness threshold | no | `50` | `mag_min_completeness` | `--mag-min-completeness 70` |
| `--mag-max-contamination N` | contamination threshold | no | `10` | `mag_max_contamination` | `--mag-max-contamination 5` |
| `--checkm2-db DIR` | CheckM2 database (dir or `.dmnd`) | for binning | – | `checkm2_db` | `--checkm2-db /db/checkm2` |
| `--metawrap-reads-mode MODE` | `plain` \| `gz` | no | `plain` | `metawrap_reads_mode` | `--metawrap-reads-mode gz` |

### MAG downstream (module 08)

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--mag-quant yes\|no` | coverM MAG abundance | no | `no` | `mag_quant` | `--mag-quant yes` |
| `--mag-annotate yes\|no` | GTDB-Tk + Prodigal + KofamScan | no | `no` | `mag_annotate` | `--mag-annotate yes` |
| `--mag-quant-methods LIST` | extra coverM methods | no | none | `mag_quant_methods` | `--mag-quant-methods "rpkm tpm"` |
| `--gtdbtk-db DIR` | GTDB reference DB | for annotate | – | `gtdbtk_db` | `--gtdbtk-db /db/gtdbtk_r220` |
| `--gtdbtk-pplacer-cpus N` | pplacer threads (≤ 4) | no | `1` | `gtdbtk_pplacer_cpus` | `--gtdbtk-pplacer-cpus 2` |
| `--kofam-profile DIR` | KofamScan profiles | for annotate | – | `kofam_profile` | `--kofam-profile /db/kofam/profiles` |
| `--kofam-ko-list FILE` | KofamScan ko_list | for annotate | – | `kofam_ko_list` | `--kofam-ko-list /db/kofam/ko_list` |

### Conda & resources

| Parameter | Description | Required | Default | YAML key | Example |
|---|---|---|---|---|---|
| `--conda-sh PATH` | `conda info --base` + `/etc/profile.d/conda.sh` | **yes on server** | placeholder | `conda.conda_sh` | `--conda-sh /opt/anaconda3/etc/profile.d/conda.sh` |
| `--qc-env` … `--drep-env NAME` | per-module conda env names | no | see `config.sh` / envs | `conda.qc_env` … | `--eggnog-env my_eggnog` |
| `--threads N` | CPUs per task | no | `16` | `resources.threads` | `--threads 28` |
| `--jobs N` | parallel tasks (`threads*jobs` ≤ node cores) | no | `4` | `resources.jobs` | `--jobs 8` |
| `--memory-gb N` | memory hint (binning) | no | `64` | `resources.memory_gb` | `--memory-gb 128` |
| `--resume yes\|no` | skip completed modules (marker files) | no | `yes` | `runtime.resume` | `--resume no` |

mg-sop extra flags: `--submit`, `--pbs-nodes N`, `--pbs-mem MEM`,
`--walltime HH:MM:SS`, `--dry-run`, `--init-config`.
