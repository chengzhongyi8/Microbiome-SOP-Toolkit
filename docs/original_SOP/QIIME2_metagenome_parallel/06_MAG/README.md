# MAG 模块

这里显式区分 assembly 和 binning 对象。运行映射脚本前必须设置 `ASSEMBLY_FASTA`，并记录它是单样品 assembly 还是真实 group coassembly；简单拼接多个 `final.contigs.fa` 不称为 coassembly。

推荐顺序是 reads 回贴产生跨样品覆盖矩阵、按需运行 2–3 个独立 binner、保留各自原始 bins、refinement、CheckM2、dRep、GTDB-Tk、CoverM 和 MAG 注释。MetaBAT2 可直接执行；MaxBin2/CONCOCT 因输入矩阵格式和 contig 切片策略需要项目级确认，脚本会停在明确的 review 提示，不伪造默认命令。

原记录的 MetaWRAP refinement 得到保留，但不是唯一选择；DAS Tool 可作为替代。reassembly 默认关闭。较完整的每个 MAG 用 Prodigal normal/single 模式；GTDB-Tk 自己也会调用 Prodigal，不需要为 taxonomy 预先固定 `-p meta`。

依据：<https://nf-co.re/mag/latest/docs/usage>、<https://github.com/chklovski/CheckM2>、<https://ecogenomics.github.io/GTDBTk/commands/classify_wf.html>、<https://github.com/wwood/CoverM>。

