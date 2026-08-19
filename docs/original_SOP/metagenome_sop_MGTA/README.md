# 宏基因组分析 SOP（Metagenome Analysis SOP）

一套**命令行参数驱动 + PBS 提交**的宏基因组分析流程，整理自你的
《MetaGenomic Analysis Tutorial (MGTA)》实战笔记，并做了修正与模块化封装。
风格与之前的 QIIME2 SOP 一致（`run_*.pbs` → `run_mg_sop.sh` → 模块脚本）。

```
metagenome_sop/
├── run_mg_sop.sh           主控脚本（全部参数走命令行）
├── run_metagenome.pbs      PBS 提交模板（qsub 用）
├── config.sh               默认参数（可被命令行覆盖）
├── modules/
│   ├── 01_qc_dehost.sh     质控 + 去宿主（kneaddata / bowtie2）
│   ├── 02_assembly.sh      组装（MEGAHIT，单样本/共组装/两者）
│   ├── 03_gene_catalog.sh  基因预测（Prodigal）+ 非冗余基因集（MMseqs2/CD-HIT）
│   ├── 04_quant.sh         基因定量（Salmon 默认 / BWA 可选）+ 可选 contig 覆盖表
│   ├── 05_taxonomy.sh      物种注释（DIAMOND+NR+MEGAN 默认；Kraken2 预留）
│   ├── 06_function.sh      功能注释（eggNOG-mapper + KEGG 完整度）
│   └── 07_binning.sh       MAG binning（MetaWRAP + dRep + CheckM2）
├── bin/                    Python 辅助脚本 + conda 环境激活
├── db/host/                旧版宿主基因组目录（已迁移，不再使用；见 db/host/README.md）
└── tests/                  轻量测试
```

## 1. 快速开始（推荐用 mg-sop 一键命令，和 qiime2-sop 一样）

```bash
# 1) 可选：生成个人配置文件 ~/.mg-sop.conf（线程、PBS 节点、时长等默认值）
bin/mg-sop --init-config

# 2) 一键前台运行（不加 --submit 就是直接跑）
bin/mg-sop \
  --fastq-dir  /home/user/proj/mg1/seq \
  --qc-needed  yes \
  --host-fasta /home/user/database/host_db/wheat/GCA_903993985.1_10wheat_assembly_arinaLrFor_genomic.fna --host-name wheat \
  --assembly   co-assembly \
  --binning    metawrap

# 3) 一键生成 PBS 并 qsub 提交（推荐在集群上用这个）
bin/mg-sop \
  --fastq-dir  /home/user/proj/mg1/seq \
  --host-genome /home/user/database/host_db/wheat/wheat \
  --assembly   co-assembly \
  --taxonomy   nr-megan --function eggnog --binning metawrap \
  --submit

# 4) 只预览要执行的命令 / 要生成的 PBS，不运行
bin/mg-sop --fastq-dir ... --host-genome ... --dry-run
bin/mg-sop --fastq-dir ... --host-genome ... --submit --dry-run
```

> - `mg-sop` 只是 `run_mg_sop.sh` 的入口封装：所有 `run_mg_sop.sh` 的参数原样可用，
>   额外多了 `--submit` / `--pbs-nodes` / `--pbs-mem` / `--walltime` / `--dry-run` / `--init-config`；
> - 想让 `mg-sop` 全局可用，在服务器上建个软链即可（脚本会自动找到流水线目录）：
>   ```bash
>   ln -s /home/user/toolkit/metagenome_sop/bin/mg-sop /home/user/bin/mg-sop
>   ```
> - 不填 `--project-dir` 时，默认输出到数据目录旁边的 `<目录名>_mg_out`。

## 2. 传统用法（直接跑主控脚本）

```bash
# 1) 把文件夹上传到集群（在本地 Mac 执行）
rsync -av --exclude '.DS_Store' ./metagenome_sop/ \
  user@server:/home/user/toolkit/metagenome_sop/

# 2) 登录集群，先 dry-run 校验（只检查参数/输入，不跑流程）
cd /home/user/toolkit/metagenome_sop
bash run_mg_sop.sh \
  --project-dir /home/user/proj/mg1 \
  --fastq-dir  /home/user/proj/mg1/seq \
  --qc-needed  yes \
  --host-genome /home/user/database/host_db/wheat/wheat \
  --check-only

# 3) 修改 run_metagenome.pbs 里的项目路径后提交
qsub run_metagenome.pbs
# 或直接 nohup 跑：
# nohup bash run_mg_sop.sh --project-dir ... --fastq-dir ... > run.log 2>&1 &
```

