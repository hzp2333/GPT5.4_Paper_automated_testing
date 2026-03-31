version 15.1
clear all
set more off

global ROOT "f:/桌面/论文测试/stata测试3"
global DATA_CITY_Y "$ROOT/data/企业进入退出中级市级地区-年份.dta"
global DATA_CITY_IY "$ROOT/data/企业进入退出中级市级地区-行业-年份.dta"
global DATA_PROV "$ROOT/data/企业进入退出中级省级.dta"
global DATA_SURV "$ROOT/data/测试企业生存年份.dta"
global OUT "$ROOT/output"
global TAB "$OUT/tables"
global FIG "$OUT/figures"
global TEX "$ROOT/paper"

cap mkdir "$OUT"
cap mkdir "$TAB"
cap mkdir "$FIG"

cap log close _all
log using "$OUT/analysis.log", replace text

cap which esttab
if _rc {
    di as error "esttab 未安装，无法生成 LaTeX 回归表。"
    exit 199
}

*========================
* 一、主样本：市级 地区-行业-年份
*========================
use "$DATA_CITY_IY", clear
keep if 统计口径 == "地区-行业-年份" & 地区层级 == "市级"
keep if year >= 2000
keep if firm_total >= 5

keep 省份 城市 year 行业名称 行业代码 entry_count exit_count enter_sum firm_total ///
    entry_rate exit_rate net_rate

sort 省份 城市 行业代码 行业名称 year
duplicates drop 省份 城市 行业代码 year, force

preserve
collapse (sum) firm_total, by(省份 城市 year 行业代码 行业名称)
bys 省份 城市 year: egen city_total = total(firm_total)
gen industry_share = firm_total / city_total
gen share_sq = industry_share^2
bys 省份 城市 year: egen hhi = total(share_sq)
keep 省份 城市 year city_total hhi
duplicates drop 省份 城市 year, force
tempfile hhi_city_year
save `hhi_city_year', replace
restore

merge m:1 省份 城市 year using `hhi_city_year', nogen keep(match)

gen ln_firm_total = ln(firm_total)

egen city_id = group(省份 城市)
egen industry_id = group(行业代码 行业名称)
egen panel_id = group(省份 城市 行业代码 行业名称)
xtset panel_id year

gen L1_entry_rate = L.entry_rate
gen L1_exit_rate = L.exit_rate
gen L1_net_rate = L.net_rate
gen L1_ln_firm_total = L.ln_firm_total
gen L1_hhi = L.hhi

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

label var firm_total "地区-行业-年份单元企业数"
label var entry_count "进入企业数"
label var exit_count "退出企业数"
label var entry_rate "进入率"
label var exit_rate "退出率"
label var net_rate "净进入率"
label var ln_firm_total "单元企业数对数"
label var hhi "城市行业集中度HHI"
label var L1_hhi "滞后一期城市行业集中度HHI"
label var L1_entry_rate "滞后一期进入率"
label var L1_exit_rate "滞后一期退出率"
label var L1_net_rate "滞后一期净进入率"
label var L1_ln_firm_total "滞后一期单元企业数对数"
label var is_subprovincial "副省级城市"
label var is_capital "省会城市"

egen tag_city = tag(city_id)
egen tag_industry = tag(industry_id)
egen tag_panel = tag(panel_id)

count
scalar N_obs = r(N)
count if tag_city
scalar N_city = r(N)
count if tag_industry
scalar N_industry = r(N)
count if tag_panel
scalar N_panel = r(N)

quietly summarize entry_rate, meanonly
scalar mean_entry = r(mean)
quietly summarize exit_rate, meanonly
scalar mean_exit = r(mean)
quietly summarize net_rate, meanonly
scalar mean_net = r(mean)
quietly summarize hhi, meanonly
scalar mean_hhi_cell = r(mean)
preserve
keep 省份 城市 year hhi
duplicates drop 省份 城市 year, force
quietly summarize hhi, meanonly
scalar mean_hhi_city = r(mean)
restore

