# 模块化宏基因组分析流程

本目录整理自 “大豆根际样品分析（2023.7.20-）” 的真实记录。它不是一条强制串联 pipeline：每个研究问题单独运行，输入对象、数据库版本和人工决策应写入项目日志。

## 目录与建议顺序

| 目录 | 作用 | 是否主流程 |
|---|---|---|
| `config/` | 样品、项目路径、软件和数据库 | 必需 |
| `01_basic_qc/` | FASTQ 完整性、reads 数、可选去宿主 | 必需/去宿主可选 |
| `02_assembly/` | 单样品组装或真实 group coassembly；重命名与统计 | 必需 |
| `03_gene_catalog/` | Prodigal、非冗余 gene catalog、Salmon | 基础主流程 |
| `04_taxonomy/` | reads-based 与 contig-based Kaiju 分开 | 按研究问题 |
| `05_function_annotation/` | eggNOG 与 gene-taxon-function 联合 | 基础主流程 |
| `06_MAG/` | mapping、独立 binners、refinement、CheckM2、dRep、GTDB-Tk、CoverM | 可独立运行 |
| `07_virome/` | 病毒鉴定、CheckV、vOTU、丰度、可选 vRhyme | 可独立运行 |
| `08_virus_host/` | iPHoP、CRISPR、tRNA、homology 与规则化合并 | 依赖 vOTU/MAG |
| `09_metatranscriptome/` | gene/MAG/vOTU/AMG 转录 count、TPM、RPKM | 可独立运行 |
| `10_AMG/` | DRAM-v candidate、上下文人工校准、accepted AMG | 依赖高可信病毒 |
| `11_microbe_traits/` | AGS、16S copy、GC、MDT 的独立研究模块 | 可选 |
| `optional/` | 可靠 full outer TSV merge 等工具 | 辅助 |
| `slurm/` | 只读式提交模板，不自动提交 | 辅助 |

## 开始前

1. 在服务器运行 `conda info --base`，将 `config/conda_envs.sh` 中的 `CONDA_SH` 改为实际的 `etc/profile.d/conda.sh`。当前 `/path/to/...` 只是占位。
2. 用 `conda env list` 核对 `config/conda_envs.sh` 中每个工具环境名。旧 Notion 环境名已优先保留，但不假设它们仍存在。集群需要 module 时只填写管理员确认过的 `CONDA_MODULE`。
3. 编辑 `config/project_config.sh`、`config/databases.sh` 和 `config/samples.tsv`。
4. `samples.tsv` 中每个样品一行；任何脚本都不写死 CK/Low/High。
5. 先运行 `01_basic_qc/01_check_samples.sh`。它验证文件、样品 ID 和 `CONCURRENT_JOBS * THREADS_PER_JOB <= TOTAL_THREADS`。
6. 对一个小样品或截取数据做 dry-run。脚本不安装软件、不下载数据库、不连接服务器、不提交 SLURM。

每个可独立执行的分析脚本会 source `config/activate_conda_env.sh`，只激活该步骤需要的环境并检查关键命令。同一脚本需要 CheckM2、dRep、GTDB-Tk 等多个环境时按执行顺序切换。首次使用的命令、环境、可执行路径和版本写入 `results/software_versions.tsv`。

## 安全与命名

- 中间结果默认永不删除。只有未来脚本同时检查两个明确开关时才可考虑删除；当前交付脚本没有自动删除命令。
- contig ID 改为 `sample|完整原始contig_ID`，并检查重复。不会只保留下划线后的一个字段。
- 合并单样品 FASTA 只是 sequence collection，不称为 coassembly；基因去冗余是对 predicted genes 聚类，概念单独保留。
- FASTA 只能按完整 record 拆分，例如 `seqkit split2 -s`，禁止 `split -l`。
- TSV 矩阵用 full outer merge，保留所有 ID并补 0；禁止未排序的默认 `join`。

## 原代码到当前代码的重要修改

| 原记录 | 修改 | 原因 |
|---|---|---|
| 单个 `Low5` MEGAHIT 命令和 CK/Low/High 循环 | 全部从 `samples.tsv` 读取 | 避免漏样和跨项目误用 |
| 重命名只取 `arr[2]` | `sample|完整原ID` + uniqueness check | 防止 ID 截断和重复 |
| 拼接 assemblies 后 `rm` | 明确标为 collection，默认保留全部文件 | 可追溯与数据安全 |
| eggNOG `split -l` | 注释整份 catalog 或用 `seqkit split2 -s` | 普通行切分会破坏 FASTA record |
| `parallel -j 6`, 每任务 64 CPU | 资源契约 + 默认顺序样品 | 防止 384/640 CPU 超配 |
| CD-HIT 唯一方案 | MMseqs2 大数据默认，CD-HIT-EST 兼容可选 | 大 catalog 可扩展，同时保留原参数 |
| CheckV “去宿主”并删 Not-determined | 保留质量/污染/provirus 全表，不默认删任何 tier | Not-determined 是无法估完整度，不是非病毒 |
| vRhyme bin 删除标题后连接 | 保留 native multi-contig bin | 禁止制造嵌合假序列 |
| contig Kaiju 当群落丰度 | reads/contigs/MAG taxonomy 分目录解释 | 三种层级有不同偏倚和含义 |
| MAG Prodigal `-p meta` | dereplicated MAG 用 normal/single | 每个较完整 genome 应训练自身模型 |
| 手工 Excel 合并宿主证据 | 标准 long table + 可复现 consensus 脚本 | 保留冲突和单方法证据 |
| VIBRANT 表直接作为 AMG | candidate + 17 列校准 ledger + 手工 accept | 排除末端、宿主污染和缺乏病毒上下文的假阳性 |

## 软件/数据库记录

每次正式运行应保存 `command --version`、数据库 release/date、配置快照和输入 checksum。尤其记录 eggNOG、GTDB、CheckM2、geNomad、CheckV、iPHoP、Kaiju 数据库版本；同名工具跨版本输出字段可能变化。

## 当前参考

- nf-core/mag 5.4.2，用作步骤完整性和 assembly/binning 概念对照，不替换本流程：<https://nf-co.re/mag/latest/>
- MEGAHIT：<https://github.com/voutcn/megahit>
- Prodigal modes：<https://github.com/hyattpd/Prodigal/wiki/Gene-Prediction-Modes>
- MMseqs2：<https://github.com/soedinglab/MMseqs2>
- Salmon：<https://salmon.readthedocs.io/en/stable/salmon.html>
- eggNOG-mapper：<https://github.com/eggnogdb/eggnog-mapper/blob/main/USAGE.md>
- CheckM2：<https://github.com/chklovski/CheckM2>
- GTDB-Tk：<https://ecogenomics.github.io/GTDBTk/commands/classify_wf.html>
- CoverM：<https://github.com/wwood/CoverM>
- VirSorter2：<https://github.com/jiarong/VirSorter2>
- geNomad：<https://portal.nersc.gov/genomad/pipeline.html>
- CheckV：<https://pmc.ncbi.nlm.nih.gov/articles/PMC8116208/>
- DRAM-v：<https://github.com/WrightonLabCSU/DRAM/wiki/3b.-Running-DRAM-v>
