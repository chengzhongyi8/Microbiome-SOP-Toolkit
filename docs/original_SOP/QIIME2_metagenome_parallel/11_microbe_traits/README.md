# 微生物基因组性状

这个目录保留原研究问题，但不强行并入主流程。

- QUAST/seqkit：全部 assembly 的 GC 与基础统计。
- MicrobeCensus：从 reads/规定长度 contigs 估计 average genome size，旧 Python 2 环境和抽样参数必须记录版本后再用。
- RasperGade16S：估计平均 16S copy number，输入与模型适用域需人工确认。
- gRodon：从可靠 CDS 和核糖体蛋白集合估计最短倍增时间；metagenome mode 与 MAG/genome mode不能混用。

所有样品均由 `samples.tsv` 读取。不同性状的输入对象不同，结果表必须保留 `input_level`（reads、contigs 或 MAG）和软件/数据库版本。

