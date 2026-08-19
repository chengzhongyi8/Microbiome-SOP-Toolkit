<div class="page-header-icon undefined">

<span class="icon" data-emoji="😁"></span>

</div>

# **自己分析流程 Pipeline**

<div class="page-body">

<div class="table_of_contents-item table_of_contents-indent-0">

[1. 生成 manifest](#d1e8c701-e156-4b91-966c-db67b5f0e8c9)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[2. 导入数据](#67dd590e-78cd-42d2-bcb7-22a710aad38a)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[3. 质控和生成特征表](#a841aa4c-65fb-417f-82a6-e7f46b2b1714)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[4. 构建进化树用于多样性分析](#73c25109-d487-4afc-88dd-89dd9e09a608)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[5. alpha 和 beta 多样性的分析](#d7043b41-87d3-480f-a79e-f764b89bcbbd)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[6. 物种组成分析](#0218573f-64bc-4412-9867-cc5284c9a779)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.1. 过滤](#9c2b75d0-1f5a-48ac-9852-6b4811a7b9a7)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.2. 过滤序列](#679f462c-d496-470e-8614-cb7da0d5fac4)

</div>

## 1\. 生成 manifest

第一列是 sample id，第二列和第三列分别是正向和反向序列文件的绝对路径。详情见 QIIME2 数据导入.md

这一步根据 之前的 python 脚本，在服务器下使用 jupyter lab，生成所需要的 manifest

`ls -d $PWD/*_R1.fastq.gz` 可以显示当前路径下所有文件的绝对路径

![](%E8%87%AA%E5%B7%B1%E5%88%86%E6%9E%90%E6%B5%81%E7%A8%8B%20Pipeline/Untitled.png)

-----

## 2\. 导入数据

首先 conda activate qiime2

实际数据是双端序列，根据 manifest 来

``` code code-wrap
qiime tools import \
--type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path manifest.tsv \
--output-path demux.qza \
--input-format PairedEndFastqManifestPhred33V2
```

对于单端序列

``` code code-wrap
qiime tools import \
--type 'SampleData[SequencesWithQuality]' \
--input-path se-33-manifest \
--output-path single-end-demux.qza \
--input-format SingleEndFastqManifestPhred33V2
```

生成的demux\_seqs.qza文件就是我们导入 Qiime2 后的文件。我们可以可视化来查看不同样本的序列数等等

``` code code-wrap
time qiime demux summarize \
    --i-data demux.qza \
    --o-visualization demux.qzv
```

![](%E8%87%AA%E5%B7%B1%E5%88%86%E6%9E%90%E6%B5%81%E7%A8%8B%20Pipeline/Untitled%201.png)

![](%E8%87%AA%E5%B7%B1%E5%88%86%E6%9E%90%E6%B5%81%E7%A8%8B%20Pipeline/Untitled%202.png)

-----

## 3\. 质控和生成特征表

用 dada2 来去噪生成 ASVs 表。在上一个 **demux.qzv** 可视化文件中，我们要关注左右两端各切多少的问题。注意，这四个参数的值不需要一致。【这一步耗时较久】

``` code code-wrap
time qiime dada2 denoise-paired \
    --i-demultiplexed-seqs demux.qza \
    --p-trim-left-f 0 \
    --p-trim-left-r 0 \
    --p-trunc-len-f 220 \
    --p-trunc-len-r 220 \
    --o-table table.qza \
    --o-representative-sequences rep-seqs.qza \
    --o-denoising-stats stats.qza \
    --p-n-threads 40
    
    #核数不能拉满
```

然后进行特征表的过滤，保留**至少在 2 个样品里存在**的 ASVs：**【这个可以自己来选择】**

``` code code-wrap
time qiime feature-table filter-features \
  --i-table table.qza \
  --p-min-samples 2 \
  --o-filtered-table filtered-table.qza
```

导出特征表【ASVs table】

``` code code-wrap
#导出特征表为 biom 格式
qiime tools export \
    --input-path filtered-table.qza \
    --output-path feature-table
#转换biom格式特征表为tsv格式
biom convert -i feature-table/feature-table.biom \
    -o feature-table/feature-table.txt \
    --to-tsv
```

【选用】然后对所获得的特征表和特征序列进行可视化，为了以后的分析

``` code code-wrap
# 查看Feature表的统计结果
time qiime feature-table summarize \
    --i-table filtered-table.qza \
    --o-visualization filtered-table.qzv \
    --m-sample-metadata-file sample_metadata.txt

# 代表序列统计
time qiime feature-table tabulate-seqs \
    --i-data rep-seqs.qza \
    --o-visualization rep-seqs.qzv

#中间过程可视化
####   需要这个 table.qza #### 计算 alpha 多样性 也可以在 R 中计算
qiime metadata tabulate \
--m-input-file stats.qza \
--o-visualization stats.qzv
```

-----

## 4\. 构建进化树用于多样性分析

``` code code-wrap
先创建一个新文件夹tree，用于存放 tree 相关的全部文件
mkdir tree

time qiime phylogeny align-to-tree-mafft-fasttree \
    --i-sequences rep-seqs.qza \
    --o-alignment tree/aligned-rep-seqs.qza \
    --o-masked-alignment tree/masked-aligned-rep-seqs.qza \
    --o-tree tree/unrooted-tree.qza \
    --o-rooted-tree tree/rooted-tree.qza \
    --p-n-threads 32
```

然后导入上一步生成的进化树：导出结果为 exported-tree/tree.nwk 是标准树nwk文件

``` code code-wrap
qiime tools export --input-path  tree/unrooted-tree.qza \
  --output-path tree/exported-tree
```

-----

【选用】外部数据导入 qiime2：

``` code code-wrap
biom convert -i otutab.txt -o otutab.biom \
--table-type="OTU table" --to-json

导入特征表
qiime tools import --input-path otutab.biom \
--type 'FeatureTable[Frequency]' --input-format BIOMV100Format \
--output-path table.qza

导入代表序列
qiime tools import --input-path otus.fa \
--type 'FeatureData[Sequence]' \
--output-path rep-seqs.qza
```

-----

## 5\. alpha 和 beta 多样性的分析

在这一步需要提供一个重要的参数**--p-sampling-depth**，指的是重采样的深度。通过查看上面的 **table.qzv** 中的信息，尽可能选择一个高的值（每个样本保留更多的序列）。目前大概在 3w-5w 的标准来抽平。这里选择4w 条

``` code code-wrap
time qiime diversity core-metrics-phylogenetic \
    --i-phylogeny tree/rooted-tree.qza \
    --i-table table.qza \
    --p-sampling-depth 20000 \
    --m-metadata-file sample_metadata.txt \
    --output-dir core-metrics-results
```

输出对象有 13 个数据文件，4 个可视化结果

同时可以指定计算某一种 alpha 多样性：(此命令没有参数--p-sampling-depth)

``` code code-wrap
qiime diversity alpha --i-table table.qza --p-metric goods_coverage --o-alpha-diversity goods_coverage.qza
```

enspie|michaelis\_menten\_fit | strong | lladser\_pe | fisher\_alpha| goods\_coverage | doubles | simpson | margalef | observed\_otus | osd| shannon | pielou\_e | chao1 | brillouin\_d | menhinick | simpson\_e| kempton\_taylor\_q | robbins | dominance | lladser\_ci|heip\_e| singles | chao1\_ci | mcintosh\_d | ace | mcintosh\_e | gini\_index| berger\_parker\_d | esty\_ci其他的一些重要的 alpha 多样性指数如 observed\_otus、observed\_species、PD\_whole\_tree

稀释曲线分析：

稀释性曲线图中，当曲线趋向平坦时，说明取样的数量合理，更多的取样只会产生少量新的OTU，反之则表明继续取样还可能产生较多新的OTU。因此，通过作稀释性曲线，可以得出样品的取样深度情况。

你设定的`–p-max-depth`的值应该根据特征表统计的可视化图 `table.qzv` 来选择，一般选择median frequency的值。如果稀释性曲线结果不好的话，可以适当提高或降低，但通常不能超出\[low total frequency, max total frequency\]的范围。

``` code code-wrap
qiime diversity alpha-rarefaction \
        --i-table table.qza \
        --i-phylogeny tree/rooted-tree.qza \
        --p-max-depth 24639 \
        --m-metadata-file sample_metadata.txt \
        --o-visualization alpha-rarefaction.qzv
```

-----

## 6\. 物种组成分析

**先下载好预训练好的分类器**

物种注释

创建一个文件夹命名为 taxa，用于存放物种注释相关的全部文件

首先将预训练好的分类器放在 taxa 目录下

``` code code-wrap
mkdir taxa
time qiime feature-classifier classify-sklearn \
    --i-classifier /home/user/soybean/db/qiime2_silva-138-99-nb-classifier.qza \
    --i-reads rep-seqs.qza \
    --o-classification taxa/taxonomy.qza \
    --p-n-jobs -1
```

可视化分类结果

``` code code-wrap
qiime metadata tabulate \
  --m-input-file taxa/taxonomy.qza \
  --o-visualization taxa/taxonomy.qzv
```

过滤掉线粒体和叶绿体：

``` code code-wrap
qiime taxa filter-table \
--i-table table.qza \
--i-taxonomy taxa/taxonomy.qza \
--p-exclude mitochondria,chloroplast,Archaea \
--o-filtered-table taxa/filter-taxa.qza
```

可视化

``` code code-wrap
qiime metadata tabulate \
    --m-input-file taxa/filter-taxa.qza \
    --o-visualization taxa/filter-taxonomy.qzv
```

物种注释堆叠图

``` code code-wrap
qiime taxa barplot \
    --i-table filtered-table.qza \
    --i-taxonomy taxa/taxonomy.qza \
    --m-metadata-file sample_metadata.txt \
    --o-visualization taxa/taxa-bar-plots.qzv
```

### 6.1. 过滤

过滤门水平下的物种组成表（同时去掉叶绿体和线粒体）：filter-table:

``` code code-wrap
qiime taxa filter-table \
--i-table table.qza \
--i-taxonomy taxonomy.qza \
--p-include p__ \
--p-exclude mitochondria,chloroplast \
--o-filtered-table table-with-phyla-no-mitochondria-no-chloroplast.qza
```

### 6.2. 过滤序列

filter-seq:在门水平上无线粒体和叶绿体的代表序列

``` code code-wrap
qiime taxa filter-seqs \
--i-sequences sequences.qza \
--i-taxonomy taxonomy.qza \
--p-include p__ \
--p-exclude mitochondria,chloroplast \
--o-filtered-sequences sequences-with-phyla-no-mitochondria-no-chloroplast.qza
```

</div>

<span class="sans" style="font-size:14px;padding-top:2em"></span>
