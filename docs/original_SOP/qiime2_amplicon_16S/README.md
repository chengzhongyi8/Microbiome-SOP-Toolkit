# QIIME2 扩增子分析 SOP（半自动 + 一键自动化）

本目录是一套**配置驱动**的 QIIME2 扩增子流程，支持两种用法：

1. **一键自动化（推荐）**：只要告诉它 FASTQ 目录、扩增区域（或引物）、classifier，它就自动：
   - 解析 region → 引物（`primers.tsv`，可覆盖）；
   - 自动检测 reads 前端是否还有引物，有则自动 `cutadapt`；
   - 自动从质量曲线估计 DADA2 的 trim/trunc（可手动覆盖）；
   - 没有 metadata 时自动生成最小 metadata；
   - 跑完 DADA2 → 分类 → 过滤 → 建树 → 导出 microeco → 生成结果汇总。
2. **手动模式（原两阶段）**：`run_qc.sh` 停在 demux 质量图，人工填 DADA2 参数后再 `run_after_qc.sh`。

---

## 1. 快速开始（一键）

在服务器上（先按第 4 节装好 conda 环境）：

```bash
# 1) 把本文件夹同步到服务器（在本地 Mac 上执行）
rsync -av --exclude '.DS_Store' --exclude 'results/' --exclude 'work/' \
  ./qiime2_amplicon/ user@server:/home/user/qiime2_project/qiime2/

# 2) 登录服务器，生成项目配置（会写 config.local.sh）
cd /home/user/qiime2_project/qiime2
bash setup_project.sh \
  --fastq-dir  /data/amplicon/2026-08/fastq \
  --region     16S_V4 \
  --classifier /db/qiime2/silva-138-99-515-806-nb-classifier.qza \
  --conda-sh   /home/user/anaconda3/etc/profile.d/conda.sh

# 3) 一键开跑（可用 nohup 挂后台）
bash run_all.sh
# 或等价地直接一步：
# bash run_all.sh --fastq-dir ... --region ... --classifier ... --conda-sh ...
```

> 没有 classifier 时，可设 `--classifier-dir /db/qiime2`，脚本会按区域关键词自动挑选；
> 若该目录只有一个 `.qza` 也会自动选中。批量跑完可看
> `results/summary/README_summary.md` 和 `results/pipeline.log`。

## 2. 常用参数

| 参数 | 说明 |
|---|---|
| `--fastq-dir DIR` | FASTQ 目录（顶层，文件名形如 `xxx_R1.fastq.gz`/`xxx_R2.fastq.gz`） |
| `--region NAME` | 扩增区域，如 `16S_V4`、`16S_V3V4`、`ITS1`、`ITS2`、`18S_V4`、`COI`（见 `primers.tsv`） |
| `--forward-primer / --reverse-primer` | 自定义引物（覆盖 region 默认值；IUPAC 简并碱基可用） |
| `--classifier PATH` / `--classifier-dir DIR` | 分类器 |
| `--mode paired|single` | 默认 paired |
| `--metadata PATH` | 样品 metadata（默认自动生成最小 metadata） |
| `--project-dir DIR` | 输出目录（默认读 config） |
| `--auto-trunc yes|no` | 自动估计 DADA2 trunc（默认 yes；填了手动值则手动优先） |
| `--auto-primer-trim yes|no` | 自动检测并去除引物（默认 yes） |
| `--quality-threshold N` | 自动 trunc 的 mean-Q 阈值（默认 20） |
| `--expected-amplicon-len N` | 插入片段长度（不含引物），用于双端重叠检查 |
| `--min-samples N` | prevalence 过滤（默认不做） |
| `--threads N` | 统一设置 cutadapt/DADA2/分类/建树线程 |
| `--resume yes|no` / `--force` | 断点续跑 / 强制重跑 |

`bash run_all.sh --help` 查看全部参数。`bash setup_project.sh` 只生成 `config.local.sh` 不跑流程。

## 3. 手动模式（保留原两阶段）

```bash
# 阶段一：校验 → manifest → 导入 → demux 质量图，然后停下
bash run_qc.sh
# 看 results/qc/demux.qzv，填 config.sh / config.local.sh 的 TRIM_LEFT_*/TRUNC_LEN_*
# （或保持 AUTO_TRUNC=yes 让阶段二自动估计）
# 阶段二：cutadapt → DADA2 → 分类过滤 → 建树 → 导出 microeco → 汇总
bash run_after_qc.sh
```

