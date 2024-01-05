*** PURPOSE : Consumption Analysis
  
global datafolder1 "/Users/Documents/data/raw/Wave 1"
global datafolder2 "/Users/Documents/Wave 3"
  
ssc install parmest
ssc install egen_inequal

*program to generate FPrimary
capture program drop gen_FPrimary
program define gen_FPrimary
	gen str1 leading_one="1"
	gen str_id1=string(int(id1),"%02.0f")
	gen str_id3=string(int(id3),"%03.0f")
	gen str_id4=string(int(id4),"%03.0f")
	egen FPrimary=concat(leading_one str_id1 str_id3 str_id4)
	destring FPrimary, replace
	format FPrimary %9.0f
	drop leading_one str_id1 str_id3 str_id4
	la var FPrimary "Household Number"
end 

**************************************************************************************************************

*GENERATING AND MERGING THE VARIABLES NEEDED TO ANALYSE THE SPREAD OF MONTHLY & PER CAPITA EXPENDITURE

use "$resultfolder2/aggregated_expenditure.dta", clear 
bys id1 : egen regionexpenditure = total(avg_monthly_exp_overall)
la var regionexpenditure "Total household expenditure by Region" 

*Creating hhsize
use "$datafolder2/01d_background.dta", clear  
collapse (count) hhmid, by (FPrimary)
ren hhmid hhsize
lab var hhsize "household size (no. of people in household)"
destring FPrimary,  replace
save "$resultfolder3/hhsize.dta", replace

use "$datafolder2/01d_background.dta", clear  
keep FPrimary hhmid age
destring FPrimary,  replace
save "$resultfolder3/age.dta", replace

*Merging key hhld info, hhsize and age
use "$datafolder1/key hhld info v2.dta", clear
tostring hhno, format("%09.0f") replace
rename hhno FPrimary 
destring FPrimary,  replace
merge 1:1 FPrimary using "$resultfolder3/hhsize.dta"
drop if _merge==2
drop _merge

merge 1:m FPrimary using "$resultfolder3/age.dta" 
drop if _merge!=3
drop _merge
move hhmid FPrimary

save "$resultfolder3/key_hh&ind_info", replace

*Merging key_hh&ind_info with aggregated_expenditure
merge m:1 FPrimary using  "$resultfolder2/aggregated_expenditure.dta"
drop if _merge==2
drop _merge

save "$resultfolder3/aggregated_expend_keyinfo.dta", replace 

*Dropping outliers
sum avg_monthly_exp, d
replace avg_monthly_exp=. if avg_monthly_exp<`r(p1)' | avg_monthly_exp>`r(p99)'

*Per capita expenditure
gen percapita_exp = avg_monthly_exp_overall/hhsize
la var percapita_exp "Per capita expediture by household"
sum percapita_exp, d
replace percapita_exp=. if percapita_exp<`r(p1)' | percapita_exp>`r(p99)'

*Adult equivalence per capita expenditure
gen adult_equivalence = .
*values are used from the paper http://siteresources.worldbank.org/PGLP/Resources/PMch2.pdf which says this scale was used by researchers analysing
* LSMS surveys in Ghana
replace adult_equivalence = 1 if age>17
replace adult_equivalence = 0.5 if age>12 & age<18
replace adult_equivalence = 0.3 if age>6 & age<13
replace adult_equivalence = 0.2 if age<7
la var adult_equivalence "Adult Equivalence Scale"

bys FPrimary : egen adult_eq_hhsize = total(adult_equivalence)
la var adult_eq_hhsize "Household size by adult equivalence"
gen adulteq_exp = avg_monthly_exp_overall/adult_eq_hhsize
la var adulteq_exp "Adult equivalence percapita expediture by household"
sum adulteq_exp, d

replace adulteq_exp=. if adulteq_exp<`r(p1)' | adulteq_exp>`r(p99)'

bys FPrimary: keep if _n == 1


*** converting norminal welfare measure to real values 
gen adulteq_exp_real= (adulteq_exp/218.94)*100 
lab var adulteq_exp_real "Real percapita adult equivalence expediture by household"


gen hhw =hhweight2*hhsize //creating new individual weights for wave3 due to changes in hhsize
lab var hhw "individual weights for wave 3"

*Creating poverty status variable 
*ssc install poverty
poverty adulteq_exp_real [aw= hhw], l(109.5) gen(pov_status) all 
la def pov_status 0 "Non-poor" 1 "Poor"
la val pov_status pov_status
lab var pov_status "Poverty status"

drop hhmid age 

saveold "$resultfolder2/percapita_exp_NaCPI_adjusted w3.dta", replace

*merge data sets 






