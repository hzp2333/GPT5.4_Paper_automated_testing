# 当前论文分析过程文档

## 1. 本次分析的目标

本次更新的目标有四项：

1. 将论文主样本统一切换到“市级地区-行业-年份”口径。
2. 使用用户新提供的数据文件重新完成描述统计、图形和回归分析。
3. 在进入退出分析基础上，新增城市产业集中度 HHI 指标并纳入论文分析。
4. 使用新增的企业生存时间数据做扩展分析，并补充具有解释力的创新图像。

## 2. 使用的数据文件

本次工作区内实际使用了以下数据文件：

- `data/企业进入退出中级市级地区-行业-年份.dta`
  作为主分析样本。
- `data/企业进入退出中级省级.dta`
  作为省级补充样本，用于输出补充性汇总表，不进入正文主回归。
- `data/企业进入退出中级市级地区-年份.dta`
  仅作对照检查，当前正文主线不再使用该文件。
- `data/测试企业生存年份.dta`
  作为扩展分析样本，用于企业生存时间分析。

## 3. 主样本的筛选规则

主样本使用如下限定条件：

- `统计口径 == "地区-行业-年份"`
- `地区层级 == "市级"`
- `year >= 2000`
- `firm_total >= 5`

其中最后一条是本次新增的硬性规则，用于保证每个地区-行业-年份单元至少有 5 条企业记录，避免极小样本单元导致进入率、退出率和净进入率机械性接近 0 或 1。

筛选后主样本规模为：

- 地区-行业-年份观测数：492,612
- 城市数：342
- 行业数：436
- 城市-行业面板单元数：71,476

## 4. 核心指标的构造

主样本直接使用数据文件中已给出的以下变量：

- `entry_count`
- `exit_count`
- `firm_total`
- `entry_rate`
- `exit_rate`
- `net_rate`

同时新增：

- `ln_firm_total = ln(firm_total)`

用于刻画行业单元规模。

## 5. HHI 指标的计算方法

HHI 在城市-年份层面计算，再并回主样本。步骤如下：

1. 在同一城市同一年内部，对所有满足 `firm_total >= 5` 的行业单元求和得到城市年度总企业数 `city_total`。
2. 计算行业份额：
   `industry_share = firm_total / city_total`
3. 计算份额平方：
   `share_sq = industry_share^2`
4. 对同一城市同一年内全部行业份额平方求和：
   `hhi = sum(share_sq)`

解释上：

- HHI 越高，说明城市企业更集中于少数行业。
- HHI 越低，说明城市行业结构更分散、更多元。

本次结果中：

- 面板单元层面的 HHI 均值约为 0.029
- 按城市-年份去重后的 HHI 均值约为 0.145

## 6. 图表和回归的组织逻辑

### 描述统计

输出文件：

- `output/tables/table1_descriptive_stats.tex`

包含以下变量：

- `firm_total`
- `entry_count`
- `exit_count`
- `entry_rate`
- `exit_rate`
- `net_rate`
- `hhi`
- `ln_firm_total`

### 总体和区域趋势图

输出文件：

- `output/figures/figure1_national_index_trend.png`
- `output/figures/figure2_region_comparison.png`

逻辑说明：

- 图 1 按全国加总企业数重新计算年度进入率、退出率、净进入率。
- 图 2 按四大区域加总企业数后计算区域净进入率。

### 城市聚合图

为展示城市层面的结果，先将主样本按“省份-城市-年份”聚合，生成：

- `entry_rate`
- `exit_rate`
- `net_rate`
- `industry_cells`
- `hhi`

其中 `industry_cells` 表示该城市该年满足筛选条件的有效行业单元数。

输出文件：

- `output/city_year_aggregated_from_industry_main.dta`

在城市排名图中，额外要求：

- `industry_cells >= 5`
- `firm_total > 50`

这一约束只用于城市排序图，不改变主样本回归口径。目的在于避免个别年份、个别城市只依赖极少行业单元或极小聚合企业规模而出现不稳定排名。

对应输出：

- `output/figures/figure3_entry_exit_scatter.png`
- `output/figures/figure4_rank_improvers.png`
- `output/figures/figure6_topcity_rank_paths.png`
- `output/figures/figure7_index_distribution_box.png`

注意：

- 原先“净进入率前20城市”图在结果上出现明显极端值，不利于稳健解释，因此已从正文分析中删除。
- 原先“排名跃升前15城市”的逻辑在新共同样本下不稳定，因此改成了“2000--2023 年净进入率排名变动最大的15城市”。

### HHI 图

输出文件：

- `output/figures/figure5_hhi_trend.png`

逻辑说明：

- 对城市-年份层面的 HHI 求年度平均，展示城市产业集中度的长期变化。

### 行业图

输出文件：

- `output/figures/figure8_industry_net_rate.png`
- `output/figures/figure9_industry_entry_trends.png`
- `output/figures/figure10_industry_exit_trends.png`

逻辑说明：

