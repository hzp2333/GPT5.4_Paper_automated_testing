version 15.1
clear all
set more off

global ROOT "f:/桌面/工商注册数据企业进入退出"
global DATA "$ROOT/工商注册数据1948_2023企业进入退出.dta"
global OUT "$ROOT/output"
global TAB "$OUT/tables"
global FIG "$OUT/figures"
global TEX "$ROOT/paper"

cap mkdir "$OUT"
cap mkdir "$TAB"
cap mkdir "$FIG"
cap mkdir "$TEX"

cap log close _all
log using "$OUT/analysis.log", replace text

cap which esttab
if _rc ssc install estout

*========================
* 一、固定单一统计层次：市级-地区年份
*========================
use "$DATA", clear
keep if 统计口径 == "地区-年份" & 地区层级 == "市级"
keep 省份 城市 成立年份 firm_total entry_count exit_count entry_rate exit_rate net_rate
rename 成立年份 year
keep if year >= 2000

sort 省份 城市 year
duplicates drop 省份 城市 year, force

gen ln_firm_total = ln(firm_total)
egen city_id = group(省份 城市)
xtset city_id year

gen L1_entry_rate = L.entry_rate
gen L1_exit_rate = L.exit_rate
gen L1_net_rate = L.net_rate
gen L1_ln_firm_total = L.ln_firm_total

gen region = ""
replace region = "东部" if inlist(省份, "北京市", "天津市", "河北省", "上海市", "江苏省")
replace region = "东部" if inlist(省份, "浙江省", "福建省", "山东省", "广东省", "海南省")
replace region = "中部" if inlist(省份, "山西省", "安徽省", "江西省", "河南省", "湖北省")
replace region = "中部" if 省份 == "湖南省"
replace region = "西部" if inlist(省份, "内蒙古自治区", "广西壮族自治区", "重庆市", "四川省", "贵州省")
replace region = "西部" if inlist(省份, "云南省", "西藏自治区", "陕西省", "甘肃省", "青海省")
replace region = "西部" if inlist(省份, "宁夏回族自治区", "新疆维吾尔自治区")
replace region = "东北" if inlist(省份, "辽宁省", "吉林省", "黑龙江省")

gen is_subprovincial = 0
replace is_subprovincial = 1 if inlist(城市, "广州市", "深圳市", "成都市", "西安市", "武汉市")
replace is_subprovincial = 1 if inlist(城市, "杭州市", "南京市", "济南市", "青岛市", "大连市")
replace is_subprovincial = 1 if inlist(城市, "宁波市", "厦门市", "哈尔滨市", "长春市", "沈阳市")

gen is_capital = 0
replace is_capital = 1 if inlist(城市, "石家庄市","太原市","呼和浩特市","沈阳市","长春市")
replace is_capital = 1 if inlist(城市, "哈尔滨市","南京市","杭州市","合肥市","福州市")
replace is_capital = 1 if inlist(城市, "南昌市","济南市","郑州市","武汉市","长沙市")
replace is_capital = 1 if inlist(城市, "广州市","南宁市","海口市","成都市","贵阳市")
replace is_capital = 1 if inlist(城市, "昆明市","拉萨市","西安市","兰州市","西宁市")
replace is_capital = 1 if inlist(城市, "银川市","乌鲁木齐市")

gen east = (region == "东部")

label var firm_total "样本企业总数"
label var entry_count "进入企业数"
label var exit_count "退出企业数"
label var entry_rate "进入率"
label var exit_rate "退出率"
label var net_rate "净进入率"
label var ln_firm_total "样本企业总数对数"
label var L1_entry_rate "滞后一期进入率"
label var L1_exit_rate "滞后一期退出率"
label var L1_net_rate "滞后一期净进入率"
label var L1_ln_firm_total "滞后一期样本企业总数对数"
label var is_subprovincial "副省级城市"
label var is_capital "省会城市"

tempfile analysis_panel
save `analysis_panel', replace
save "$OUT/city_year_panel_main.dta", replace

*========================
* 二、描述统计与城市排名
*========================
use `analysis_panel', clear

