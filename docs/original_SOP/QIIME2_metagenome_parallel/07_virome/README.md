# DNA 病毒模块

## 工具定位

- **当前主要方案**：`geNomad end-to-end` 作为默认，提供病毒/质粒识别、provirus、marker/NN evidence 和 ICTV taxonomy；或按项目改为 VirSorter2，并用 `--prep-for-dramv` 保留 DRAM-v 上下文。
- **质量评估**：CheckV 是完整度、终端重复、provirus 宿主污染区域和质量分层工具，不是 “去宿主 reads”。完整输出全部保留，Not-determined 不自动删除。
- **补充验证**：VirSorter2、DeepVirFinder、VIBRANT 可提供不同证据；默认不同时全跑。COBRA 只在有原 assembly graph、coverage、mapping 且确有延伸目的时使用。
- **历史/谨慎解释**：DeepVirFinder 和 VIBRANT 的单独命中不直接升级为最终 vOTU；PhaTYP/BACPHLIP lifestyle 结果保留置信度和未分类；vConTACT2 适合基因共享网络，不等同于最新 ICTV taxonomy。
- **不再作为默认**：旧 DIAMOND + MEGAN 病毒注释已移入 `legacy_code/`。

vRhyme 输出保持 multi-contig bin 结构，绝不删除标题后直接连接。vOTU 聚类默认 95% ANI、85% 较短序列覆盖，项目发表前需明确方向覆盖、环状/末端冗余和输入质量规则。

参考：<https://portal.nersc.gov/genomad/pipeline.html>、<https://github.com/jiarong/VirSorter2>、<https://github.com/AnantharamanLab/VIBRANT>、<https://pmc.ncbi.nlm.nih.gov/articles/PMC8116208/>。