## 4. 服务器环境准备

```bash
conda info --base                     # 记下 conda 根目录，例如 /home/user/anaconda3
# CONDA_SH 应填:  <上面路径>/etc/profile.d/conda.sh
# 集群若需 module 加载 conda，先确认 module 名再填 CONDA_MODULE（不要猜）

# QIIME2 2026.4（amplicon 发行版；也可用你自己已有的 qiime2 环境，改 QIIME2_ENV 即可）
wget https://data.qiime2.org/distro/amplicon/qiime2-amplicon-2026.4-py38-linux-conda.yml
conda env create -n qiime2 --file qiime2-amplicon-2026.4-py38-linux-conda.yml
conda activate qiime2 && qiime --version

# R + file2meco + microeco（仅用于最终验证，可后装）
conda create -n microeco -c conda-forge r-base
conda activate microeco
Rscript -e 'install.packages("remotes", repos="https://cloud.r-project.org")'
Rscript -e 'remotes::install_github("ChiLiubio/file2meco")'
Rscript -e 'remotes::install_github("ChiLiubio/microeco")'
```

`results/software_versions.tsv` 会记录实际使用的 qiime/R 版本。

## 5. 配置文件

- `config.sh`：默认值（一般不用改）。
- `config.local.sh`：每个项目的实际配置，由 `setup_project.sh` / `run_all.sh` 自动生成，也可手改。
- `primers.tsv`：内置扩增区域 → 引物/插入长度/classifier 关键词。**生产前请核对引物是否与你的测序方案一致**（可随时用 `--forward-primer/--reverse-primer` 覆盖）。
- 管线自动生成：`work/generated.env`（自动 metadata 路径）、`work/primers.env`（引物检测结论）、`work/dada2_auto.env`（自动 DADA2 参数），一般无需手改。

## 6. 输出目录

| 路径 | 说明 |
|---|---|
| `results/qc/` | demux.qza/.qzv、每样本 reads 数、输入校验 |
| `results/dada2/` | DADA2 表/代表序列/stats 及 qzv |
| `results/taxonomy/` | 未过滤物种注释 |
| `results/final/` | 同步后的最终 feature-table/rep-seqs/taxonomy/tree（qza+qzv） |
| `results/microeco_input/` | file2meco 五个直接输入 + TSV/FASTA/Newick 导出 + 校验表 |
| `results/downstream/` | 可选：core metrics / alpha rarefaction / taxa barplot |
| `results/summary/` | 汇总报告（`README_summary.md`、`summary_report.tsv`） |
| `results/pipeline.log` | 全流程日志 |
| `results/software_versions.tsv` | 软件版本 |

microeco 读取示例：

```r
obj <- file2meco::qiime2meco(
  feature_table  = "results/microeco_input/feature-table.qza",
  sample_table   = "results/microeco_input/metadata.tsv",
  taxonomy_table = "results/microeco_input/taxonomy.qza",
  phylo_tree     = "results/microeco_input/rooted-tree.qza",
  rep_fasta      = "results/microeco_input/rep-seqs.qza",
  auto_tidy      = TRUE
)
```

## 7. 人工检查点（自动化不会替你决定）

- **classifier 必须与扩增区域/引物方向匹配**（如 V4 数据用 515F/806R 的 classifier）。
- 自动估计的 DADA2 参数是**建议值**：极端文库（严重降解、长度异常）建议仍打开 `demux.qzv` 复核，可在 `config.local.sh` 直接填手动值覆盖。
- metadata 若为自动生成（只有 `sample_name` 列），做组间比较前请换成真实分组列。
- 可选下游（`RUN_CORE_METRICS` 等）的抽平深度需人工设置。
- 双端重叠警告（`R1+R2 无法覆盖插入长度`）意味着 reads 太短，需要换测序策略或接受缺口。

## 8. 常见问题

- `CONDA_SH` 报错：把它改成服务器上 `conda info --base` 得到的路径 + `/etc/profile.d/conda.sh`。
- 找不到 classifier：`--classifier` 或 `--classifier-dir`（目录里多个 qza 时需明确指定）。
- FASTQ 没被发现：文件必须在 `--fastq-dir` 顶层，且后缀匹配 `_R1/_R2/_1/_2`（或单端 `.fastq.gz`）。
- 想完全手动控制 DADA2：`--auto-trunc no`，并填 `TRIM_LEFT_*`/`TRUNC_LEN_*`。
