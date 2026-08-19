# AMG 模块

VIBRANT 或 DRAM-v 的输出只能是 candidate AMG。最终接受前逐基因检查：位置是否靠 contig 末端、病毒 contig 的 CheckV 质量与宿主污染、两侧邻近基因、病毒 hallmark 支持、代谢基因身份是否由多个数据库/结构域支持、是否更像被带入的宿主基因。`amg_curation.tsv` 保存 accept/reject/uncertain 和理由，只有 accept 被提取用于 metaG/metaT 定量。

DRAM-v auxiliary score 和 flags 是筛选线索，不替代人工校准。参考：<https://github.com/WrightonLabCSU/DRAM/wiki/3b.-Running-DRAM-v>。