> 第一次用某个宿主时也可只给 `--host-fasta`，脚本会自动 `bowtie2-build` 建索引。


```bash
# 1) 把文件夹上传到集群（在本地 Mac 执行）
rsync -av --exclude '.DS_Store' ./metagenome_sop/ \
  user@server:/home/user/toolkit/metagenome_sop/

# 2) 登录集群，先 dry-run 校验（只检查参数/输入，不跑流程）
cd /home/user/toolkit/metagenome_sop
bash run_mg_sop.sh \
  --project-dir /home/user/proj/mg1 \
  --fastq-dir  /home/user/proj/mg1/seq \
  --qc-needed  yes \
  --host-genome /home/user/database/host_db/wheat/wheat \
  --check-only

# 3) 修改 run_metagenome.pbs 里的项目路径后提交
qsub run_metagenome.pbs
# 或直接 nohup 跑：
# nohup bash run_mg_sop.sh --project-dir ... --fastq-dir ... > run.log 2>&1 &
```

> 第一次用某个宿主时也可只给 `--host-fasta`，脚本会自动 `bowtie2-build` 建索引。

## 3. 关键参数速查（完整列表见 `bash run_mg_sop.sh --help`）

| 参数 | 说明 | 默认 |
|---|---|---|
| `--project-dir DIR` | 输出根目录（results/ work/ logs/） | 必填 |
| `--fastq-dir DIR` | 测序数据目录，自动识别 `*_1.fq.gz`/`*_2.fq.gz` | 必填 |
| `--qc-needed yes\|no` | 公司没质控=yes（kneaddata 质控+去宿主）；已质控=no（只去宿主） | yes |
| `--host-genome PREFIX` | 宿主 bowtie2 索引前缀（与 `--host-fasta` 二选一） | 空=不去宿主 |
| `--host-fasta FILE` | 宿主基因组 FASTA，自动建索引到 `HOST_DB_DIR/<物种>/`（默认 `/home/user/database/host_db`） | |
| `--adapters FILE` | trimmomatic 接头文件（ILLUMINACLIP） | 空=用默认 |
| `--group-file FILE` | 可选分组文件 `sample_id<TAB>group`，共组装按组 | |
| `--assembly MODE` | `per-sample` / `co-assembly` / `both` | per-sample |
| `--min-contig-len N` | 基因预测用 contigs ≥ N bp | 1000 |
| `--bin-min-contig-len N` | binning 用 contigs ≥ N bp | 1500 |
| `--cluster TOOL` | `mmseqs2`（大基因集推荐） / `cd-hit-est` | mmseqs2 |
| `--quant TOOL` | `salmon`（推荐）/ `bwa` | salmon |
| `--taxonomy TOOL` | `nr-megan` / `kraken2`（需先配置）/ `none` | nr-megan |
| `--function TOOL` | `eggnog` / `none` | eggnog |
| `--binning TOOL` | `metawrap` / `none` | none |
| `--binners LIST` | `metabat2,maxbin2,concoct`（可裁剪） | 三款 |
| `--binning-reassemble yes\|no` | 是否 reassemble（较慢） | no |
| `--run-drep yes\|no` | 是否 dRep 去冗余 | yes |
| `--checkm2-db DIR` | CheckM2 数据库 | /home/user/database/checkm2_db |
| `--nr-db PATH` | NR diamond 数据库 | config.sh 预填 |
| `--megan-map PATH` | MEGAN accession→taxid 映射 | config.sh 预填 |
| `--eggnog-db DIR` | eggNOG 数据库目录 | config.sh 预填 |
| `--contig-coverage yes\|no` | 额外输出 contig 覆盖深度表（reads 回比组装） | no |
| `--kegg-module-def FILE` | KEGG module.ko（完整度矩阵；空=只出检测表） | 空 |
| `--kegg-pathway-def FILE` | KEGG ko00001.keg（完整度矩阵；空=只出检测表） | 空 |
| `--kegg-module-name FILE` | KEGG module 名称文件（可选） | 空 |
| `--conda-sh PATH` | conda.sh（`conda info --base` 得到） | config.sh 预填 |
| `--threads N` / `--jobs N` | 单任务 CPU / 并行任务数 | 28 / 8 |
| `--resume yes\|no` / `--force` | 断点续跑 / 强制重跑 | yes |
| `--check-only` | 只校验不跑流程 | |

## 4. 输出目录

