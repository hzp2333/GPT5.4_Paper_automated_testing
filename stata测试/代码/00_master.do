clear all
set more off

cd "f:/桌面/stata测试"

do "代码/01_data_cleaning.do"
do "代码/02_paper_analysis.do"

display "master workflow complete"
