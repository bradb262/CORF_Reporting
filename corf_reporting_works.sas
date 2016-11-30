
/*Name the file location where you are pulling your data from. This will be the same file that your output is saved to.*/

/*Identify the file directory here:*/
/*Replace the information between "filename indata pipe 'dir" and "/b';" */
/*Each level of the path should be in "".*/
/* Example: filename indata pipe 'dir W:\"Sampling"\"MI"\"Smith" /b '; */
filename indata pipe 'dir W:\"_WORK_ANALYST"\"J5A_CORF_rpting_RH-BB_041715" /b '; 

/*Identify the file path here:*/
/*Replace the information after: "%let pull_folder=" with your file path. No quotes are needed */
/* Example: %let pull_folder=W:\Sampling\MI\Smith; */
%let pull_folder=W:\_WORK_ANALYST\J5A_CORF_rpting_RH-BB_041715;

/*Data import*/
proc import out=work.corf_data
			DATAFILE= "&pull_folder.\J5A CORF 041715.xlsx"
            dbms=XLSX REPLACE;
run;


/* Summarizing By Provider Data */
proc sql;
	CREATE TABLE provider AS
	select distinct(BP_Billing_Prov_Num_OSCAR) as Oscar_Num, COUNT (distinct  Bene_Claim_HIC_Num)AS HIC_Count,COUNT (distinct CH_ICN) AS ICN_Count, sum(clf_amt_paid) AS Amt_Paid_Tot, FP_Facility_Provider_Master_Name as Facility_Name
	FROM corf_data
	GROUP BY BP_Billing_Prov_Num_OSCAR;
	quit;
/* Extract the month of year from the CHD_From_Date*/
data corf_data1;
set corf_data; CHD_From_Date2= DATEPART(CHD_Claim_From_Date);
month=month(CHD_From_Date2);
Rev_Cd_Desc= catx("-", of CLI_Revenue_Cd_Category_Cd CLI_Revenue_Cd_Category_Cd_Desc);
run;
/*order data by month ascending order */
proc sql;
CREATE TABLE corf_data1_sorted as
select *
FROM corf_data1
ORDER BY month;
run;






/*For each Oscar number generate two tables-provider breakout by TOB and by Revenue Code*/

%macro runtab(x);

/*Provider Breakout by TOB for Paid Claims*/
/*First create table of providers and a distinct ICN Count, also bringing in type of bill, facility name, and a sum of amount Medicare paid*/
	proc sql;
	CREATE TABLE  prov_&x AS
	select distinct BP_Billing_Prov_Num_OSCAR AS Prov_ID, CHI_TOB_TYPE_OF_BILL_Cd AS TOB_Desc, COUNT (distinct CH_ICN)AS ICN_COUNT, SUM (CLF_AMT_PAID) AS Payment, FP_Facility_Provider_Master_Name AS Facility
	FROM corf_data 
	WHERE BP_Billing_Prov_Num_OSCAR = &x
	GROUP BY CHI_TOB_TYPE_OF_BILL_Cd;
	quit;

/*This table takes the first table and re-formats the payment to dollar format and creates a percent of total column for the percent each TOP contributes to the total*/
proc sql;
	CREATE TABLE prov_&x AS
	select *, SUM (Payment) AS Total FORMAT DOLLAR9.2,
 (100*Payment/CALCULATED TOTAL)
AS TOTAL FORMAT=5.2 AS PCT
 FROM prov_&x;
 quit;



/*Provider Breakout by Revenue Code (Beneficiaries can have more than one revenue service per claim)*/
	proc sql;
	CREATE TABLE prov_revCD_&x AS
	select distinct BP_Billing_Prov_Num_OSCAR AS Prov_ID, CLI_REVENUE_Cd_Category_Cd AS Rev_Cd , COUNT (distinct BENE_CLAIM_HIC_Num)AS HIC_COUNT, SUM (CLF_AMT_PAID) AS Payment
	FROM corf_data 
	WHERE BP_Billing_Prov_Num_OSCAR = &x
	GROUP BY CLI_REVENUE_Cd_Category_Cd;
	quit;


proc sql;
	CREATE TABLE prov_revCD_&x AS
	select *, SUM (Payment) AS Total FORMAT DOLLAR9.2,
 (100*Payment/CALCULATED TOTAL)
AS TOTAL FORMAT=5.2 AS PCT
 FROM prov_revCD_&x;
 quit;


 /*Create summary chart for generating graph of codes billed per month by Revenue Code*/
proc sql;
CREATE TABLE summary_&x AS
select DISTINCT month, COUNT (CH_ICN) AS ICN_Count, CLI_Revenue_Cd_Category_Cd, SUM(CLF_AMT_PAID) AS Amount_Paid
 FROM corf_data1_sorted
 WHERE BP_Billing_Prov_Num_OSCAR=&x
 group by month ,CLI_Revenue_Cd_Category_Cd;
 run;
