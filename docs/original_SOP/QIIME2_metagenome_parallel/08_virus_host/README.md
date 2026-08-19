# 病毒宿主预测

iPHoP、CRISPR spacer、病毒 tRNA 与长序列同源性结果分别保留。先把各工具结果标准化为 `virus_id, host_id, method, score, detail`，再用 `03_merge_host_evidence.py` 合并；脚本使用全连接思想，不会因某方法缺失而丢掉 pair。

默认合并规则：至少两种独立方法且含 CRISPR/iPHoP 为 high；至少两种为 medium；单方法为 single_method。一个病毒出现多个 host 时全部保留并标记 conflict，不能通过排序去重静默删除。物种/属级 host 合并还需统一 GTDB taxonomy 层级。

