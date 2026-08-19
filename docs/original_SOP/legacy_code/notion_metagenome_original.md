![](https://app.notion.com/images/page-cover/met_william_morris_1877_willow.jpg)

<div class="page-header-icon page-header-icon-with-cover">

<span class="icon" data-emoji="🍛"></span>

</div>

# 大豆根际样品分析（2023.7.20-）

<div class="page-body">

<div class="table_of_contents-item table_of_contents-indent-0">

[① Contigs 分析](#e79ac5de-ad3c-40f7-b60d-ced4f8164088)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.1 拼接 megahit](#e365ae16-215f-425d-a2f5-4cae27ea35ab)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.2 功能注释 prodigal](#db5cfe52-afcd-42b9-a2ca-e766ab54d96f)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.3 去冗余 CD-HIT](#b791a137-8c72-44f6-ab58-18b13130f976)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.4 Salmon 定量](#f7e0da07-a91b-4b71-8ce7-2ebed393b349)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.5 功能基因注释](#d4aaccf0-6eeb-4821-a8a5-c43b085efeef)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[1.6 分析每个物种（门水平，科水平等）的特定的功能基因丰度](#822f05e1-dd89-4336-966d-4b60c337d31f)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[② DNA 病毒分析](#1ee215ef-49f1-4626-ad13-155443b730c1)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.1 病毒序列鉴定 (Sullivan lab SOP + Deepvirfinder + VIBRANT)](#2891a67d-d684-4132-aa8e-5fd591b6d719)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.1.1 Sullivan lab SOP](#9d6abeba-a850-4010-8449-d1f13b151803)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.1.2 DeepvirFinder](#0db3db1f-13bf-44b1-b358-c2341c175f3f)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.1.3 VIBRANT](#3f6cef87-1488-4cb1-ba66-4b98fa618bee)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.2 病毒序列分析](#d1dfe794-b4ae-48b7-a621-8c86037ef85d)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.2.1 checkv 去宿主](#b8b87f7f-c637-4338-8293-a3c161ac3b2e)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.2.2 COBRA 提高病毒序列准确度](#73ea5c7e-d845-414f-a4b1-030696f50979)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.2.3 checkv再检查 去除 not-determined](#e099e6ce-acbf-4bf0-b2bd-d15bd9072c36)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.2.1 病毒 bins 分箱](#e9415c5e-5641-4ddf-809e-760319315ed1)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.3 病毒 lifestyle 预测 (PhaTYP \\ **BACPHLIP\\VIBRANT结果**)](#7a5157ff-9451-493b-a833-67187b34e35e)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.3.1 PhaTYP](#dbcd9182-5966-4921-ae5a-c26bbb9f4eb2)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.3.2 BACPHLP](#a18d89dd-3eb6-4989-862a-1d84e420882a)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.4 vOTUs 丰度 (coverm)](#3b315d57-1313-4461-bc1a-741e121592fc)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.4.1 比对宏基因组序列获得丰度 rpkm](#12a5ee7c-2f64-431c-8bb3-b01a4a18d6db)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.4.2 比对宏转录组数据获得活性 vOTUs 丰度 tpm](#c92102ae-d704-47b8-b9e3-073829c33988)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.5 基因注释 (prodigal)](#db8ecf7d-6048-4eb5-b9cc-4d03dbf97289)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[2.6 物种注释](#f1c9f243-8a1d-4f85-ba6f-69b6e4c4d54a)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.6.1 Diamond + MEGAN (结果不理想——弃用）](#f531e507-b789-42e5-817a-0cc1411468e5)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.6.2 PhaGCN](#c7aee2bc-65cb-4a33-80b7-858aac887490)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.6.3 geNomad](#1f7e2205-70d0-477f-b970-69a3ea78e109)

</div>

<div class="table_of_contents-item table_of_contents-indent-2">

[2.6.4 vConTACT2](#fc87ac0a-14b3-4fa7-ad1b-e94f9c17b771)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[③ Bin【每个样品分开来 bin】](#637d3f2c-870b-489d-8420-86e3b517d74c)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[3.1 metawrap 运行 bin](#a806bea9-904e-4c33-86f5-1bdd89365a2e)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[3.2 bin 定量 rpkm](#68139793-5664-4ebe-b5d5-943cc9b38637)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[3.3 bin 丰度比对到宏转录组数据 tpm](#5add2493-cede-4122-8d33-4f915bb75999)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[3.4 物种注释](#2c4583bb-faad-4c2e-9bdb-3d7bd1e23474)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[3.5 功能注释](#015b611c-f440-4435-a7b1-83a3626bd2e0)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[④ 病毒-宿主互作](#e0a8ffc6-92e3-4d14-b67f-9a67b3c6bbf8)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[4.1 iPHop (by Simon Roux)](#1ead31ca-bf81-413f-9fdc-9b34832755fd)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[4.2 tRNA](#9c237fc8-cdf6-479b-8122-6317b90c45d6)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[4.3 CRISPR](#28d6a87f-7d80-43ce-be60-058afd9d4a4f)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[4.4 Homology match](#81e1e162-5595-45ed-a064-48617b87b3de)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[⑤ 病原菌分析](#b1febd0d-0c10-46da-927b-0def28414758)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[⑥ 细菌基因组大小分析](#c0d40224-1c55-40be-bbfc-1926f20ad8a8)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.1 **MicrobeCensus (v1.1.0) 评估 average genome size (AGS)**](#20125e5d-cf47-4cae-95be-f0a6aa7a666b)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.2 平均 16S rRNA 基因拷贝数 average 16S rRNA gene copy number](#6883baca-61ca-4807-befe-5e0d6704e405)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.3 GC 含量(Quast v4.5)](#d92df9ce-9a96-46ee-870e-c9dbd033d763)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[6.4 gRodon 评估 Minimal doubling time MDT](#9d5ce734-31b4-4108-a8eb-a7a3383ba6d6)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[⑦ 物种组成](#4c191025-67c3-40a5-a588-2c4e3ab6a344)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[7.1 contigs 水平 (FASTQ水平也适用) ⇒ 基于 Kaiju](#b415fd9b-599f-4e13-b550-da07d90147f7)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[7.2 MAGs 水平](#5c6df209-457f-4ff0-b13c-79c59ba07505)

</div>

<div class="table_of_contents-item table_of_contents-indent-1">

[7.3 mRNA 水平](#6d080e13-a226-430b-b29e-71ebeb5bfa59)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[⑧ 宏转录组数据 map 到 AMG.fa中](#fc541e21-1c5b-4500-b04b-67163c7b9b07)

</div>

<div class="table_of_contents-item table_of_contents-indent-0">

[⑨ AMG 丰度 分析](#cb41cb6d-9417-4f3e-a2d8-1989556d7ab0)

</div>

-----

# ① Contigs 分析

![](%E5%A4%A7%E8%B1%86%E6%A0%B9%E9%99%85%E6%A0%B7%E5%93%81%E5%88%86%E6%9E%90%EF%BC%882023%207%2020-%EF%BC%89/Untitled.png)

## 1.1 拼接 megahit

``` code code-wrap
cd /home/user/Project2_next_soybean/metagenomic

megahit -1 seq_data/Low5_clean_R1.fq.gz -2 seq_data/Low5_clean_R2.fq.gz \
-o megahit/Low5 -t 64 --k-step 10 --k-min 21 --k-max 141 --min-contig-len 200
```

统计每个样品中拼接完的序列的信息 `seqkit stat temp/megahit/*/final.contigs.fa -j 20`

![](%E5%A4%A7%E8%B1%86%E6%A0%B9%E9%99%85%E6%A0%B7%E5%93%81%E5%88%86%E6%9E%90%EF%BC%882023%207%2020-%EF%BC%89/Untitled%201.png)

修改名称

``` code code-wrap
cd temp/megahit

# 修改名字
for folder in *; do
    cd "$folder" || continue
    
    for file in final.contigs.fa; do
        awk -v folder="$folder" '{
            if ($0 ~ /^>/) {
                split($1, arr, "_");
                contig_name = folder "|" arr[2];
                print ">" contig_name;
            } else {
                print $0;
            }
        }' "$file" > temp.fa
        
        mv temp.fa "$file"
    done
    
    cd ..
done
```

合并每个样品的拼接结果(clean.fa, contigs.1000kb.fa)

``` code code-wrap
# 合并所有的 final.contigs.fa
cat */final.contigs.fa > final.contigs.fa
# 对序列去重
seqkit rmdup -s -o clean.fa final.contigs.fa
# 选择 >1000kb 的继续分析
seqkit seq -m 5000 -g clean.fa > 5kb.fa
rm final.contigs.fa clean.fa #删除以减少空间占用
# 查看过滤后的 contigs 信息
seqkit stat 5kb.fa
------------------------------------------------------------------------------------------
file    format  type  num_seqs        sum_len  min_len  avg_len  max_len
5kb.fa  FASTA   DNA    120,206  1,120,872,166    5,000  9,324.6  934,623
------------------------------------------------------------------------------------------
```

## 1.2 功能注释 prodigal

这一步，选择 \> 500bp的进行后续的分析 `/megahit/500bp.fa` ⇒移动到 `function_contig/prodigal`

|          |        |      |            |                |          |          |          |
| -------- | ------ | ---- | ---------- | -------------- | -------- | -------- | -------- |
| file     | format | type | num\_seqs  | sum\_len       | min\_len | avg\_len | max\_len |
| 500bp.fa | FASTA  | DNA  | 18,528,397 | 16,909,910,769 | 500      | 912.6    | 934,623  |

``` code code-wrap
cd function_contig
mkdir prodigal && cd prodigal

n=50000
# 这一步生成的文件夹为final.contigs.fa.split，在 megahit目录里，手动移到 prodigal 下
seqkit split 500bp.fa -s $n 
ls 500bp.fa.split/500bp.part_*.fa|cut -f 2 -d '_'|cut -f 1 -d '.' > split.list\

# 多线程同步
mkdir temp
cat split.list | xargs -I{} -P 50 sh -c 'prodigal -i 500bp.fa.split/500bp.part_{}.fa \
          -d temp/gene{}.fa  \
          -o temp/gene{}.gff -p meta -f gff \
          > temp/gene{}.log 2>&1'

# 合并基因序列
cat temp/gene*.fa > gene.fa
cat temp/gene*.gff > gene.gff
```

## 1.3 去冗余 CD-HIT

``` code code-wrap
mkdir cd-hit

# aS覆盖度，c相似度，G局部比对，g最优解，T多线程，M内存0不限制
time cd-hit-est -i ../gene.fa \
        -o nucleotide.fa \
        -aS 0.9 -c 0.95 -G 0 -g 0 -T 0 -M 0
# 统计非冗余基因数量，单次拼接结果数量下降不大，多批拼接冗余度高
grep -c '>' nucleotide.fa #14276776
# 翻译核酸为对应蛋白序列, --trim去除结尾的*
seqkit translate --trim nucleotide.fa > protein.fa
```

## 1.4 Salmon 定量

``` code code-wrap
mkdir salmon

# 建索引 -t 序列 -i 索引
/home/user/software_documents/salmon/bin/salmon index -t cd-hit/nucleotide.fa -p 64 -i salmon/index

# 并行
tail -n+2 ../metadata.txt \
  | cut -f1 \
  | parallel -j 6 "/home/user/software_documents/salmon/bin/salmon quant -i ../temp/function_contig/prodigal/salmon/index -l A -p 64 --meta \
        -1 {1}_clean_1.fastq -2 {1}_clean_2.fastq \
        -o ../temp/function_contig/prodigal/salmon/{1}.quant"

# 合并
/home/user/software_documents/salmon/bin/salmon quantmerge \
        --quants salmon/*.quant \
        -o salmon/gene.TPM

/home/user/software_documents/salmon/bin/salmon quantmerge \
        --quants salmon/*.quant \
        --column NumReads -o salmon/gene.count

sed -i '1 s/.quant//g' salmon/gene.*

# 预览
head -n3 salmon/gene.*
```

## 1.5 功能基因注释

``` code code-wrap
mkdir eggnog

seqkit seq -w 0 prodigal/cd-hit/protein.fa > prodigal/cd-hit/prot.cd.hit1.fa

# 拆分
mkdir split && cd split
split -l 200000 -a 3 -d ../../cd-hit/prot.cd.hit1.fa input_file.chunk_

# pbs
cd /home/user/Project3_rice/metagenomic/temp/eggnog/split

source activate eggnog2.0.1

cp -r /home/user/database/eggnog_2022_12_4 /dev/shm

time parallel -j 10 --xapply \
  'emapper.py -m diamond --no_annot --no_file_comments --data_dir /tmp/eggnog_2022_12_4 --override --cpu 64 -i {1} -o {1}' \
 ::: input_file.chunk*

cat *.chunk_*.emapper.seed_orthologs > ../emapper.seed_orthologs

time emapper.py \
      --annotate_hits_table ../emapper.seed_orthologs \
      --data_dir /tmp/eggnog_2022_12_4 \
      --cpu 64 --no_file_comments --override \
      -o ../output

rm -r /tmp/eggnog_2022_12_4

sed '1 i Name\tortholog\tevalue\tscore\ttaxonomic\tprotein\tGO\tEC\tKO\tPathway\tModule\tReaction\trclass\tBRITE\tTC\tCAZy\tBiGG\ttax_scope\tOG\tbestOG\tCOG\tdescription' \
      output.emapper.annotations \
      > output

--------------------------------------------------------
# 丰度表
conda activate basta_py3
python /home/user/summarizeAbundance.py \
      -i prodigal/salmon/gene.TPM \
      -m eggnog/output \
      -c '9,16,21' -s ',+,+*' -n raw \
      -o eggnog/eggnog

#添加注释文件
sed -i 's#^ko:##' eggnog/eggnog.KO.raw.txt
sed -i '/^-/d' eggnog/eggnog*
```

## 1.6 分析每个物种（门水平，科水平等）的特定的功能基因丰度

``` code code-wrap
# 分析物种和功能之间的关系
cut -f1,5,9,16,21 output > tax_func.txt # 1-基因名 5-物种 9-KO 16-CAZy 21-COG


conda activate py2

# 丰度表
abundance = pd.read_table('/home/user/Project2_next_soybean/metagenomic/temp/function_contig/prodigal/salmon/gene.TPM', index_col=0)

# 物种表
lca = pd.read_table('/data/user/Project2/temp/taxonomy/nr_blast_out.m8.tax.tsv', sep='; ;',engine='python', header=None,index_col=0)
tax = lca[1].str.split('; \d+;',expand=True,n = 7)[range(7)]
tax.columns = ['domain','phylum','class','order','family','genus','species']
tax = tax.fillna('None',inplace=False)





```

# ② DNA 病毒分析

## 2.1 病毒序列鉴定 (Sullivan lab SOP + Deepvirfinder + VIBRANT)

用到 Sullivan lab 的 SOP流程 、DeepVirFinder 以及 VIBRANT

[<span class="icon" data-emoji="🐻‍❄️"></span>SOP病毒提取 pipeline (Sullivan Lab)](https://app.notion.com/p/SOP-pipeline-Sullivan-Lab-6a78f07e734c4c8c99ee4086bc72740a?pvs=21) [DeepVirFinder -env deepvirfinder](https://app.notion.com/p/DeepVirFinder-env-deepvirfinder-9ffd5010afd741aa80d4edb7c0698eb0?pvs=21) [VIBRANT(鉴定 AMGs 的）-鉴定细菌/古菌病毒](https://app.notion.com/p/VIBRANT-AMGs-b1498ac9fb214e10b07e7f1eb62a7e63?pvs=21)

*`本次分析的是 5kb 以上的序列`*

``` code code-wrap
$ tree -L 1                        
.
├── cd-hit.pbs
├── cd_hit_virus.fa
├── checkv1
├── checkv2
├── deep.pbs
├── deepvirfinder
├── dup_contigs.fa
├── dup_name_contigs.fa
├── raw_viral_contigs.fa
├── sullivan_SOP
├── vibrant
└── vibrant.pbs
```

### 2.1.1 Sullivan lab SOP

``` code code-wrap
#########       Sullivan lab SOP       #########  
### 最终文件：vs2-pass2/final-viral-combined.fa
##############################

# 第一步 vs2提取可能的病毒序列
cd /home/user/Project2_next_soybean/metagenomic/temp
mkdir dna_virus
cd dna_virus

source activate vs2

virsorter run \
  -w vs2-pass1 \
  -i ../megahit/contigs.1000kb.fa \
  --min-length 5000 \
  --use-conda-off \
  --include-groups \
  -j 64 all

# 第二步 checkv 质控
cd /home/user/Project2_next_soybean/metagenomic/temp/dna_virus
conda activate py3

# 使用 CheckV 进行端到端检查
checkv end_to_end \
  vs2-pass1/final-viral-combined.fa \
  chekv_output \
  -d /home/user/database/virus.db/checkv-db-v1.0 \
  -t 64

# 第三步 再次运行 vs2
# 先将 checkv 结果中的 proviruses 和 viruses 的 fa 合并，为获得的 fa 文件
cat chekv_output/proviruses.fna chekv_output/viruses.fna > chekv_output/combined.fna

# 再进行一次 VirSorter2
conda activate vs2

virsorter run \
  --seqname-suffix-off \
  --viral-gene-enrich-off \
  --prep-for-dramv \
  -i chekv_output/combined.fna \
  -w vs2-pass2 \
  --include-groups dsDNAphage,ssDNA \
  --min-length 5000 \
  --min-score 0.5 \
  --use-conda-off \
  -j 32 all # 这里不能设置太满

# 挑选 VirSorter2 score ≥0.95 or hallmark gene count >2
# excel 完成
seqkit grep -f <(cut -f1 final-viral-score.tsv) -i final-viral-combined.fa > vs2.fa
```

### 2.1.2 DeepvirFinder

``` code code-wrap
#########       DeepvirFinder       #########   # 建议 pbs 跑 # 线程数不要设满
### 最终文件：dvf_sequences.fa
##############################
mkdir deepvirfinder
conda activate deepvirfinder

python /home/user/Applications/DeepVirFinder/dvf.py \
    -i ../../megahit/5kb.fa \
    -o deepvirfinder \
    -l 1000 \
    -c 64

# 筛选 score >= 0.9, pvalue < 0.05 的
awk '$3 >= 0.9 && $4 < 0.05 {print}' 5kb.fa_gt5000bp_dvfpred.txt > dvf_filter.txt

# 提取序列
seqkit grep -f <(cut -f1 dvf_filter.txt) -i ../../../megahit/5kb.fa > dvf_sequences.fa
```

### 2.1.3 VIBRANT

``` code code-wrap
#########       VIBRANT       #########    # 线程数不要设满
### 最终文件：VIBRANT_5kb/VIBRANT_phages_5kb/5kb.phages_combined.fna 
##############################
conda activate vibrant

python3 /home/user/database/virus.db/VIBRANT/VIBRANT_run.py \
        -i ../../megahit/5kb.fa \
        -t 20 \
        -folder vibrant/

----------------------------------------------------------------------
# 合并三个软件的结果文件
cat sullivan_SOP/vs2-pass2/vs2.fa deepvirfinder/dvf_sequences.fa vibrant/VIBRANT_5kb/VIBRANT_phages_5kb/5kb.phages_combined.fna > raw_viral_contigs.fa
# 用 seqkit 分别对序列名称和序列去重
#seqkit rmdup -n raw_viral_contigs.fa -o dup_name_contigs.fa
#seqkit rmdup -s dup_name_contigs.fa -o dup_contigs.fa

#seqkit stat dup_contigs.fa                           
#file            format  type  num_seqs     sum_len  min_len   avg_len  max_len
#dup_contigs.fa  FASTA   DNA      2,871  37,454,499    4,400  13,045.8  517,266


----------------------------------------------------------------------
# cd-hit
time cd-hit-est -i raw_viral_contigs.fa \
        -o cd_hit_virus.fa \
        -aS 0.85 -c 0.95 -T 0 -M 0

#得到的病毒 contigs 信息如下：
#seqkit stat cd_hit_virus.fa
#file             format  type  num_seqs     sum_len  min_len   avg_len  max_len
#cd_hit_virus.fa  FASTA   DNA      1,779  25,198,931    4,400  14,164.7  517,266
```

## 2.2 病毒序列分析

### 2.2.1 checkv 去宿主

用 checkv 评估病毒序列，首先去掉 provirus的宿主信息，然后使用 COBRA 提高病毒序列置信度，最后再运行 checkv 将 *`Not-determined 的序列删除`*

最后的文件为 `after_checkv_contigs.fa`

``` code code-wrap
conda activate py3
checkv -h #CheckV v1.0.1

checkv contamination \
    cd_hit_virus.fa \
    checkv_contamination \
    -d /home/user/database/virus.db/checkv-db-v1.0 \
    -t 64
# 生成的 virus.fna 就是去宿主之后的
```

### 2.2.2 COBRA 提高病毒序列准确度

上一步的输出在 checkv\_contamination/viruses.fna

``` code code-wrap
conda activate cobra

# 首先确保病毒序列和原来 megahit 得到的序列名字得一致
grep "^>" viruses.fna > contigs1_headers.txt # 病毒序列名字
grep "^>" clean.fasta > clean_headers.txt # 拼接得到的 contigs 名字
comm -23 <(sort contigs1_headers.txt) <(sort clean_headers.txt)
# 然后删掉不匹配的序列 在virus.fna的基础上删除

# 运行 COBRA
# 格式改成 fasta
python /home/user/Tools/cobra/cobra.py -f /home/user/Project2_next_soybean/metagenomic/temp/megahit/clean.fasta \
          -q /home/user/Project2_next_soybean/metagenomic/temp/dna_virus/virus_identification/checkv_contamination/viruses.fasta \
          -o cobra \
          -c /home/user/Project2_next_soybean/metagenomic/temp/megahit/coverage.txt \
          -m /home/user/Project2_next_soybean/metagenomic/temp/megahit/output.sam \
          -a megahit \
          -mink 21 \
          -maxk 141 \
          -t 64

cat *fasta > cobra.fasta

#$ seqkit stat cobra.fasta                        
#file         format  type  num_seqs     sum_len  min_len   avg_len  max_len
#cobra.fasta  FASTA   DNA      1,699  25,706,231    5,000  15,130.2  517,266
```

### 2.2.3 checkv再检查 去除 not-determined

``` code code-wrap
conda activate py3

checkv end_to_end \
    cobra.fasta \
    checkv_cobra \
    -d /home/user/database/virus.db/checkv-db-v1.0 \
    -t 64

# 删除 Not-determined 的序列名
```

### 2.2.1 病毒 bins 分箱

用上面得到的 Checkv\_contigs.fa作为输入，进行病毒 bins 的分箱

``` code code-wrap
conda activate vRhyme

vRhyme -i ../checkv_contigs.fa \
      -r ../../../seq_data/*.fastq \
      -t 64 \
      -o vRhyme/ \
      --method longest

# 合并
for fasta_file in *.fasta; do
    # 获取文件名（不包括扩展名）
    file_prefix=$(basename "$fasta_file" .fasta)

    # 删除所有以>开头的行并合并剩余内容到临时文件
    grep -v '^>' "$fasta_file" | tr -d '\n' > temp.fasta

    # 在第一行添加以文件前缀为标识的新行
    sed -i "1i>$file_prefix" temp.fasta

    # 将处理后的内容保存回原文件
    mv temp.fasta "$fasta_file"
done

# 和原先的合并然后去冗余 
# sed 's/>/\n>/g' seq.fasta > seq1.fasta 添加一行空格 不然无法识别
# 然后用 checkv 进行统计
```

## 2.3 病毒 lifestyle 预测 (PhaTYP \\ **BACPHLIP\\VIBRANT结果**)

**输入 (input)** 的是病毒的 fa 文件 `checkv_contigs.fa`

### 2.3.1 PhaTYP

输入的是 得到的病毒序列 fa 文件

``` code code-wrap
conda activate phasuit

# --rootpth 直接用 pwd 获取当下目录即可
python /home/user/Applications/PhaBOX/PhaTYP_single.py \
    --contigs cobra/modified_cobra.fa \
    --threads 64 --len 3000 \
    --rootpth /home/user/Project2_next_soybean/metagenomic/temp/dna_virus \
    --out lifestyle_PhaTYP \
    --dbdir /home/user/Applications/PhaBOX/database/ \
    --parampth /home/user/Applications/PhaBOX/parameters/

# 筛选 score > 0.5 的，将不达标的保存为 phatyp_unclassified.txt
seqkit grep -f phatyp_unclassified.txt ../checkv_contigs.fa > phatyp_unclassified.fa
```

### 2.3.2 BACPHLP

输入的序列是上面 PhaTYP 没有比对上

``` code code-wrap
cd lifestyle_PhaTYP

conda activate ViWrap

bacphlip -i phatyp_unclassified.fa --multi_fasta

#################################################################################
Beginning BACPHLIP pipeline
Finished six frame translation of all nucleotide records with outputs stored in phatyp_unclassified.fa.BACPHLIP_DIR/
Finished hmmsearch calls and processing for all records
Finished with BACPHLIP predictions! Final output file stored in phatyp_unclassified.fa.bacphlip
#################################################################################
```

然后合并两个结果文件，就是最终的 lifestyle\_prediction。

## 2.4 vOTUs 丰度 (coverm)

### 2.4.1 比对宏基因组序列获得丰度 rpkm

输入的是病毒序列文件，这里是 checkv\_contigs.fa

### 2.4.2 比对宏转录组数据获得活性 vOTUs 丰度 tpm

``` code code-wrap
mkdir coverm_votus_abu_metatranscriptome

conda activate METABOLIC_v4.0

for sample in CK1 CK2 CK3 Low1 Low2 Low3 High1 High2 High3; do       
  coverm contig -r checkv_contigs.fa -t 64 -m tpm --min-read-percent-identity 95 --min-read-aligned-percent 90 \
        --coupled ../../../metatranscriptome/data/"$sample"_R1.fq.gz ../../../metatranscriptome/data/"$sample"_R2.fq.gz \
        -o coverm_votus_abu_metatranscriptome/"$sample"_output.tsv
done
```

## 2.5 基因注释 (prodigal)

``` code code-wrap
mkdir prodigal

prodigal -p meta \
         -a out.faa \
         -d out.fna \
         -o out.gff -f gff -q -m -c \
         -i ../checkv_contigs.fa

# 输出文件 out.fna
# 看看多少
#file     format  type  num_seqs     sum_len  min_len  avg_len  max_len
#out.fna  FASTA   DNA     24,082  14,617,518       90      607   29,652

# 蛋白序列文件
seqkit translate --trim out.fna > protein.fa
```

## 2.6 物种注释

### 2.6.1 Diamond + MEGAN (结果不理想——弃用）

``` code code-wrap
mkdir taxonomy

time diamond blastp --threads 64 \
    -d /home/user/Project2/diamond/nr.dmnd \  # NCBI nr 的 diamond 索引文件
    -q ../prodigal/protein.fa \  # 注意 输入的蛋白序列文件
    -o Unigenes_vs_nr_blt.txt \ 
    --max-target-seqs 5 \
    --evalue 0.0001 \
    --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore

# MEGAN
/home/user/megan/tools/blast2lca \
    -i Unigenes_vs_nr_blt.txt \
    -f BlastTab -ms 50 -me 0.00001 \
    -a2t /home/user/megan_db/prot_acc2tax-Jul2019X1.abin \
    -o nr_blast_out.m8.tax.tsv
```

### 2.6.2 PhaGCN

``` code code-wrap
conda activate phasuit

mkdir phagcn

python /home/user/Applications/PhaBOX/PhaGCN_single.py \
        --contigs ../checkv_contigs.fa \
        --threads 64 --len 4000 \
        --rootpth phagcn/ \
        --out output \
        --dbdir /home/user/Applications/PhaBOX/database/ \
        --parampth /home/user/Applications/PhaBOX/parameters/
```

将注释为 Unknown 的 vOTU 提取出来，然后用 seqkit 将序列提取出来：

``` code code-wrap
seqkit grep -f unknown_data.txt ../checkv_contigs.fa > phagcn_unclassified.fa
```

### 2.6.3 geNomad

``` code code-wrap
conda activate genomad

mkdir genomad

genomad annotate --cleanup ../checkv_contigs.fa genomad /home/user/database/virus.db/genomad_db/genomad_db_v1.3
# or
genomad end-to-end --cleanup --splits 8 ../checkv_contigs.fa genomad /home/user/database/virus.db/genomad_db/genomad_db_v1.3
```

### 2.6.4 vConTACT2

这里，我们用了四个数据库：包括 Santos soil, stordalen soil, 去年的病毒序列以及 RefSeq

``` code code-wrap
# 将上述的三个fa 文件转为蛋白序列（除 RefSeq 外） 先用 prodigal
cat ../../checkv_contigs.fa soybean1.fa > input.fa

mkdir prodigal

prodigal -a prodigal/out.faa \
         -d prodigal/out.fna \
         -f gff \
         -g 11 \
         -o prodigal/out.gff \
         -s prodigal/out.stat \
         -i input/input.fa \
         -q

# 开始分析 #
conda activate vContact2

# 生成映射文件
vcontact2_gene2genome \
    --proteins prodigal/out.faa \
    --output out_map.csv \
    --source-type Prodigal-FAA

# 运行 vConTACT2
## 节点数不能设置高，就 32 可以了！
vcontact2 \
    --rel-mode 'Diamond' \
    --pcs-mode MCL \
    --vcs-mode ClusterONE \
    --c1-bin /home/user/anaconda3/bin/cluster_one-1.0.jar \
    --db 'ProkaryoticViralRefSeq85-Merged' \
    --verbose --threads 32 \
    --raw-proteins prodigal/out.faa \
    --proteins-fp out_map.csv \
    --output-dir output


#####################
.
├── input
├── out_map.csv
├── output
└── prodigal
```

# ③ Bin【每个样品分开来 bin】

### 3.1 metawrap 运行 bin

``` code code-wrap
/home/user/Project2_next_soybean/metagenomic/temp

source activate metawrap
####################################
###########     bin     ############
####################################
metawrap binning \
    -o binning \
    -t 64 \
    --run-checkm \
    -a ../megahit/contigs.1000kb.fa \
    --metabat2 --maxbin2 --concoct \
    ../../seq_data/*.fastq

#####################################
####  bin_refinement 【以 CK1 为例】###
#####################################
cd /home/user/Project2_next_soybean/metagenomic/temp/binning/CK1_bin

metawrap bin_refinement \
    -o bin_refinement \
    -t 96 \
    -A metabat2_bins/ \
    -B maxbin2_bins/ \
    -C concoct_bins/ \
    -c 70 -x 5
# 看有多少优秀的 bin
cat CK1_bin/bin_refinement/metawrap_70_5_bins.stats | awk '$2>70 && $3<5' | wc -l

#####################################
#### re_assemble 【以 CK1 为例】######
#####################################
metawrap reassemble_bins \
    -o re_assemble \
    -1 ../../../seq_data/CK1_clean_1.fastq \
    -2 ../../../seq_data/CK1_clean_2.fastq \
    -t 96 -m 800 -c 70 -x 5 \
    -b bin_refinement/metawrap_70_5_bins
# 提纯后的 bin，在 bin_refinement/metawrap_70_5_bins 目录下

# 根据处理名字，重命名 bin 比如在 CK1
for file in bin.*.fa; do mv "$file" "${file/bin./CK1_bin.}"; done

# 将所有提纯后的 bin 拿出来放到一起
for dir in CK1_bin CK2_bin CK3_bin CK4_bin CK5_bin CK6_bin High1_bin High2_bin High3_bin High4_bin High5_bin High6_bin Low1_bin Low2_bin Low3_bin Low4_bin Low5_bin Low6_bin; do
    if [ -d "$dir/bin_refinement/metawrap_70_5_bins" ]; then
        cp "$dir/bin_refinement/metawrap_70_5_bins/"*.fa /home/user/Project2_next_soybean/metagenomic/temp/binning_analysis/seq_bin/
    fi
done
# 一共获得 154 个 Bin

--------------------------------------------------------------------------------------------------------
# dRep 去重
conda activate checkm

dRep dereplicate dRep/ -g seq_bin/*.fa -pa 0.95 -sa 0.99 -p 64 -comp 50 -con 10

# Checkm2 评估基因组信息
conda activate checkm2

checkm2 predict --threads 64 --input dRep/dereplicated_genomes_1/*.fa --output-directory checkm2_output
```

### 3.2 bin 定量 rpkm

``` code code-wrap
conda activate metawrap

mkdir bin_abu
metawrap quant_bins -b dRep/dereplicated_genomes_1/ -t 64 \
      -o bin_abu -a ../megahit/final.contigs.fa ../../seq_data/*.fastq
# 注意：这里的final.contigs.fa 是原先每个 sample 的final.contigs.fa 合并而来的


# coverm
conda activate METABOLIC_v4.0
for sample in CK1 CK2 CK3 CK4 CK5 CK6 Low1 Low2 Low3 Low4 Low5 Low6 High1 High2 High3 High4 High5 High6; do
  coverm genome -d dRep/dereplicated_genomes_1 -x fa -t 64 -m rpkm --min-read-percent-identity 95 --min-read-aligned-percent 90 \
        --coupled ../../seq_data/"$sample"_clean_1.fastq ../../seq_data/"$sample"_clean_2.fastq \
        -o coverm_bin_abu/"$sample"_output.tsv
done
```

### 3.3 bin 丰度比对到宏转录组数据 tpm

``` code code-wrap
mkdir coverm_mag_abu_metatranscriptome

conda activate METABOLIC_v4.0

for sample in CK1 CK2 CK3 Low1 Low2 Low3 High1 High2 High3; do       
  coverm genome -d dRep/dereplicated_genomes_1 -x fa -t 64 -m tpm --min-read-percent-identity 95 --min-read-aligned-percent 90 \
        --coupled ../../../metatranscriptome/data/"$sample"_R1.fq.gz ../../../metatranscriptome/data/"$sample"_R2.fq.gz \
        -o coverm_mag_abu_metatranscriptome/"$sample"_output.tsv
done
```

### 3.4 物种注释

``` code code-wrap
conda activate gtdbtk

gtdbtk classify_wf \
    --genome_dir dRep/dereplicated_genomes1 \
    --out_dir gtdb_classify \
    --extension fa \
    --prefix tax \
    --cpus 64

# 对其结果建树
gtdbtk infer \
    --msa_file gtdb_classify/align/tax.bac120.user_msa.fasta \
    --out_dir gtdb_infer \
    --prefix tax \
    --cpus 64
```

## 3.5 功能注释

``` code code-wrap
# 基因预测
for fa_file in /home/user/Project2_next_soybean/metagenomic/temp/binning_analysis/dRep/dereplicated_genomes_1/*.fa; do
    base_name=$(basename "$fa_file" .fa)
    prodigal -i "$fa_file" \
             -d /home/user/Project2_next_soybean/metagenomic/temp/binning_analysis/prodigal/"$base_name".gene.fa \
             -o /home/user/Project2_next_soybean/metagenomic/temp/binning_analysis/prodigal/"$base_name".gene.gff \
             -p meta -f gff
done

# 翻译成蛋白序列
for gene_file in *.gene.fa; do
    output_file="prot_${gene_file}"
    seqkit translate --trim "$gene_file" > "$output_file"
done


# KOFAM 注释
mkdir KofamKOALA && cd KofamKOALA

conda activate kofam

# 每一个 bin 分开运行
## 输入的是蛋白序列，在 ../../prodigal 下，以 prot 开头 .

input_dir="../../prodigal"

for file in "$input_dir"/prot_*.gene.fa; do
    # 获取文件名（包括扩展名）
    filename=$(basename "$file")
    
    # 删除扩展名，得到目录名
    folder_name="${filename%.gene.fa}"
    
    # 定义输出文件名（不包含路径和扩展名）
    output_filename="${folder_name}.txt"
        
        # Execute the exec_annotation command
    exec_annotation \
        -f detail-tsv \
        -o "$output_filename" \
        "$input_dir/$folder_name.gene.fa" \
        -p "/home/user/db/kofamscan/db/profiles/" \
        -k "/home/user/db/kofamscan/db/ko_list" \
        -e 1e-5 \
        --cpu 64
done

# 获得 符合条件的行
for file in *.txt; do
  base_name="${file%.*}"  # 获取文件名去掉扩展名
  new_file="${base_name}_final.txt"  # 构建新文件名
  grep "^\*" "$file" > "$new_file"  # 运行 grep 并将结果保存到新文件
done
```

# ④ 病毒-宿主互作

``` code code-wrap
├── crispr
│   ├── crispr_result.txt
│   ├── out.fa
│   └── out.txt
├── homology_match
│   └── ublast.viral.txt
├── host_database.udb
├── host_MAGs_seq.fa
├── iphop
│   ├── bac_MAGs_seq
│   ├── iphop_output
│   ├── iphop.sh
│   ├── MAGs_GTDB-tk_results
│   └── Sept_2021_pub_rw_w_soybean_hosts_iphop_1.3.2
├── tRNA
│   ├── rRNA.ss
│   ├── tRNA.fa
│   ├── tRNA.out
│   ├── tRNA_similarity_blast.txt
│   ├── tRNA_similarity.txt
│   └── tRNA.stats
├── usearch
└── vOTU_database.udb
```

## 4.1 iPHop (by Simon Roux)

``` code code-wrap
mkdir iphop

注意 MAGs 的命名，是： >CK1_307978 这种，不要有其他多余的部分

###############################################
####     将 MAGs 加入到 host database 中    #### 
###############################################

conda activate gtdbtk # 用 gtdbtk 2.1.0

# MAGs 包含了细菌和古菌
### 注意，cpus 不要设置满，不然会显示内存不足（pbs 提交任务的情况下）
# 细菌
gtdbtk de_novo_wf --genome_dir bac_MAGs_seq/ \
                  --bacteria \
                  --outgroup_taxon p__Patescibacteria \
                  --out_dir MAGs_GTDB-tk_results/ \
                  --cpus 32 \
                  --force \
                  --extension fa

# 古菌
gtdbtk de_novo_wf --genome_dir bac_MAGs_seq/ \
                  --archaea \
                  --outgroup_taxon p__Altarchaeota \
                  --out_dir MAGs_GTDB-tk_results/ \
                  --cpus 32 \
                  --force \
                  --extension fa

conda activate iphop_env

# 将基因组添加到 iphop 数据库
iphop add_to_db \
    --fna_dir bac_MAGs_seq/ \
    -t 64 \
    --gtdb_dir MAGs_GTDB-tk_results/ \
    --out_dir Sept_2021_pub_rw_w_soybean_hosts_iphop_1.3.2 \
    --db_dir /home/user/database/virus.db/iphop_db/Sept_2021_pub_rw/

# 运行 iphop 预测
iphop predict --fa_file ../checkv_contigs.fa \
              --db_dir Sept_2021_pub_rw_w_soybean_hosts_iphop_1.3.2 \
              --out_dir iphop_output \
              -t 64

# 然后手动整理结果

##################################################
.
├── bac_MAGs_seq
├── iphop_output
├── iphop.sh
├── MAGs_GTDB-tk_results
├── Sept_2021_pub_rw_w_soybean_hosts_iphop_1.3.2
└── Sept_2021_pub_rw_w_Wetland_hosts
```

## 4.2 tRNA

病毒中的 tRNA ⇒ MAGs

分析思路是：使用 `tRNAscan-SE` 找到 vOTUs 中的 tRNA，然后使用 blastn v2.5.0 针对 host database 查询获得的 tRNA

> 由于最后要溯源到 MAGs，所以可以提前在每一个 MAGs 的 contigs 前面加上 MAGs 的名字：

for file in \*.fa; do  
prefix=$(echo "$file" | sed 's/\\.fa//; s/\\./\_/g')  
sed -i "s/^\>/\>${prefix}|/" "$file"  
done

``` code code-wrap
tRNAscan-SE -B \
    -o tRNA.out \
    -f rRNA.ss \
    -m tRNA.stats \
    -a tRNA.fa \
    ../../checkv_contigs.fa
# 删掉多余信息
# awk '/^>/ { sub(/\.[^.]+$/, "", $0); print; next } { print }' tRNA.fa > tRNA1.fa

# 合并所有的 MAGs 文件
cat iphop/bac_MAGs_seq/*.fa > host_MAGs_seq.fa

# 构造 MAGs 索引
./usearch -makeudb_ublast host_MAGs_seq.fa -output host_database.udb &> usearch_database.log

# 100% identity and 100% coverage
./usearch -ublast tRNA/tRNA.fa -db host_database.udb -strand plus -id 1.0 -query_cov 1.0 -evalue 1e-5 -blast6out tRNA/tRNA_similarity_blast.txt -threads 64 &> ublast.log

# 根据第二列去重复
sort -u -k2,2 tRNA/tRNA_similarity_blast.txt > tRNA/tRNA_similarity.txt
```

## 4.3 CRISPR

MAGs 中的 CRISPR ⇒ vOTUs

分析思路：将 host database 里的 CRISPR序列比对回 vOTUs

``` code code-wrap
mkdir crispr

pilercr -in host_MAGs_seq.fa \
        -out crispr/out.txt \
        -seq crispr/out.fa -quiet

# 构造 vOTUs 索引
./usearch -makeudb_ublast ../checkv_contigs.fa -output vOTU_database.udb &> usearch_database.log

# word size=16, coverage=100, mismatch ≤ 3, e-value ≤ 10−5 #
./usearch -ublast crispr/out.fa \
          -db vOTU_database.udb \
          -strand plus -evalue 1e-5 \
          -blast6out crispr/crispr_result.txt \
          -threads 64

sort -u -k2,2 crispr/crispr_result.txt > crispr/final_crispr_result.txt
```

## 4.4 Homology match

将 vOTUs 比对到 host database 上（用 blastn ⇒ 核酸-核酸）

``` code code-wrap
mkdir homology_match

./usearch -ublast ../checkv_contigs.fa \
    -db host_database.udb \
    -strand plus -id 0.7 -evalue 1e-3 -query_cov 0.75 \
    -blast6out homology_match/ublast.viral.txt \
    -threads 64

sort -u -k2,2 homology_match/ublast.viral.txt > homology_match/homology_match.txt
```

-----

# ⑤ 病原菌分析

  - 得到病原菌序列文件：`seqkit grep -f <(cut -f1 pathogen_contigs_name.txt) -i ../megahit/5kb.fa > pathogen_seq.fa`

s

-----

# ⑥ 细菌基因组大小分析

根据先前研究的方法，**GC 是对全部的 contigs 进行分析的，而其余三个是对 \> 500bp 的 contigs 进行分析的**。首先，我们是每个样品分开megahit的，所以，第一步是先批量运行，得到 \>500bp 的 contigs 文件。

``` code code-wrap
# 筛选得到 > 500bp 的 contigs
for folder in *; do
    if [ -d "$folder" ]; then
        cd "$folder" || continue

        for file in final.contigs.fa; do
            seqkit seq -m 500 "$file" > contigs_500bp.fa
        done

        cd ..
    fi
done
```

### 6.1 **MicrobeCensus (v1.1.0) 评估 average genome size (AGS)**

这个 tool 放在` /home/user/Tools/MicrobeCensus-1.1.1`

``` code code-wrap
conda activate py2_new

for category in CK{1..6} Low{1..6} High{1..6}; do
    input_file="/home/user/Project2_next_soybean/metagenomic/temp/megahit/${category}/contigs_500bp.fa"

    run_microbe_census.py -n 100000000 \
        -t 60 \
        -l 500 \
        "${input_file}" \
        "/home/user/Project2_next_soybean/metagenomic/temp/genomic_size/micro_census/${category}.txt"
done
```

### 6.2 平均 16S rRNA 基因拷贝数 average 16S rRNA gene copy number

``` code code-wrap
conda activate METABOLIC_v4.0

# 进入到 R 中
library(RasperGade16S)
pred.GCN = predict_16SGCN_from_sequences(seqs="/home/user/Project2_next_soybean/metagenomic/temp/megahit/CK1/contigs_500bp.fa")
```

### 6.3 GC 含量(Quast v4.5)

``` code code-wrap
conda activate py2

for category in CK{1..6} Low{1..6} High{1..6}; do
    input_file="/home/user/Project2_next_soybean/metagenomic/temp/megahit/${category}/final.contigs.fa"
    python /home/user/software_documents/quast/quast.py \
        -t 60 \
        -o GC/${category} \
        "${input_file}"
done
```

### 6.4 gRodon 评估 Minimal doubling time MDT

  - 首先，用 Prodigal 获得 faa 文件：

<!-- end list -->

``` code code-wrap
# 第一步，运行prokka
conda activate prokka

prokka ../../megahit/CK1/contigs_500bp.fa --outdir CK1 --prefix CK1 --cpus 64 --fast --metagenome --kingdom Bacteria --quiet

# 第二步 获取 CDS 的 ID
sed -n '/##FASTA/q;p' CK1/out.gff | awk '$3=="CDS" {gsub("ID=", "_", $9); print $1 "_" $9}' | awk -F'[_;]' '{print $1 $2 "_" $3}' > CK1/CDS_names.txt

# 第三步 R 中运行
library(gRodon)
library(Biostrings)

genes <- readDNAStringSet("/home/user/Project2_next_soybean/metagenomic/temp/genomic_size/gRodon/CK1/out.ffn.gz")
CDS_IDs <- readLines("CK1/CDS_names.txt")
gene_IDs <- gsub(" .*","",names(genes))
genes <- genes[gene_IDs %in% CDS_IDs]
highly_expressed <- grepl("ribosomal protein",names(genes),ignore.case = T)
predictGrowth(genes, highly_expressed, mode = "metagenome_v1")
```

# ⑦ 物种组成

## 7.1 contigs 水平 (FASTQ水平也适用) ⇒ 基于 Kaiju

``` code code-wrap
for category in CK{1..6} Low{1..6} High{1..6}; do
    input_file="/home/user/Project2_next_soybean/metagenomic/temp/megahit/${category}/final.contigs.fa"
    
    kaiju -z 64 \
      -t /home/user/software_documents/kaiju/kaijudb/nodes.dmp \
      -f /home/user/software_documents/kaiju/kaijudb/kaiju_db_refseq.fmi \
      -i "${input_file}" \
      -o /home/user/Project2_next_soybean/metagenomic/temp/taxonomy/contig/${category}.out

    kaiju2table \
      -t /home/user/software_documents/kaiju/kaijudb/nodes.dmp \
      -n /home/user/software_documents/kaiju/kaijudb/names.dmp -u \
      -o /home/user/Project2_next_soybean/metagenomic/temp/taxonomy/contig/${category}.family.txt \
      -r family /home/user/Project2_next_soybean/metagenomic/temp/taxonomy/contig/${category}.out
done


## 如果需要其他水平的，直接运行 kaiju2table就可以了

for category in CK{1..6} Low{1..6} High{1..6}; do
    input_file="/home/user/Project2_next_soybean/metagenomic/temp/megahit/${category}/final.contigs.fa"

    kaiju2table \
      -t /home/user/software_documents/kaiju/kaijudb/nodes.dmp \
      -n /home/user/software_documents/kaiju/kaijudb/names.dmp -u \
      -o /home/user/Project2_next_soybean/metagenomic/temp/taxonomy/contig/${category}.family.txt \
      -r family /home/user/Project2_next_soybean/metagenomic/temp/taxonomy/contig/${category}.out
done
```

## 7.2 MAGs 水平

MAGs 物种注释结果+ MAGs 的丰度

## 7.3 mRNA 水平

``` code code-wrap
## 1. Prodigal 对转录组数据进行功能预测

cat split.list | \
    xargs -I{} -P10 \
    sh -c \
    'prodigal -i contigs.fa.split/contigs.part_{}.fa \
    -d temp/gene{}.fa \
    -o temp/gene{}.gff \
    -p meta -f gff > temp/gene{}.log 2>&1'

# 合并基因序列
cat temp/gene*.fa > gene.fa
# cat temp/gene*.gff > gene.gff

seqkit translate --trim gene.fa > protein.fa

## 2. DIAMOND 比对 NCBI nr 数据库
# nr 数据库 makedb 在 /home/user/Project2/diamond/nr.dmnd
time diamond blastp --threads 64 \
             -d /home/user/Project2/diamond/nr.dmnd \
             -q prodigal/protein.fa \
             -o taxonomy/Unigenes_vs_nr_blt.txt \
             --max-target-seqs 5 \
             --evalue 0.00001 \
             --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore

## 3. MEGAN 分析物种组成
/home/user/megan/tools/blast2lca -i Unigenes_vs_nr_blt.txt -f BlastTab -ms 50 \
    -me 0.000001 -a2t /home/user/megan_db/prot_acc2tax-Jul2019X1.abin \
    -o nr_blast_out.m8.tax.tsv

## 4. 建索引定量 gene 丰度 salmon 0.7
salmon index -t gene.fa -p 28 -k 31 -i salmon/index --type quasi

cat split.list | \
    xargs -I{} -P3 \
    sh -c \
    'salmon quant \
    -i salmon/index -l A -p 64 --meta \
    -1 /home/user/Project2_next_soybean/metatranscriptome/data/{}_R1.fq.gz \
    -2 /home/user/Project2_next_soybean/metatranscriptome/data/{}_R2.fq.gz \
    -o salmon/{}.quant'

## 5. 合并
salmon quantmerge \
        --quants salmon/*.quant \
        -o salmon/gene.TPM

salmon quantmerge \
        --quants salmon/*.quant \
        --column NumReads -o salmon/gene.count
```

# ⑧ 宏转录组数据 map 到 AMG.fa中

``` code code-wrap
for name in CK{1..3} Low{1..3} High{1..3}; do
/home/user/bbtools/bbmap/bbmap.sh \
    ref=amg.fa \
    in=/home/user/Project2_next_soybean/metagenomic/seq_data/${name}_clean_1.fastq \
    in2=/home/user/Project2_next_soybean/metagenomic/seq_data/${name}_clean_2.fastq \
    out=${name}.sam \
    minid=1.0 \
    threads=64
done

# ref=gene.fa 指定了参考序列文件
# in=sample_R1.fastq 和 in2=sample_R2.fastq 指定了输入的测序数据
# out=mapped.sam 指定了输出文件，其中包含了比对结果
# minid=1.0 设置了最小身份百分比为 100%，即要求完全一致性
# mincov=100 设置了最小覆盖度为 100%，即要求整个参考序列都被覆盖

samtools view -bS mapped.sam > mapped.bam       # SAM 转换为 BAM
samtools sort mapped.bam -o mapped.sorted.bam    # 对 BAM 文件进行排序
samtools index mapped.sorted.bam  

coverm contig -m count -b ${path}*.bam > ${path}votu.count.tsv
coverm contig -m count --min-covered-fraction 0.75 -b ${path}*.bam > ${path}votu75.count.tsv
```

# ⑨ AMG 丰度 分析

整体思路为：获得 AMG 的序列信息，然后将宏基因组数据 mapping 到 AMG 的信息上

``` code code-wrap
# 首先处理 vibrant 的结果文件，将序列名后的位置信息移除
sed 's/ #.*//' amg.fa > amg1.fa

seqkit grep -f amg.name.txt amg1.fa -o result.fa
```

![](%E5%A4%A7%E8%B1%86%E6%A0%B9%E9%99%85%E6%A0%B7%E5%93%81%E5%88%86%E6%9E%90%EF%BC%882023%207%2020-%EF%BC%89/Untitled%202.png)

``` code code-wrap
# 合并 coverm 
#!/bin/bash

# 获取第一个TSV文件作为初始的基础文件
base_file=$(ls *.tsv | head -n 1)

# 临时文件，用于存储中间合并结果
temp_file="temp_merge_result.tsv"

# 将基础文件复制到临时文件中，初始化合并结果
cp "$base_file" "$temp_file"

# 遍历所有TSV文件
for file in *.tsv; do
    # 跳过基础文件，避免与自身合并
    if [[ "$file" == "$base_file" ]]; then
        continue
    fi

    # 使用join命令合并当前文件与临时合并结果文件
    # 注意: 输出被重定向到一个新的临时文件，然后这个新的临时文件会被重命名为原来的临时文件
    join -t $'\t' -1 1 -2 1 "$temp_file" "$file" > "${temp_file}_new"
    mv "${temp_file}_new" "$temp_file"
done

# 将最终的合并结果重命名
final_result="final_merged.tsv"
mv "$temp_file" "$final_result"
echo "合并完成，结果保存在：$final_result"
```

</div>

<span class="sans" style="font-size:14px;padding-top:2em"></span>
