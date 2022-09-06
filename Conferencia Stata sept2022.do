* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ *
* CONFERENCIA DE STATA - SEPT. 2022 *
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ *

* ~~~~~~~~~~~~~~~~~~~~~~~~~ *
* Franco A. Mansilla Ibáñez *
* ~~~~~~~~~~~~~~~~~~~~~~~~~ *
* www.francomansilla.com 	*	
* www.software-shop.com     *
* ~~~~~~~~~~~~~~~~~~~~~~~~~ *
* Conferencia STATA 09/2022 *
* ~~~~~~~~~~~~~~~~~~~~~~~~~ *

* ========================= *

* ~~~~~~~~~~~~~~~~~~~~~~~ *
* Definición pre-eliminar *
* ~~~~~~~~~~~~~~~~~~~~~~~ *

clear all
set more off, permanently

* Cargar BD
import delimited "/Volumes/GoogleDrive-111868847232940162537/Mi unidad/SOFTWARE-SHOP/Conferencia/09.2022 Conferencia Stata/transaction_dataset.csv", clear 

* Renombrar variables  
drop v1
ds *, varwidth(32)	

global var_all = r(varlist)

local number=1
foreach i in $var_all {
	
	rename `i' x`number'
	local ++number

}

rename x3 fraude
drop x1 x2 x49 x50	

* ~~~~~~~~~~~~~~~~~~~ *
* Análisis de la Data *
* ~~~~~~~~~~~~~~~~~~~ *

* 1. Tabulación de Fraude
tab fraude 

* 2. var_x (missing value)
misstable summarize *

* 2.1. Borrar missing value (obs. 9.841) -> (obs. 9.012)
ds fraude, not

global var_all = r(varlist)

foreach i in $var_all {

	drop if `i'==.

}

* 3. Valores unicos (vars. 47) ~> (vars. 40)
foreach i in $var_all {

	unique `i'
	
	if r(unique) <= 1 {
		drop `i'
	}

}

* ~~~~~~~~~~~~~~~~~~~~~~~~ *
* Muestra de Entrenamiento *
* ~~~~~~~~~~~~~~~~~~~~~~~~ *

splitsample, generate(muestra) split(0.75 0.25) rseed(123456)
tab fraude if muestra==1

* ~~~~~~~~~~~~~~~~~~~~~ *
* Análisis pre-modelado *
* ~~~~~~~~~~~~~~~~~~~~~ *

ds fraude muestra, not
global var_all = r(varlist)

* 1. Análisis de Discrimanación 

dcof $var_all, var_y(fraude) lvl_conf(95) sample(all_sample) sort(1)

* Top 5: x6 x5 x18 x7 x8 

* Forma grafica
twoway (histogram x6 if fraude==0, percent fcolor(%0) lcolor(black%50)) (histogram x6 if fraude==1, percent fcolor(%0) lcolor(red%50))


* 2. Filtro de Correlación (vars. 48) ~> (vars. 30)

foreach i in $var_all{

	capture{

	ds fraude muestra `i', not varwidth(32) skip(1)
	local var_x_`i' = r(varlist)

	foreach j in `var_x_`i''{

		corr `i' `j' if muestra == 1

		if abs(r(C)[2,1]) >= 0.7 {

			drop `j'
			}

	}
	}
}



* ~~~~~~~~~~~~ *
* Modelamineto *
* ~~~~~~~~~~~~ *


* Modelo: STEPWISE
ds fraude muestra, not
global var_x = r(varlist)

*stepwise, pr(0.05) pe(0.01): logit fraude $var_x if muestra==1, difficult iterate(500)

* Modelo Tradicional: Modelo Logistico
logit fraude  x1 x4 x5 x6 x7 x8 x9 x10 x11 x12 x31 x33 x16 x17 x32 x25 x26 x22 if muestra == 1, difficult iterate(500)

predict proba_logit, pr
replace proba_logit = 1 if proba_logit >=0.5
replace proba_logit = 0 if proba_logit !=1
roctab fraude proba_logit  if muestra == 1, graph summary title("Muestra Entrenamiento") name(logit_train, replace)
roctab fraude proba_logit  if muestra == 2, graph summary title("Muestra Validación") name(logit_test, replace)
graph combine logit_train logit_test, title("Modelo Logit") name(stepwise_graph, replace)


* Modelo Random Forest: sin SMOTE
rforest fraude $var_x if muestra==1, type(class) iterations(12) depth(6) seed(123456)

predict proba_rf_sps_1 proba_rf_sps_2 , pr
replace proba_rf_sps_2 = 1 if proba_rf_sps_2 >=0.5
replace proba_rf_sps_2 = 0 if proba_rf_sps_2 !=1
roctab fraude proba_rf_sps_2  if muestra == 1, graph summary title("Muestra Entrenamiento") name(rf_sps_train, replace)
roctab fraude proba_rf_sps_2  if muestra == 2, graph summary title("Muestra Validación") name(rf_sps_test, replace)
graph combine rf_sps_train rf_sps_test, title("Random Forest (sin pSMOTE)") name(rf_sps, replace)


* Aplicación de Balance: pSMOTE
tab fraude if muestra ==1

psmote $var_x, var_y(fraude) class_min(995) balance(50) sample(muestra) seed(123456)

* Modelo Random Forest: con SMOTE
rforest fraude $var_x if muestra==1, type(class) iterations(12) depth(6) seed(123456)

predict proba_rf_cps_1 proba_rf_cps_2 , pr
replace proba_rf_cps_2 = 1 if proba_rf_cps_2 >=0.5
replace proba_rf_cps_2 = 0 if proba_rf_cps_2 !=1
roctab fraude proba_rf_cps_2  if muestra == 1, graph summary title("Muestra Entrenamiento") name(rf_cps_train, replace)
roctab fraude proba_rf_cps_2  if muestra == 2, graph summary title("Muestra Validación") name(rf_cps_test, replace)
graph combine rf_cps_train rf_cps_test, title("Random Forest (con pSMOTE)") name(rf_cps, replace)



*Combinación de Gráficos
graph combine stepwise_graph rf_sps rf_cps