- 图 8 展示样本规模最大的 15 个行业的平均净进入率。
- 图 9 和图 10 选取样本规模最大的 4 个行业，展示其进入率和退出率趋势。

### 企业生存时间扩展图

扩展数据文件：

- `data/测试企业生存年份.dta`

该数据当前包含三列：

- `行业门类`
- `成立年份`
- `age`

其中 `age` 表示对应行业门类、成立年份企业的平均生存时间。

输出文件：

- `output/figures/figure11_survival_cohort_trend.png`
- `output/figures/figure12_survival_premium.png`
- `output/figures/figure13_survival_netrate_scatter.png`
- `output/tables/survival_year_summary.csv`
- `output/tables/survival_industry_premium.csv`
- `output/tables/survival_netrate_link.csv`

逻辑说明：

- 图 11 仅保留 2015--2020 年成立 cohort，并统一以 2015 年平均生存时间为基期标准化为 100；同时绘制 1\%--99\% 区间带，用于展示不同 cohort 生存时间分布的相对变化。
- 图 12 构造“行业生存时间溢价”，即某行业相对同成立年份平均生存时间的偏离。
- 图 13 将行业平均生存时间与主样本行业大类的平均净进入率联动起来，观察“高净进入”与“长生存”是否一致。

## 7. 回归设定

### 基准回归

输出文件：

- `output/tables/table2_baseline_regs.tex`

模型设定：

- 面板维度：城市-行业
- 固定效应：城市-行业固定效应
- 年份固定效应：主规格纳入
- 聚类层级：城市

主要变量：

- 被解释变量：`net_rate`、`entry_rate`、`exit_rate`
- 解释变量：`L1_ln_firm_total`
- 控制变量：对应指标的一期滞后项、`L1_hhi`

### 异质性回归

输出文件：

- `output/tables/table3_heterogeneity.tex`

异质性维度：

- 东部城市
- 省会城市
- 副省级城市

做法：

- 将 `L1_ln_firm_total` 分别与上述城市类型虚拟变量交互。

## 8. 代码文件和输出文件

本次主要修改文件如下：

- `code/00_master.do`
- `code/01_analysis.do`
- `paper/main.tex`
- `paper/analysis_process.md`

本次新增或重写的重要输出文件包括：

- `output/city_industry_year_panel_main.dta`
- `output/city_year_hhi_panel.dta`
- `output/city_year_aggregated_from_industry_main.dta`
- `output/tables/table1_descriptive_stats.tex`
- `output/tables/table2_baseline_regs.tex`
- `output/tables/table3_heterogeneity.tex`
- `output/tables/paper_stats.tex`
- `output/tables/city_rank_change_2000_2023.csv`
- `output/tables/industry_summary_2000_2023.csv`
- `output/tables/province_summary_2000_2023.csv`
- `output/tables/survival_year_summary.csv`
- `output/tables/survival_industry_premium.csv`
- `output/tables/survival_netrate_link.csv`
- `output/figures/figure1_national_index_trend.png`
- `output/figures/figure2_region_comparison.png`
- `output/figures/figure3_entry_exit_scatter.png`
- `output/figures/figure4_rank_improvers.png`
- `output/figures/figure5_hhi_trend.png`
- `output/figures/figure6_topcity_rank_paths.png`
- `output/figures/figure7_index_distribution_box.png`
- `output/figures/figure8_industry_net_rate.png`
- `output/figures/figure9_industry_entry_trends.png`
- `output/figures/figure10_industry_exit_trends.png`
- `output/figures/figure11_survival_cohort_trend.png`
- `output/figures/figure12_survival_premium.png`
- `output/figures/figure13_survival_netrate_scatter.png`

## 9. 当前版本的关键结论

基于当前新数据与筛选规则，论文主结论可以概括为：

- 主样本行业单元平均进入率约为 0.674，平均退出率约为 0.326，平均净进入率约为 0.347。
- 城市产业集中度 HHI 的城市-年份平均值约为 0.145，长期呈下降趋势，说明城市产业结构趋于多元化。
- 面板回归显示企业动态存在显著持续性。
- 控制滞后净进入率和 HHI 后，行业单元规模与后续净进入率总体上表现为负相关。
- 东部城市和副省级城市中，这种负相关关系明显减弱。
- 扩展生存时间数据表明，行业之间存在显著生存时间溢价，科学研究和技术服务业、交通运输仓储邮政业、教育业的平均生存时间相对更长，而采矿业偏低。
- 平均生存时间与净进入率之间并不是简单线性对应关系，因此“企业进入活跃”与“企业存续较久”应被视为营商活力的不同侧面。

## 10. 后续可继续扩展的方向

如果后续继续完善论文，建议优先考虑以下方向：

1. 将 HHI 与城市宏观变量或政策变量联结，分析产业多元化的决定因素。
2. 增加省级口径与市级口径的对照表，说明尺度差异。
3. 针对行业结构做更细的稳健性检验，例如只保留高频行业或构造行业大类口径。
4. 如需正式投稿，可进一步整理回归表展示格式，并补充标准误、固定效应说明和识别限制讨论。
