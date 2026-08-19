# SLURM 模板

模板不会自动提交。作业脚本内部会读取 `config/conda_envs.sh`、初始化 Conda并激活模块环境；不能依赖提交前登录 Shell 的激活状态。若集群要求 `module load`，只需在环境配置中填写确认过的 `CONDA_MODULE`。

`--cpus-per-task` 必须与 `THREADS_PER_JOB` 一致；如果改为 job array，同时运行的 array task 数乘每 task CPU 不得超过分配/队列限制。先用一个小样品或截取 reads 做 dry-run，再提交正式数据。