```
<project>/
├── work/
│   ├── samples.tsv           样品清单（自动生成）
│   ├── generated.env         本次运行参数快照（模块自动加载）
│   ├── qc/clean/<s>_{1,2}.fq.gz   标准化干净数据
│   ├── assembly/             组装中间文件
│   ├── gene_catalog/         基因预测/去冗余中间文件
│   ├── quant/                定量中间文件（含 contig_cov/，若开启）
│   ├── taxonomy/  function/  binning/   各模块中间文件
│   └── markers/*.ok          resume 标记
├── results/
│   ├── qc/                   质控统计、FastQC、MultiQC
│   ├── assembly/             assembly.fa、统计表
│   ├── gene_catalog/         gene_catalog.fna/.faa、统计
│   ├── quant/                gene.count.tsv / gene.TPM.tsv（或 FPKM）
│   │                        + contig.depth.tsv（--contig-coverage yes 时）
│   ├── taxonomy/             Table_taxa_*.tsv
│   ├── function/             KO.tsv / CAZy.tsv / COG.tsv
│   │                        + KEGG_module_completeness.tsv / KEGG_pathway_completeness.tsv
│   ├── mags/                 MAG_list.txt / MAG_quality.tsv
│   ├── software_versions.tsv 软件版本记录
│   └── summary/README_summary.md   汇总报告
└── logs/pipeline.log         流程日志
```

## 5. 你需要配置的东西（上服务器后）

1. `config.sh` → `CONDA_SH`（如 `/home/user/anaconda3/etc/profile.d/conda.sh`）已预填，核对即可；
2. `config.sh` → 各 `ENV_*` 环境名按你服务器 `conda env list` 核对（kneaddata、megahit、prodigal、mmseqs2、salmon、diamond、megan、eggnog2.0.1、metawrap、checkm2、dRep 所在环境）；
3. `config.sh` → `NR_DMND`、`MEGAN_MAP`、`EGGNOG_DATA_DIR`、`CHECKM2_DB`（已按你 PDF/描述预填，确认实际路径）；
4. （可选）KEGG 完整度定义文件：下载后填 `KEGG_MODULE_DEF` / `KEGG_PATHWAY_DEF` / `KEGG_MODULE_NAME`：
   ```bash
   mkdir -p /home/user/database/kegg && cd /home/user/database/kegg
   wget ftp://ftp.genome.jp/pub/kegg/module/module.ko
   wget ftp://ftp.genome.jp/pub/kegg/module/module          # 模块名称（可选）
   wget ftp://ftp.genome.jp/pub/kegg/brite/ko/ko00001.keg   # 通路定义
   ```
   不配也能跑：模块 06 会退化为“检测表”（只用 emapper 的 `KEGG_Module` / `KEGG_Pathway` 列）。
5. 宿主基因组放到 `/home/user/database/host_db/<物种>/`（流水线目录之外，拖拽上传/解压不会覆盖；可用 `--host-db-dir` 改）；
   - 第一次用某物种：放 FASTA，跑 `--host-fasta ... --host-name <物种>` 自动建索引；
   - 之后：直接 `--host-genome /home/user/database/host_db/<物种>/<物种>`；
   - 注意：上传 `metagenome_sop/` 时**不要**把宿主基因组放进流水线目录里，避免整目录覆盖把数据库冲掉。
6. 每个项目的路径在 `run_metagenome.pbs` 里改，不要改全局 config。

## 6. 常见问题 / 踩坑提醒（已在你旧笔记基础上修正）

- **双端序列名字错位**：kneaddata 加 `--reorder`；模块 01 还会自动抽查前 1 万条 reads 名字是否一致。
- **eggNOG 拆块**：只用 `seqkit split2` 按完整记录拆，禁止 `split -l` 按行切；模块 06 已自动处理。
- **BWA 定量**：先 `samtools view -F 0x904` 过滤 secondary/supplementary/unmapped 再 idxstats，避免多比对重复计数。
- **丰度合并**：全部由 Python 脚本自动合并，不再手工 `paste/cut` 硬编码列号。
- **物种注释**：默认保留所有 domain（`--taxa-filter all`）；只要细菌用 `--taxa-filter bacteria`（旧笔记行为）。
- **ARG/Resfams**：按你的要求已删除该模块。
- **Kraken2**：模块 05 预留，但你的服务器未安装/未配置数据库，用到时会明确报错，装上后配 `--kraken2-db` 即可。
- **python3 找不到**：某些 conda 环境（如 eggnog2.0.1）里没有 `python3`，模块内的 Python 汇总脚本已统一走 `run_py3`，会自动退回 conda base 的 python3，不再报 `python3: 未找到命令`。

## 7. 测试

```bash
bash tests/run_small_tests.sh   # 纯本地：Python 辅助脚本 + 主控 --check-only
```
