clear all
set more off
set scheme s1color

cd "f:/桌面/stata测试"

capture which esttab
if _rc ssc install estout, replace

capture which eststo
if _rc ssc install estout, replace

use "数据/分析样本/paper_analysis_sample.dta", clear

capture confirm variable firm_id
if _rc {
    encode Symbol, gen(firm_id)
}

capture confirm variable industry_id
if _rc {
    encode IndustryCode, gen(industry_id)
}

xtset firm_id year

label variable violated_flag "违规虚拟变量"
label variable violation_count "违规次数"
label variable ln_total_emp "员工规模对数"
label variable ln_skill_emp "技能员工规模对数"
label variable ln_rd_emp "研发员工对数"
label variable ln_registercapital "注册资本对数"
label variable firm_age "上市年限"
label variable ln_penalty_total "处罚总额对数"

gen ln_violation_count = ln(violation_count + 1)
gen ln_admin_emp = ln(admin_emp + 1)
gen ln_business_emp = ln(business_emp + 1)
gen ln_total_emp_sq = ln_total_emp^2
gen ln_skill_emp_sq = ln_skill_emp^2
gen post_2020 = year >= 2020

preserve
keep if inrange(year, 2016, 2019)
collapse (mean) pre_skill=ln_skill_emp pre_size=ln_total_emp, by(firm_id)
quietly summarize pre_skill, detail
scalar med_skill = r(p50)
quietly summarize pre_size, detail
scalar med_size = r(p50)
tempfile prebase
save `prebase'
restore

merge m:1 firm_id using `prebase', keep(master match) nogen
gen high_skill_pre = pre_skill >= med_skill if pre_skill < .
gen high_size_pre = pre_size >= med_size if pre_size < .
gen placebo_2018 = year >= 2018

sort firm_id year
xtset firm_id year

gen L1_ln_total_emp = L1.ln_total_emp
gen L1_ln_skill_emp = L1.ln_skill_emp
gen L1_ln_admin_emp = L1.ln_admin_emp
gen L1_ln_business_emp = L1.ln_business_emp

quietly count
scalar n_obs = r(N)
quietly summarize violated_flag
scalar mean_violate = r(mean)
quietly summarize violation_count
scalar mean_vcount = r(mean)
quietly summarize ln_total_emp
scalar mean_size = r(mean)
quietly summarize ln_skill_emp
scalar mean_skill = r(mean)
quietly summarize ln_registercapital
scalar mean_capital = r(mean)
quietly summarize firm_age
scalar mean_age = r(mean)
quietly count if high_skill_pre == 1
scalar n_high_skill = r(N)
quietly count if high_size_pre == 1
scalar n_high_size = r(N)
quietly count if year >= 2020
scalar n_post = r(N)

* 表1：描述统计
eststo clear
estpost summarize violated_flag violation_count ln_total_emp ln_skill_emp ln_rd_emp ln_admin_emp ln_business_emp ln_registercapital firm_age
esttab . using "文档/表格/paper_desc.tex", replace ///
    cells("count(fmt(0)) mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") ///
    label nonumber noobs nomtitles booktabs fragment ///
    collabels("N" "Mean" "SD" "Min" "Max")

* 表2：主结果，逐步提高识别强度
eststo clear
reg violated_flag ln_total_emp ln_skill_emp ln_registercapital firm_age i.year i.industry_id, vce(cluster firm_id)
eststo main1
estadd local Model "行业+年份 FE"

xtreg violated_flag ln_total_emp ln_skill_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo main2
estadd local Model "公司 FE"

xtreg violated_flag L1_ln_total_emp L1_ln_skill_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo main3
estadd local Model "公司 FE + 滞后"

xtreg ln_violation_count L1_ln_total_emp L1_ln_skill_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo main4
estadd local Model "违规强度"

esttab main1 main2 main3 main4 using "文档/表格/paper_main.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    label booktabs fragment ///
    drop(*.year *.industry_id) ///
    mtitles("(1)" "(2)" "(3)" "(4)") collabels(none) nonumbers ///
    stats(N r2 Model, fmt(0 3 0) labels("Observations" "R-squared" "Specification"))

* 表3：准实验检验，预先人力资本 x 2020 后冲击
eststo clear
xtreg violated_flag c.high_skill_pre#c.post_2020 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo did1
estadd local Treat "高技能预暴露"

xtreg violated_flag c.high_size_pre#c.post_2020 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo did2
estadd local Treat "大规模预暴露"

xtreg ln_violation_count c.high_skill_pre#c.post_2020 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo did3
estadd local Treat "高技能预暴露"

