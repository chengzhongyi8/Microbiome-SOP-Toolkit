# 宏转录组定量

`references.tsv` 明确列出基因 catalog、MAG genes、vOTU 或通过人工校准的 AMG reference。输出同时保留 raw count、覆盖比例、mean coverage、TPM 和 RPKM。count 适合后续使用正确设计矩阵的差异统计；TPM/RPKM 是长度和库规模归一化描述量，不直接等于绝对活性。vOTU 活性应同时检查覆盖广度，避免少数保守区域命中被解释为整条病毒转录。