/*************************************************************************/
/* DEFINE STYLES TEMPLATE WHICH DICTATES FORMATTING OF FINAL Report       */
/* 06/04/2015 BMB                                                                                      */
/*************************************************************************/
/* Create chart template corf_graphs template */
proc template;
 define statgraph corf_graphs;
  begingraph;
  entrytitle "CORF Services and Revenue Analysis";
  
    layout lattice / columns=2 ;
     layout overlay / cycleattrs=true;
barchart x=month y=Amount_Paid /
                     stat=sum
                     name="Amount Paid for Revenue Cds Per Month"
               group=CLI_Revenue_Cd_Category_Cd name="Rev_Cd";
			   discretelegend "Rev_Cd"/title="Rev_Cd:";
endlayout;
     layout overlay / cycleattrs=true;
       barchart x=month y=ICN_Count /
                     stat=sum
                     name="ICN Count for Revenue Cds Per Month"
               group=CLI_Revenue_Cd_Category_Cd name="Rev_Cd";
			   discretelegend "Rev_Cd"/title="Rev_Cd:";
endlayout;
     sidebar / align=top;	
     endsidebar;
     rowaxes;
       rowaxis / display=(tickvalues)
        displaysecondary=(tickvalues) griddisplay=on;
     endrowaxes;	   
    endlayout;
  endgraph;
 end;
run;





%mend runtab;



/*Create a macro variable of all the oscar codes */
proc sql noprint;
	select BP_Billing_Prov_Num_OSCAR
	into :varlist separated by ' ' /*Each OSCAR code in the list is sep. by a single space*/
from provider;
quit;

%let cntlist = &sqlobs; /*Store a count of the number of oscar codes*/
%put &varlist; /*Print the codes to the log to be sure our list is accurate*/

ods tagsets.rtf file="W:\Brad_Belfiore\test2014b.doc" style=sasdocprinter ;

/*goptions reset=goptions device=png target=png*/
/*         xmax=3 in ymax=5 in*/
/*         xpixels=1400 ypixels=1800*/
/*         ftext=swiss ftitle=swiss;*/



/*ods tagsets.rtf /*startpage=never; /*options(sheet_interval='none' sheet_name="&x");*/
/*Generate an overall summary document*/

ods escapechar="~"; /*Define the escape character*/

/*Name document*/
/*filename _rtf_*/
/*"&pull_folder.\CORFSummary.doc";*/

/*ods rtf file=_rtf_ */
/*ods rtf style=journal  /*Defined in Step 1 above;*/*/
/*options papersize = A4 */

/*Document title*/
title1 j=C COLOR=BLACK BOLD HEIGHT=10 "CORF Report Summary";

/*Save today's date as the run date in a macro variable=run_date*/
%let run_date=%sysfunc(date(),worddate.);

/*Include the date the report was run*/
title2 j=C "Evaluation performed on: &run_date";

ODS TEXT="Statement of Work C.5.15.2 Review of Comprehensive Outpatient Rehabilitation Facility Billing Records." ;
/*ods text="~{newline(1)}";/*Adds line of blank space. ~ is the escape character defined above*/
ODS TEXT ="The contractor shall review Comprehensive Outpatient Rehabilitation Facility (CORF) billing records and the Contractor shall immediately advise CMS of aberrant billing.";
/*ods text="~{newline(2)}";/*Adds line of blank space. ~ is the escape character defined above*/
ODS TEXT="IOM 100-02 - Medicare Benefit Policy Manual - Chapter 12 states:  The purpose of a CORF is to permit the beneficiary to receive multidisciplinary rehabilitation services at a single location in a coordinated fashion." ;
ODS TEXT="Statement of Work C.5.15.2 Review of Comprehensive Outpatient Rehabilitation Facility Billing Records." ;


proc report data=provider nowd;
title 'CORF Providers';
column _ALL_;
run;
/*write a macro to generate the output tables*/
%macro output(x);



proc print data=prov_&x;
run;


proc print data=prov_revCD_&x;
run;



/*Create a graph of Units of Services Per Month and group by the Revenue Code*/
ods graphics on / height=255px width=550px;
proc sgrender data=summary_&x template=corf_graphs;
run;
ods graphics on / reset=all;






%mend;


/*Run a loop for each oscar code. Each code will enter the document generation loop*/
%macro loopit(mylist);
    %let else=;
   %let n = %sysfunc(countw(&mylist)); /*let n=number of codes in the list*/
    data 
   %do I=0 %to &n;
      %let val = %scan(&mylist,&I); /*Let val= the ith code in the list*/
    %end;

   %do j=0 %to &n;
      %let val = %scan(&mylist,&j); /*Let val= the jth code in the list*/
/*Run the macro loop to generate the required tables*/
ods tagsets.rtf startpage=NOW;
%runtab(&val);


%output(&val);
  ods tagsets.rtf startpage=NO;

   %end;
   run;
%mend;






%loopit(&varlist)



ods tagsets.rtf close;
/*Run the macro loop over the list of significant procedure code values*/