preserve
bys year: egen n_obs_year = count(year)
bys year: egen n_city_year = nvals(city_id)
bys year: egen n_industry_year = nvals(industry_id)
collapse (first) n_obs_year n_city_year n_industry_year, by(year)
quietly summarize n_obs_year if year == 2000, meanonly
scalar obs_2000 = r(mean)
quietly summarize n_city_year if year == 2000, meanonly
scalar city_2000 = r(mean)
quietly summarize n_industry_year if year == 2000, meanonly
scalar industry_2000 = r(mean)
quietly summarize n_obs_year if year == 2023, meanonly
scalar obs_2023 = r(mean)
quietly summarize n_city_year if year == 2023, meanonly
scalar city_2023 = r(mean)
quietly summarize n_industry_year if year == 2023, meanonly
scalar industry_2023 = r(mean)
restore

tempfile analysis_panel
save `analysis_panel', replace
save "$OUT/city_industry_year_panel_main.dta", replace

preserve
keep 省份 城市 year hhi city_total
duplicates drop 省份 城市 year, force
save "$OUT/city_year_hhi_panel.dta", replace
restore

*========================
* 二、补充样本：省级 地区-行业-年份
*========================
use "$DATA_PROV", clear
keep if 统计口径 == "地区-行业-年份" & 地区层级 == "省级"
keep if year >= 2000
keep if firm_total >= 5
keep 省份 year 行业名称 行业代码 entry_count exit_count enter_sum firm_total ///
    entry_rate exit_rate net_rate
sort 省份 行业代码 行业名称 year
duplicates drop 省份 行业代码 year, force
save "$OUT/province_industry_year_panel_supplement.dta", replace

preserve
collapse (sum) entry_count exit_count firm_total, by(省份)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
gen net_rate = (entry_count - exit_count) / firm_total
gsort -net_rate
export delimited using "$TAB/province_summary_2000_2023.csv", replace
restore

*========================
* 三、描述统计
*========================
use `analysis_panel', clear

estpost tabstat firm_total entry_count exit_count entry_rate exit_rate net_rate hhi ln_firm_total, ///
    statistics(count mean sd p25 p50 p75) columns(statistics)
esttab using "$TAB/table1_descriptive_stats.tex", ///
    replace label booktabs nomtitle nonumber noobs ///
    cells("count(fmt(%9.0fc)) mean(fmt(3)) sd(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3))") ///
    title("描述统计：市级地区-行业-年份样本（2000--2023，单元企业数至少为5）")