estpost tabstat firm_total entry_count exit_count entry_rate exit_rate net_rate ln_firm_total, ///
    statistics(count mean sd p25 p50 p75) columns(statistics)
esttab using "$TAB/table1_descriptive_stats.tex", ///
    replace label booktabs nomtitle nonumber noobs ///
    cells("count(fmt(%9.0fc)) mean(fmt(3)) sd(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3))") ///
    title("描述统计：市级地区-年份样本（2000--2023）")

preserve
collapse (mean) entry_rate exit_rate net_rate firm_total, by(region)
export delimited using "$TAB/region_means.csv", replace
restore

preserve
keep if year == 2023
gsort -net_rate
gen rank_2023 = _n
keep if rank_2023 <= 20
keep rank_2023 城市 省份 net_rate entry_rate exit_rate firm_total
export delimited using "$TAB/top20_cities_2023.csv", replace
restore

*========================
* 三、基准回归
*========================
use `analysis_panel', clear
xtset city_id year

eststo clear

xtreg net_rate L1_ln_firm_total, fe vce(cluster city_id)
eststo m1
estadd local city_fe "Yes"
estadd local year_fe "No"

xtreg net_rate L1_entry_rate L1_exit_rate L1_ln_firm_total i.year, fe vce(cluster city_id)
eststo m2
estadd local city_fe "Yes"
estadd local year_fe "Yes"

xtreg entry_rate L1_ln_firm_total i.year, fe vce(cluster city_id)
eststo m3
estadd local city_fe "Yes"
estadd local year_fe "Yes"

xtreg exit_rate L1_ln_firm_total i.year, fe vce(cluster city_id)
eststo m4
estadd local city_fe "Yes"
estadd local year_fe "Yes"

esttab m1 m2 m3 m4 using "$TAB/table2_baseline_regs.tex", ///
    replace label booktabs se star(* 0.10 ** 0.05 *** 0.01) drop(*.year) ///
    stats(city_fe year_fe N r2_within, fmt(%9s %9s %9.0fc 3) ///
    labels("City FE" "Year FE" "Observations" "Within R-squared")) ///
    title("市级地区-年份样本：进入退出指标回归")

*========================
* 四、异质性回归
*========================
use `analysis_panel', clear
xtset city_id year

eststo clear

xtreg net_rate c.L1_ln_firm_total##i.east i.year, fe vce(cluster city_id)
eststo h1
estadd local city_fe "Yes"
estadd local year_fe "Yes"

xtreg net_rate c.L1_entry_rate##i.is_capital L1_ln_firm_total i.year, fe vce(cluster city_id)
eststo h2
estadd local city_fe "Yes"
estadd local year_fe "Yes"

xtreg exit_rate c.L1_exit_rate##i.is_subprovincial L1_ln_firm_total i.year, fe vce(cluster city_id)
eststo h3
estadd local city_fe "Yes"
estadd local year_fe "Yes"

esttab h1 h2 h3 using "$TAB/table3_heterogeneity.tex", ///
    replace label booktabs se star(* 0.10 ** 0.05 *** 0.01) drop(*.year) ///
    stats(city_fe year_fe N r2_within, fmt(%9s %9s %9.0fc 3) ///
    labels("City FE" "Year FE" "Observations" "Within R-squared")) ///
    title("市级地区-年份样本：异质性分析")

*========================
* 五、城市排名与图形
*========================
use `analysis_panel', clear
bys year: egen city_count_year = count(city_id)
bys year: egen rank_net = rank(-net_rate)
gen rank_pct = rank_net / city_count_year

tempfile rank_panel
save `rank_panel', replace