xtreg ln_violation_count c.high_size_pre#c.post_2020 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo did4
estadd local Treat "大规模预暴露"

esttab did1 did2 did3 did4 using "文档/表格/paper_did.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    label booktabs fragment ///
    drop(*.year) ///
    mtitles("(1)" "(2)" "(3)" "(4)") collabels(none) nonumbers ///
    stats(N r2 Treat, fmt(0 3 0) labels("Observations" "R-squared" "Treatment"))

* 表4：机制检验
eststo clear
xtreg ln_admin_emp ln_total_emp ln_skill_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo mech1
estadd local Channel "行政执行网络"

xtreg ln_business_emp ln_total_emp ln_skill_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo mech2
estadd local Channel "业务执行网络"

xtreg violated_flag ln_total_emp ln_skill_emp ln_admin_emp ln_business_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo mech3
estadd local Channel "通道纳入主回归"

xtreg violated_flag L1_ln_skill_emp L1_ln_admin_emp L1_ln_business_emp ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo mech4
estadd local Channel "滞后通道"

esttab mech1 mech2 mech3 mech4 using "文档/表格/paper_mechanism.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    label booktabs fragment ///
    drop(*.year) ///
    mtitles("(1)" "(2)" "(3)" "(4)") collabels(none) nonumbers ///
    stats(N r2 Channel, fmt(0 3 0) labels("Observations" "R-squared" "Mechanism"))

* 表5：安慰剂检验
eststo clear
xtreg violated_flag c.high_skill_pre#c.placebo_2018 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo plc1
estadd local Placebo "高技能预暴露"

xtreg violated_flag c.high_size_pre#c.placebo_2018 ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo plc2
estadd local Placebo "大规模预暴露"

esttab plc1 plc2 using "文档/表格/paper_placebo.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    label booktabs fragment ///
    drop(*.year) ///
    mtitles("(1)" "(2)") collabels(none) nonumbers ///
    stats(N r2 Placebo, fmt(0 3 0) labels("Observations" "R-squared" "Placebo treatment"))

* 表6：非线性检验
eststo clear
xtreg violated_flag ln_total_emp ln_total_emp_sq ln_skill_emp ln_skill_emp_sq ///
    ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo nl1
estadd local Outcome "违规虚拟变量"

xtreg ln_violation_count ln_total_emp ln_total_emp_sq ln_skill_emp ln_skill_emp_sq ///
    ln_registercapital firm_age i.year, fe vce(cluster firm_id)
eststo nl2
estadd local Outcome "违规强度"

esttab nl1 nl2 using "文档/表格/paper_nonlinear.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.4f) se(%9.4f) ///
    label booktabs fragment ///
    drop(*.year) ///
    mtitles("(1)" "(2)") collabels(none) nonumbers ///
    stats(N r2 Outcome, fmt(0 3 0) labels("Observations" "R-squared" "Outcome"))

* 表7：趋势表
preserve
collapse (mean) mean_violate=violated_flag mean_count=violation_count ///
         mean_size=ln_total_emp mean_skill=ln_skill_emp, by(year)