* 区域年度总量与均值
preserve
collapse (sum) entry_count exit_count firm_total, by(region year)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
gen net_rate = (entry_count - exit_count) / firm_total
tempfile region_year
save `region_year', replace
collapse (mean) entry_rate exit_rate net_rate (sum) firm_total, by(region)
export delimited using "$TAB/region_means.csv", replace
restore

* 图1：全国加总进入率、退出率、净进入率
preserve
collapse (sum) entry_count exit_count firm_total, by(year)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
gen net_rate = (entry_count - exit_count) / firm_total
twoway ///
    (line entry_rate year, lcolor(navy) lwidth(medthick)) ///
    (line exit_rate year, lcolor(maroon) lpattern(dash) lwidth(medthick)) ///
    (line net_rate year, lcolor(forest_green) lpattern(shortdash_dot) lwidth(medthick)) ///
    , title("全国市级地区-行业单元加总进入、退出与净进入率走势") ///
      xtitle("年份") ytitle("比率") ///
      legend(order(1 "进入率" 2 "退出率" 3 "净进入率") position(6) ring(1) rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure1_national_index_trend.png", replace width(2200)
restore

* 图2：区域净进入率比较
use `region_year', clear
twoway ///
    (line net_rate year if region=="东部", lcolor(navy) lwidth(medthick)) ///
    (line net_rate year if region=="中部", lcolor(maroon) lpattern(dash)) ///
    (line net_rate year if region=="西部", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line net_rate year if region=="东北", lcolor(orange_red) lpattern(longdash)) ///
    , title("不同区域的净进入率比较") ///
      xtitle("年份") ytitle("净进入率") ///
      legend(order(1 "东部" 2 "中部" 3 "西部" 4 "东北") position(6) ring(1) rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure2_region_comparison.png", replace width(2200)

*========================
* 四、城市聚合后的排序图与HHI
*========================
use `analysis_panel', clear
collapse (sum) entry_count exit_count firm_total ///
    (count) industry_cells=net_rate ///
    (max) hhi city_total, by(省份 城市 year)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
gen net_rate = (entry_count - exit_count) / firm_total
label var industry_cells "有效行业单元数"
label var city_total "城市年度样本企业数"

tempfile city_year_agg
save `city_year_agg', replace
save "$OUT/city_year_aggregated_from_industry_main.dta", replace

cap erase "$TAB/top20_cities_2023.csv"
cap erase "$FIG/figure3_top20_2023.png"

* 图3：城市平均进入率与退出率
preserve
collapse (sum) entry_count exit_count firm_total, by(省份 城市)
gen entry_rate = entry_count / firm_total
gen exit_rate = exit_count / firm_total
twoway ///
    (scatter entry_rate exit_rate [w=firm_total], mcolor(navy%35) msize(small)) ///
    (function y=x, range(0 1) lcolor(maroon) lpattern(dash)) ///
    , title("城市平均进入率与退出率") ///
      xtitle("平均退出率") ytitle("平均进入率") ///
      legend(order(1 "城市" 2 "45度线") position(6) ring(1) rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure3_entry_exit_scatter.png", replace width(2200)
restore

cap erase "$FIG/figure4_entry_exit_scatter.png"

* 图4、图6：城市排名变化
use `city_year_agg', clear
keep if industry_cells >= 5
keep if firm_total > 50
bys year: egen city_count_year = count(城市)
bys year: egen rank_net = rank(-net_rate)

tempfile rank_panel
save `rank_panel', replace

preserve
keep if inlist(year, 2000, 2023)
keep 省份 城市 year rank_net net_rate firm_total industry_cells
reshape wide rank_net net_rate firm_total industry_cells, i(省份 城市) j(year)
drop if missing(rank_net2000) | missing(rank_net2023)
gen rank_improve = rank_net2000 - rank_net2023
gen rank_change = rank_net2023 - rank_net2000
gen abs_rank_change = abs(rank_change)
gsort -rank_improve
export delimited using "$TAB/city_rank_change_2000_2023.csv", replace

gsort -abs_rank_change
gen order_up = _n
keep if order_up <= 15
gsort abs_rank_change
graph hbar abs_rank_change, over(城市, sort(1) descending label(labsize(small))) ///
    title("2000--2023年净进入率排名变动最大的15城市") ///
    ytitle("排名变动绝对值") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure4_rank_improvers.png", replace width(2200)
restore

cap erase "$FIG/figure5_rank_improvers.png"

* 图5：城市产业集中度HHI走势
use `city_year_agg', clear
collapse (mean) hhi, by(year)
twoway ///
    (line hhi year, lcolor(navy) lwidth(medthick)) ///
    , title("城市产业集中度（HHI）走势") ///
      xtitle("年份") ytitle("HHI") ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure5_hhi_trend.png", replace width(2200)

cap erase "$FIG/figure6_hhi_trend.png"

* 图6：主要城市排名轨迹
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
      legend(order(1 "北京" 2 "上海" 3 "广州" 4 "深圳" 5 "杭州" 6 "成都") position(6) ring(1) rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure6_topcity_rank_paths.png", replace width(2200)

cap erase "$FIG/figure7_topcity_rank_paths.png"

* 图7：净进入率分布变化
use `analysis_panel', clear
keep if inlist(year, 2000, 2010, 2023)
graph box net_rate, over(year, label(labsize(small))) ///
    title("净进入率的年度分布变化") ///
    ytitle("净进入率") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure7_index_distribution_box.png", replace width(2200)

cap erase "$FIG/figure8_index_distribution_box.png"

*========================
* 五、基准回归
*========================
use `analysis_panel', clear
xtset panel_id year

eststo clear

xtreg net_rate L1_ln_firm_total, fe vce(cluster city_id)
eststo m1
estadd local panel_fe "Yes"
estadd local year_fe "No"

xtreg net_rate L1_net_rate L1_ln_firm_total L1_hhi i.year, fe vce(cluster city_id)
eststo m2
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

xtreg entry_rate L1_entry_rate L1_ln_firm_total L1_hhi i.year, fe vce(cluster city_id)
eststo m3
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

xtreg exit_rate L1_exit_rate L1_ln_firm_total L1_hhi i.year, fe vce(cluster city_id)
eststo m4
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

esttab m1 m2 m3 m4 using "$TAB/table2_baseline_regs.tex", ///
    replace label booktabs se star(* 0.10 ** 0.05 *** 0.01) drop(*.year) ///
    stats(panel_fe year_fe N r2_within, fmt(%9s %9s %9.0fc 3) ///
    labels("City-Industry FE" "Year FE" "Observations" "Within R-squared")) ///
    title("市级地区-行业-年份样本：基准固定效应回归")

*========================
* 六、异质性回归
*========================
use `analysis_panel', clear
xtset panel_id year

eststo clear

xtreg net_rate c.L1_ln_firm_total##i.east L1_net_rate L1_hhi i.year, fe vce(cluster city_id)
eststo h1
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

xtreg net_rate c.L1_ln_firm_total##i.is_capital L1_net_rate L1_hhi i.year, fe vce(cluster city_id)
eststo h2
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

xtreg net_rate c.L1_ln_firm_total##i.is_subprovincial L1_net_rate L1_hhi i.year, fe vce(cluster city_id)
eststo h3
estadd local panel_fe "Yes"
estadd local year_fe "Yes"

esttab h1 h2 h3 using "$TAB/table3_heterogeneity.tex", ///
    replace label booktabs se star(* 0.10 ** 0.05 *** 0.01) drop(*.year) ///
    stats(panel_fe year_fe N r2_within, fmt(%9s %9s %9.0fc 3) ///
    labels("City-Industry FE" "Year FE" "Observations" "Within R-squared")) ///
    title("市级地区-行业-年份样本：异质性分析")

*========================
* 七、行业扩展展示
*========================
use `analysis_panel', clear

preserve
collapse (mean) entry_rate exit_rate net_rate (sum) firm_total, by(行业名称)
gsort -firm_total
export delimited using "$TAB/industry_summary_2000_2023.csv", replace
restore

* 图8：样本规模最大的行业平均净进入率
preserve
collapse (mean) net_rate (sum) firm_total, by(行业名称)
gsort -firm_total
keep in 1/15
gsort net_rate
graph hbar net_rate, over(行业名称, sort(1) descending label(labsize(small))) ///
    title("样本规模最大的15个行业的平均净进入率") ///
    ytitle("平均净进入率") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure8_industry_net_rate.png", replace width(2400)
restore

* 选取样本规模最大的四个行业，观察趋势
preserve
collapse (sum) firm_total, by(行业名称)
gsort -firm_total
levelsof 行业名称 in 1/4, local(top4_industries) clean
restore

local i1 : word 1 of `top4_industries'
local i2 : word 2 of `top4_industries'
local i3 : word 3 of `top4_industries'
local i4 : word 4 of `top4_industries'

preserve
collapse (mean) entry_rate exit_rate, by(行业名称 year)
twoway ///
    (line entry_rate year if 行业名称=="`i1'", lcolor(navy) lwidth(medthick)) ///
    (line entry_rate year if 行业名称=="`i2'", lcolor(maroon) lpattern(dash)) ///
    (line entry_rate year if 行业名称=="`i3'", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line entry_rate year if 行业名称=="`i4'", lcolor(orange_red) lpattern(longdash)) ///
    , title("样本规模最大的四个行业进入率趋势") ///
      xtitle("年份") ytitle("进入率") ///
      legend(order(1 "`i1'" 2 "`i2'" 3 "`i3'" 4 "`i4'") position(6) ring(1) rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure9_industry_entry_trends.png", replace width(2400)

twoway ///
    (line exit_rate year if 行业名称=="`i1'", lcolor(navy) lwidth(medthick)) ///
    (line exit_rate year if 行业名称=="`i2'", lcolor(maroon) lpattern(dash)) ///
    (line exit_rate year if 行业名称=="`i3'", lcolor(forest_green) lpattern(shortdash_dot)) ///
    (line exit_rate year if 行业名称=="`i4'", lcolor(orange_red) lpattern(longdash)) ///
    , title("样本规模最大的四个行业退出率趋势") ///
      xtitle("年份") ytitle("退出率") ///
      legend(order(1 "`i1'" 2 "`i2'" 3 "`i3'" 4 "`i4'") position(6) ring(1) rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure10_industry_exit_trends.png", replace width(2400)
restore

cap erase "$FIG/figure6_industry_turnover.png"
cap erase "$FIG/figure9_industry_net_rate.png"
cap erase "$FIG/figure10_industry_entry_trends.png"
cap erase "$FIG/figure11_industry_exit_trends.png"

*========================
* 八、生存时间扩展分析
*========================
tempfile sector_map
clear
input str1 sector_code str48 行业门类
"A" "农、林、牧、渔业"
"B" "采矿业"
"C" "制造业"
"D" "电力、热力、燃气及水生产和供应业"
"E" "建筑业"
"F" "批发和零售业"
"G" "交通运输、仓储和邮政业"
"H" "住宿和餐饮业"
"I" "信息传输、软件和信息技术服务业"
"J" "金融业"
"K" "房地产业"
"L" "租赁和商务服务业"
"M" "科学研究和技术服务业"
"N" "水利、环境和公共设施管理业"
"O" "居民服务、修理和其他服务业"
"P" "教育"
"Q" "卫生和社会工作"
"R" "文化、体育和娱乐业"
"S" "公共管理、社会保障和社会组织"
end
save `sector_map', replace

use `analysis_panel', clear
keep if year >= 2010
gen sector_code = substr(行业代码, 1, 1)
collapse (mean) net_rate entry_rate exit_rate (sum) firm_total, by(sector_code)
merge 1:1 sector_code using `sector_map', nogen keep(match)
keep if trim(行业门类) != ""
tempfile sector_dynamics
save `sector_dynamics', replace

use "$DATA_SURV", clear
keep if trim(行业门类) != "" & !missing(age)
keep if inrange(成立年份, 2010, 2023)

count
scalar survival_obs = r(N)
quietly summarize age, meanonly
scalar mean_survival_age = r(mean)
quietly levelsof 行业门类, local(surv_industries) clean
scalar survival_industries = wordcount(`"`surv_industries'"')

tempfile survival_clean
save `survival_clean', replace

* 图11：2015-2020年不同成立年份企业的平均生存时间指数（2015=100）
preserve
keep if inrange(成立年份, 2015, 2020)
collapse (mean) age (p1) age_p1=age (p99) age_p99=age, by(成立年份)
quietly summarize age if 成立年份 == 2015, meanonly
scalar base_age = r(mean)
gen age_index = age / base_age * 100
gen age_p1_index = age_p1 / base_age * 100
gen age_p99_index = age_p99 / base_age * 100
export delimited using "$TAB/survival_year_summary.csv", replace
twoway ///
    (rarea age_p99_index age_p1_index 成立年份, color(navy%22) lcolor(none)) ///
    (line age_p99_index 成立年份, lcolor(navy%60) lpattern(shortdash)) ///
    (line age_p1_index 成立年份, lcolor(navy%60) lpattern(shortdash)) ///
    (line age_index 成立年份, lcolor(navy) lwidth(medthick)) ///
    , title("2015--2020年企业平均生存时间指数（2015年=100）") ///
      xtitle("成立年份") ytitle("生存时间指数（2015年平均值=100）") ///
      xlabel(2015(1)2020) ///
      legend(order(4 "平均生存时间指数" 1 "1\%-99\%区间带" 2 "99\%边界" 3 "1\%边界") position(6) ring(1) rows(2)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure11_survival_cohort_trend.png", replace width(2200)
restore

* 图13：行业生存时间溢价
preserve
bys 成立年份: egen cohort_age = mean(age)
gen age_premium = age - cohort_age
collapse (mean) age_premium age (count) obs=age, by(行业门类)
gsort -age_premium
export delimited using "$TAB/survival_industry_premium.csv", replace
gsort age_premium
graph hbar age_premium, over(行业门类, sort(1) descending label(labsize(small))) ///
    title("行业生存时间溢价") ///
    ytitle("相对同成立年份平均值的溢价（年）") ///
    graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure12_survival_premium.png", replace width(2400)
restore

* 图14：生存时间与净进入率的行业关系
preserve
collapse (mean) age (count) obs=age, by(行业门类)
merge 1:1 行业门类 using `sector_dynamics', nogen keep(match)
gen label_sector = ""
replace label_sector = 行业门类 if inlist(行业门类, ///
    "科学研究和技术服务业", "交通运输、仓储和邮政业", "教育", ///
    "采矿业", "电力、热力、燃气及水生产和供应业", "水利、环境和公共设施管理业")
export delimited using "$TAB/survival_netrate_link.csv", replace
twoway ///
    (scatter age net_rate [w=firm_total], msymbol(circle_hollow) mcolor(navy%45) ///
        mlabel(label_sector) mlabsize(vsmall) mlabcolor(black)) ///
    (lfit age net_rate, lcolor(maroon) lpattern(dash) lwidth(medthick)) ///
    , title("行业平均生存时间与净进入率的关系") ///
      xtitle("2010--2023年平均净进入率") ytitle("平均生存时间（年）") ///
      legend(order(1 "行业门类" 2 "线性拟合") position(6) ring(1) rows(1)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$FIG/figure13_survival_netrate_scatter.png", replace width(2200)
restore

cap erase "$FIG/figure12_survival_cohort_trend.png"
cap erase "$FIG/figure13_survival_premium.png"
cap erase "$FIG/figure14_survival_netrate_scatter.png"

*========================
* 九、论文宏变量
*========================
file open stats using "$TAB/paper_stats.tex", write replace
file write stats "\newcommand{\MeanEntryRate}{" %5.3f (mean_entry) "}" _n
file write stats "\newcommand{\MeanExitRate}{" %5.3f (mean_exit) "}" _n
file write stats "\newcommand{\MeanNetRate}{" %5.3f (mean_net) "}" _n
file write stats "\newcommand{\MeanHHI}{" %5.3f (mean_hhi_cell) "}" _n
file write stats "\newcommand{\MeanCityHHI}{" %5.3f (mean_hhi_city) "}" _n
file write stats "\newcommand{\MeanSurvivalAge}{" %5.3f (mean_survival_age) "}" _n
file write stats "\newcommand{\SurvivalObs}{" %9.0fc (survival_obs) "}" _n
file write stats "\newcommand{\SurvivalIndustries}{" %9.0fc (survival_industries) "}" _n
file write stats "\newcommand{\SampleObs}{" %12.0fc (N_obs) "}" _n
file write stats "\newcommand{\SampleCities}{" %9.0fc (N_city) "}" _n
file write stats "\newcommand{\SampleIndustries}{" %9.0fc (N_industry) "}" _n
file write stats "\newcommand{\SamplePanels}{" %12.0fc (N_panel) "}" _n
file write stats "\newcommand{\ObsYTwoThousand}{" %9.0fc (obs_2000) "}" _n
file write stats "\newcommand{\CitiesYTwoThousand}{" %9.0fc (city_2000) "}" _n
file write stats "\newcommand{\IndustriesYTwoThousand}{" %9.0fc (industry_2000) "}" _n
file write stats "\newcommand{\ObsYTwentyThree}{" %9.0fc (obs_2023) "}" _n
file write stats "\newcommand{\CitiesYTwentyThree}{" %9.0fc (city_2023) "}" _n
file write stats "\newcommand{\IndustriesYTwentyThree}{" %9.0fc (industry_2023) "}" _n
file close stats

log close _all