* 图1：全国平均进入率、退出率、净进入率
preserve
collapse (mean) entry_rate exit_rate net_rate, by(year)
twoway ///
    (line entry_rate year, lcolor(navy) lwidth(medthick)) ///
    (line exit_rate year, lcolor(maroon) lpattern(dash) lwidth(medthick)) ///
    (line net_rate year, lcolor(forest_green) lpattern(shortdash_dot) lwidth(medthick)) ///
    , title("全国城市平均进入、退出与净进入率走势") ///
      xtitle("年份") ytitle("比率") ///
      legend(order(1 "进入率" 2 "退出率" 3 "净进入率") rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure1_national_index_trend.png", replace width(2200)
restore

* 图2：区域净进入率比较
preserve
collapse (mean) net_rate, by(region year)
twoway ///
    (line net_rate year if region=="东部", lcolor(navy) lwidth(medthick)) ///
    (line net_rate year if region=="中部", lcolor(maroon) lpattern(dash)) ///
    (line net_rate year if region=="西部", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line net_rate year if region=="东北", lcolor(orange_red) lpattern(longdash)) ///
    , title("不同区域净进入率比较") ///
      xtitle("年份") ytitle("净进入率") ///
      legend(order(1 "东部" 2 "中部" 3 "西部" 4 "东北") rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure2_region_comparison.png", replace width(2200)
restore

* 图3：2023年净进入率前20城市
preserve
keep if year == 2023
gsort -net_rate
keep in 1/20
gsort net_rate
graph hbar net_rate, over(城市, sort(1) descending label(labsize(small))) ///
    title("2023年净进入率前20城市") ///
    ytitle("净进入率") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure3_top20_2023.png", replace width(2200)
restore

* 图4：城市平均进入率与退出率
preserve
collapse (mean) entry_rate exit_rate firm_total, by(城市)
twoway ///
    (scatter entry_rate exit_rate [w=firm_total], mcolor(navy%35) msize(small)) ///
    (function y=x, range(0 1) lcolor(maroon) lpattern(dash)) ///
    , title("城市平均进入率与退出率") ///
      xtitle("平均退出率") ytitle("平均进入率") ///
      legend(order(1 "城市" 2 "45度线")) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure4_entry_exit_scatter.png", replace width(2200)
restore

* 图5：净进入率排名跃升前15城市
use `rank_panel', clear
keep if inlist(year, 2000, 2023)
keep if firm_total >= 5000
keep 省份 城市 year rank_net net_rate firm_total
reshape wide rank_net net_rate firm_total, i(省份 城市) j(year)
drop if missing(rank_net2000) | missing(rank_net2023)
gen rank_improve = rank_net2000 - rank_net2023
gsort -rank_improve
preserve
keep if rank_improve > 0
gen order_up = _n
keep if order_up <= 15
gsort rank_improve
graph hbar rank_improve, over(城市, sort(1) descending label(labsize(small))) ///
    title("2000-2023年净进入率排名跃升前15城市") ///
    ytitle("名次提升（2000名次-2023名次）") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure5_rank_improvers.png", replace width(2200)
restore

export delimited using "$TAB/city_rank_change_2000_2023.csv", replace

* 图7：头部城市排名轨迹
use `rank_panel', clear
keep if inlist(城市, "北京市", "上海市", "广州市", "深圳市", "杭州市", "成都市")
twoway ///
    (line rank_net year if 城市=="北京市", lcolor(navy) lwidth(medthick)) ///
    (line rank_net year if 城市=="上海市", lcolor(maroon) lwidth(medthick)) ///
    (line rank_net year if 城市=="广州市", lcolor(forest_green) lwidth(medthick)) ///
    (line rank_net year if 城市=="深圳市", lcolor(orange_red) lwidth(medthick)) ///
    (line rank_net year if 城市=="杭州市", lcolor(teal) lwidth(medthick)) ///
    (line rank_net year if 城市=="成都市", lcolor(cranberry) lwidth(medthick)) ///
    , title("主要城市净进入率排名轨迹") ///
      xtitle("年份") ytitle("年度排名（数值越小越靠前）") ///
      yscale(reverse) ///
      legend(order(1 "北京" 2 "上海" 3 "广州" 4 "深圳" 5 "杭州" 6 "成都") rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure7_topcity_rank_paths.png", replace width(2200)

* 图8：净进入率分布变化
use `rank_panel', clear
keep if inlist(year, 2000, 2010, 2023)
graph box net_rate, over(year, label(labsize(small))) ///
    title("净进入率的年度分布变化") ///
    ytitle("净进入率") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure8_index_distribution_box.png", replace width(2200)

*========================
* 六、行业扩展分析：单独使用市级-地区行业门类-年份层次做描述
*========================
use "$DATA", clear
keep if 统计口径 == "地区-行业门类-年份" & 地区层级 == "市级"
keep 省份 城市 成立年份 行业门类 entry_count exit_count firm_total
rename 成立年份 year
keep if year >= 2000

collapse (sum) entry_count exit_count firm_total, by(行业门类 year)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
gen net_rate = (entry_count - exit_count) / firm_total
gen turnover_rate = entry_rate + exit_rate

tempfile industry_panel
save `industry_panel', replace

* 行业长期均值
preserve
collapse (mean) entry_rate exit_rate net_rate turnover_rate (sum) firm_total, by(行业门类)
gsort -turnover_rate
export delimited using "$TAB/industry_summary_2000_2023.csv", replace
restore

* 图6：行业平均进入退出活跃度
preserve
collapse (mean) turnover_rate entry_rate exit_rate net_rate, by(行业门类)
gsort -turnover_rate
graph hbar turnover_rate, over(行业门类, sort(1) descending label(labsize(small))) ///
    title("行业平均进入退出活跃度") ///
    ytitle("平均进入率 + 平均退出率") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure6_industry_turnover.png", replace width(2400)
restore

* 选取进入退出最活跃的四个行业，观察趋势
use `industry_panel', clear
preserve
collapse (mean) turnover_rate, by(行业门类)
gsort -turnover_rate
keep in 1/4
levelsof 行业门类, local(top4_industries)
restore

* 图9：高活跃行业进入率趋势
local i1 : word 1 of `top4_industries'
local i2 : word 2 of `top4_industries'
local i3 : word 3 of `top4_industries'
local i4 : word 4 of `top4_industries'

twoway ///
    (line entry_rate year if 行业门类=="`i1'", lcolor(navy) lwidth(medthick)) ///
    (line entry_rate year if 行业门类=="`i2'", lcolor(maroon) lpattern(dash)) ///
    (line entry_rate year if 行业门类=="`i3'", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line entry_rate year if 行业门类=="`i4'", lcolor(orange_red) lpattern(longdash)) ///
    , title("高活跃行业进入率趋势") ///
      xtitle("年份") ytitle("进入率") ///
      legend(order(1 "`i1'" 2 "`i2'" 3 "`i3'" 4 "`i4'") rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure9_industry_entry_trends.png", replace width(2400)

* 图10：高活跃行业退出率趋势
twoway ///
    (line exit_rate year if 行业门类=="`i1'", lcolor(navy) lwidth(medthick)) ///
    (line exit_rate year if 行业门类=="`i2'", lcolor(maroon) lpattern(dash)) ///
    (line exit_rate year if 行业门类=="`i3'", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line exit_rate year if 行业门类=="`i4'", lcolor(orange_red) lpattern(longdash)) ///
    , title("高活跃行业退出率趋势") ///
      xtitle("年份") ytitle("退出率") ///
      legend(order(1 "`i1'" 2 "`i2'" 3 "`i3'" 4 "`i4'") rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure10_industry_exit_trends.png", replace width(2400)

* 删除不再使用的旧图6
cap erase "$FIG/figure6_rank_decliners.png"
cap erase "$FIG/figure4_diversity_netentry.png"

*========================
* 七、论文宏变量
*========================
use `analysis_panel', clear
quietly summarize entry_rate if year >= 2000
scalar mean_entry = r(mean)

quietly summarize exit_rate if year >= 2000
scalar mean_exit = r(mean)

quietly summarize net_rate if year >= 2000
scalar mean_net = r(mean)

file open stats using "$TAB/paper_stats.tex", write replace
file write stats "\newcommand{\MeanEntryRate}{" %5.3f (mean_entry) "}" _n
file write stats "\newcommand{\MeanExitRate}{" %5.3f (mean_exit) "}" _n
file write stats "\newcommand{\MeanNetRate}{" %5.3f (mean_net) "}" _n
file close stats

log close _all
