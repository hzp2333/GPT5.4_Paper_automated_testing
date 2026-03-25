clear all
set more off
set scheme s1color

cd "f:/桌面/stata测试"

* =========================================================
* 01_data_cleaning.do
* 功能：
* 1. 整理上市公司年度基本信息主表
* 2. 聚合人员结构表到公司-年份层面
* 3. 聚合违规事件表到公司-年份层面
* 4. 合并三张表并生成分析底稿
* =========================================================

* 1. 主表整理
use "数据/原始数据/STK_LISTEDCOINFOANL.dta", clear

gen year = real(substr(EndDate, 1, 4))
keep if inrange(year, 2015, 2022)

keep Symbol ShortName ListedCoID SecurityID EndDate year IndustryName IndustryCode ///
     PROVINCE CITY RegisterCapital LISTINGDATE LISTINGSTATE

isid Symbol year

gen listed_year = real(substr(LISTINGDATE, 1, 4))
gen firm_age = year - listed_year + 1 if listed_year < .
replace firm_age = . if firm_age <= 0

gen normal_listing = (LISTINGSTATE == "正常上市")
gen st_status = inlist(LISTINGSTATE, "ST", "*ST", "暂停上市")
gen ln_registercapital = ln(RegisterCapital + 1)

save "数据/中间数据/main_panel_2015_2022.dta", replace

* 2. 人员结构表聚合
use "数据/原始数据/STK_CompanyStaff.dta", clear

gen year = real(substr(EndDate, 1, 4))
keep if inrange(year, 2015, 2022)

keep Symbol EndDate year EmployStructureID EmployDetail Amount

gen total_emp_candidate = Amount if EmployStructureID == "P5701"
gen edu_grad = Amount if EmployStructureID == "P5703" & ///
    regexm(EmployDetail, "博士|硕士|研究生")
gen edu_bachelor = Amount if EmployStructureID == "P5703" & ///
    regexm(EmployDetail, "本科")

gen business_emp = Amount if EmployStructureID == "P5709" & ///
    regexm(EmployDetail, "业务|销售|营销")
gen rd_emp = Amount if EmployStructureID == "P5709" & ///
    regexm(EmployDetail, "研发|技术|科研|设计")
gen admin_emp = Amount if EmployStructureID == "P5709" & ///
    regexm(EmployDetail, "管理|行政|后勤|职能|财务")

collapse (max) total_emp=total_emp_candidate ///
         (sum) grad_emp=edu_grad bachelor_emp=edu_bachelor ///
               business_emp rd_emp admin_emp, by(Symbol year)

foreach v in total_emp grad_emp bachelor_emp business_emp rd_emp admin_emp {
    replace `v' = 0 if missing(`v')
}

gen skill_emp = grad_emp + bachelor_emp
gen ln_total_emp = ln(total_emp + 1)
gen ln_skill_emp = ln(skill_emp + 1)
gen ln_rd_emp = ln(rd_emp + 1)
gen skill_share = skill_emp / total_emp if total_emp > 0
gen rd_share = rd_emp / total_emp if total_emp > 0

save "数据/中间数据/staff_panel_2015_2022.dta", replace

* 3. 违规表聚合
use "数据/原始数据/STK_Violation_Main.dta", clear

gen year = real(substr(DeclareDate, 1, 4))
keep if inrange(year, 2015, 2022)

keep Symbol year ViolationID IsViolated Penalty SumPenalty

gen violated_flag = (IsViolated == "Y")
replace Penalty = 0 if missing(Penalty)
replace SumPenalty = 0 if missing(SumPenalty)

collapse (count) violation_count=ViolationID ///
         (max) violated_flag ///
         (sum) penalty_firm=Penalty penalty_total=SumPenalty, by(Symbol year)

gen ln_penalty_firm = ln(penalty_firm + 1)
gen ln_penalty_total = ln(penalty_total + 1)

save "数据/中间数据/violation_panel_2015_2022.dta", replace

* 4. 三表合并
use "数据/中间数据/main_panel_2015_2022.dta", clear

merge 1:1 Symbol year using "数据/中间数据/staff_panel_2015_2022.dta", keep(master match)
rename _merge merge_staff

merge 1:1 Symbol year using "数据/中间数据/violation_panel_2015_2022.dta", keep(master match)
rename _merge merge_violation

foreach v in total_emp grad_emp bachelor_emp business_emp rd_emp admin_emp ///
             skill_emp ln_total_emp ln_skill_emp ln_rd_emp skill_share rd_share ///
             violation_count violated_flag penalty_firm penalty_total ///
             ln_penalty_firm ln_penalty_total {
    replace `v' = 0 if missing(`v')
}

order Symbol ShortName year IndustryName PROVINCE CITY RegisterCapital total_emp ///
      skill_share rd_share violation_count violated_flag

isid Symbol year
encode Symbol, gen(firm_id)
xtset firm_id year

save "数据/中间数据/merged_panel_2015_2022.dta", replace

* 5. 生成论文分析样本
use "数据/中间数据/merged_panel_2015_2022.dta", clear
keep if merge_staff == 3
save "数据/分析样本/paper_analysis_sample.dta", replace

display "data cleaning complete"