format mean_violate mean_count mean_size mean_skill %9.3f
file open trend using "文档/表格/paper_trend.tex", write replace
file write trend "年份 & 平均违规率 & 平均违规次数 & 平均员工规模对数 & 平均技能员工对数\\" _n
file write trend "\midrule" _n
forvalues i = 1/`=_N' {
    file write trend ///
        "`=string(year[`i'],"%9.0f")' & `=string(mean_violate[`i'],"%9.3f")' & `=string(mean_count[`i'],"%9.3f")' & `=string(mean_size[`i'],"%9.3f")' & `=string(mean_skill[`i'],"%9.3f")'\\" _n
}
file close trend
restore

* 图1：规模与违规率散点
preserve
xtile size_bin = ln_total_emp, n(20)
collapse (mean) mean_violate=violated_flag mean_size=ln_total_emp, by(size_bin)
twoway ///
    (scatter mean_violate mean_size, mcolor(navy) msize(small)) ///
    (lfit mean_violate mean_size, lcolor(maroon)), ///
    title("Violation risk and firm size") ///
    xtitle("Log employees") ///
    ytitle("Mean violation rate") ///
    legend(off)
graph export "文档/图片/paper_scatter.png", replace
restore

* 图2：年度趋势
preserve
collapse (mean) mean_violate=violated_flag, by(year)
twoway ///
    (line mean_violate year, lcolor(navy) lwidth(medium)) ///
    (scatter mean_violate year, mcolor(maroon) msize(small)), ///
    title("Annual violation rate") ///
    xtitle("Year") ///
    ytitle("Average violation rate") ///
    xlabel(2015(1)2022) ///
    legend(off)
graph export "文档/图片/paper_trend.png", replace
restore

* 图3：高低技能企业的年度违规率趋势
preserve
keep if high_skill_pre < .
collapse (mean) mean_violate=violated_flag, by(year high_skill_pre)
twoway ///
    (line mean_violate year if high_skill_pre==0, lcolor(navy) lwidth(medium)) ///
    (line mean_violate year if high_skill_pre==1, lcolor(maroon) lwidth(medium)), ///
    title("Violation rate by pre-period skill intensity") ///
    xtitle("Year") ///
    ytitle("Average violation rate") ///
    xlabel(2015(1)2022) ///
    legend(order(1 "低技能组" 2 "高技能组"))
graph export "文档/图片/paper_skill_trend.png", replace
restore

* 图4：高低规模企业的年度违规率趋势
preserve
keep if high_size_pre < .
collapse (mean) mean_violate=violated_flag, by(year high_size_pre)
twoway ///
    (line mean_violate year if high_size_pre==0, lcolor(navy) lwidth(medium)) ///
    (line mean_violate year if high_size_pre==1, lcolor(forest_green) lwidth(medium)), ///
    title("Violation rate by pre-period firm size") ///
    xtitle("Year") ///
    ytitle("Average violation rate") ///
    xlabel(2015(1)2022) ///
    legend(order(1 "小规模组" 2 "大规模组"))
graph export "文档/图片/paper_size_trend.png", replace
restore

* 图5：机制图，技能员工与业务执行网络
preserve
xtile skill_bin = ln_skill_emp, n(20)
collapse (mean) mean_business=ln_business_emp mean_skill=ln_skill_emp, by(skill_bin)
twoway ///
    (scatter mean_business mean_skill, mcolor(navy) msize(small)) ///
    (lfit mean_business mean_skill, lcolor(maroon)), ///
    title("Skill intensity and business execution network") ///
    xtitle("Log skill employees") ///
    ytitle("Log business employees") ///
    legend(off)
graph export "文档/图片/paper_mechanism_business.png", replace
restore

* 图6：非线性预测图
preserve
xtreg violated_flag ln_total_emp ln_total_emp_sq ln_skill_emp ln_skill_emp_sq ///
    ln_registercapital firm_age i.year, fe vce(cluster firm_id)
quietly summarize ln_registercapital
scalar cap_mean = r(mean)
quietly summarize firm_age
scalar age_mean = r(mean)
margins, at(ln_total_emp=(4(0.5)11) ln_skill_emp=`=scalar(mean_skill)' ///
    ln_registercapital=`=scalar(cap_mean)' firm_age=`=scalar(age_mean)') nose
marginsplot, recast(line) ciopts(lcolor(none)) ///
    title("Predicted violation risk across firm size") ///
    xtitle("Log employees") ///
    ytitle("Predicted violation probability") ///
    name(fig_u_size, replace)
graph export "文档/图片/paper_u_shape_size.png", replace
restore

* 摘要片段
local obs_fmt : display %9.0f scalar(n_obs)
local mean_violate_fmt : display %4.3f scalar(mean_violate)
local mean_vcount_fmt : display %4.3f scalar(mean_vcount)
local mean_size_fmt : display %4.3f scalar(mean_size)
local mean_skill_fmt : display %4.3f scalar(mean_skill)
local mean_capital_fmt : display %4.3f scalar(mean_capital)
local mean_age_fmt : display %4.3f scalar(mean_age)
local n_high_skill_fmt : display %9.0f scalar(n_high_skill)
local n_high_size_fmt : display %9.0f scalar(n_high_size)
local n_post_fmt : display %9.0f scalar(n_post)

file open desc using "文档/表格/paper_summary.tex", write replace
file write desc "\noindent 样本共包含 `obs_fmt' 个公司--年份观测，违规虚拟变量均值为 `mean_violate_fmt'，违规次数均值为 `mean_vcount_fmt'。员工规模对数均值为 `mean_size_fmt'，技能员工规模对数均值为 `mean_skill_fmt'，注册资本对数均值为 `mean_capital_fmt'，上市年限均值为 `mean_age_fmt'。" _n
file write desc "\noindent 以 2016--2019 年企业平均技能投入和平均员工规模构造预处理分组后，高技能预暴露组样本量为 `n_high_skill_fmt'，大规模预暴露组样本量为 `n_high_size_fmt'，2020--2022 年后冲击期观测量为 `n_post_fmt'。这些设定为后续的固定效应、准实验与机制分析提供了统一样本基础。" _n
file close desc

display "paper analysis complete"
