/*******************************************************************************
Program: S:\RR_Data_Share\RR_Data_Share_New_Organization\Cyclical_Production\
            ASR\00 ASR.sas

Description: Creates and emails the Daily Admission Status Report.

Created by: SStewart 03.30.2018

Input: 01 Snapshot Create.sas
       hist_dat.asr_snapshot_&hist_date..sas7bdat

Modifications:
06.07.2018 SStewart added Spring connection file.
06.20.2018 SStewart added macros to avoid changing program every semester.
07.18.2018 SStewart modified to avoid updating date list every year.
01.14.2019 SStewart modified to create file for upload to SAS VA.
01.30.2019 SStewart modified to email Countries report to Jeong.
03.12.2019 SStewart added SAS VA link.
*******************************************************************************/

%let oraclepw=;*enter oracle PRD password;
%let email=snstewar@ncsu.edu;*enter your email address;
%let name=Stephanie Stewart;*enter your name;

/*for hardcoding hist_date; leave blank for next upcoming date in last year*/
%let histdate=;*DDMMMYYYY format;
%let histdt=;*YYYY-MM-DD format;

/****************************END USER Supplied Info****************************/
%let fall_entry=%sysfunc(today(),year2.);*fall year;
%let sprg_entry=%eval(&fall_entry.+1);*spring year;
%let hist_entry=%eval(&fall_entry.-1);*last year;

%let today=%sysfunc(date(),date9.);*today's date;
%let today_dt=%sysfunc(date(),yymmdd10.);

%let dir=S:\RR_Data_Share\Cyclical_Production\Admissions\ASR;*location of ASR code;

/***************************Macro-create output PDFs***************************/
%macro output(type, vars,where);
title "&type.";
proc tabulate;
class &vars. /s=[just=center font_size=3];
var apply admit will_enter /s=[width=2cm];
table (all='Total' &vars.),
      ((apply='Applied' admit='Admitted' will_enter='Will Enter' )*sum*F=6.
       (admit=''*pctsum<apply>='Acceptance Rate' will_enter=''*pctsum<admit>='Yield Rate')*F=mypct.);
keylabel sum=' ';
where day in("&today_dt.") and applicant_type="&type." &where.;
run;
proc tabulate data=tiers;
class day  &vars. /s=[just=center font_size=3];
var apply admit will_enter;
table (all='Total' &vars.),
      ((apply='Applied' admit='Admitted' will_enter='Will Enter')*sum*F=6.*day='') ;
keylabel sum=' ';
where applicant_type="&type." &where.;
run;
%mend;

/**********************Macro-create data and output files**********************/
%macro main;
libname PRD ORACLE path=cs920prd user=regrec pw=&oraclepw. readbuff=40000;
libname app_his "&dir.\data";
libname ACTSAT "&dir.\ACT SAT Convert";
libname outdir "&dir.\data\&admit_semester";
libname hist_dat "&dir.\data\&hist_semester";

/*calculate hist_date*/
data dates;
set app_his.dates;
if day>=intnx('year',today(),-1,'s') and semester="&hist_semester." then do;
   distance=intck('days',intnx('year',today(),-1,'s'),day);
   output;
end;
run;
proc sort data=dates;
by distance;
run;
data _null_;
set dates (obs=1);
call symputx('hist_date',put(day,date9.));
call symputx('hist_dt',put(day,yymmdd10.));
run;
%if "&histdate" ne "" %then %let hist_date=&histdate.;
%if "&histdate" ne "" %then %let hist_dt=&histdt.;
%put &hist_dt.;

/*clean raw data and save snap shot*/
%include "&dir.\01 Snapshot Create.sas";run;

/*Merge and format for output*/
data together;
set hist_dat.asr_snapshot_&hist_date. (in=a) outdir.asr_snapshot_&today. (in=b);
where admit_term in(&hist_sem. &admit_sem.) and applicant_type in('Freshmen','Ext_Trans') ;
if a then day="&hist_dt.";
else if b then day="&today_dt.";
run;
proc sql;
create table tiers as
select a.*, 
       case when c.tier_designation=. then 'Missing' 
            else Catx(' ','Tier',c.tier_designation) end as tier_designation
from together (drop=college res_st)as a
left join ACTSAT.res_code as b
on a.nc_tui_res_code=b.nc_tui_res_code
left join ACTSAT.tier as c
on b.nc_tui_res_cd_dcr=c.county;
quit;

proc format;                           
   picture mypct (round) low-high='009.99%';   
run; 

/*output data*/
ods pdf file="&dir.\PDF Output\NTR_NFR_&&admit_semester._&today..pdf";
%output(Freshmen,gender race RES_ST tier_designation college,);
%output(Ext_Trans,gender race RES_ST tier_designation college,);
ods pdf close;
ods pdf file="&dir.\PDF Output\Countries_&&admit_semester._&today..pdf";
%output(Freshmen,Country);
%output(Ext_Trans,Country);
/*CNR-only on Mondays*/
%if "%sysfunc(today(),weekday1.)"="2" %then %do; 
ods pdf file="&dir.\PDF Output\CNR_&&admit_semester._&today..pdf";
%output(Freshmen,gender race RES_ST tier_designation acad_plan, 
        and (college='CNR' or acad_plan in ('11ENVSCBS','15ENVSCBS','24ENVSCBS','31ENVSCBS') or acad_sub_plan ='14PSEI'));
%output(Ext_Trans,gender race RES_ST tier_designation acad_plan,
        and (college='CNR' or acad_plan in ('11ENVSCBS','15ENVSCBS','24ENVSCBS','31ENVSCBS') or acad_sub_plan ='14PSEI'));
ods pdf close;
%end;

/**Spring Connect**/
%if " 6"<"%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<" 9" %then %do;
proc sql;
create table spring_conn as 
select 'Spring Connect' as applicant_type, b.admit, b.will_enter, a.*
from tiers as a
inner join outdir.asr_snapshot_&today. as b
on a.emplid=b.emplid and b.admit_term=cats('2',&sprg_entry,'1')
where a.spring_defer=1 and a.apply=1 and a.admit=0
union 
select 'Spring Connect' as applicant_type, 1 as admit, c.spring_def_WE as will_enter, c.*
from tiers as c
where c.spring_defer=1;
quit;

ods pdf file="&dir.\PDF Output\SPR_CON_&today..pdf";
%output(Spring Connect, gender race RES_ST tier_designation college,);
ods pdf close;
%end;
%mend;

/***************Macro-calculate admission cycle and execute %main**************/
%macro execute;
%global admit_semester;
%let season1=Fall;
%let season2=Spring;
%if ("11"<="%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<="12") or 
     "%sysfunc(today(),month2.)"=" 1" %then %do i=1 %to 2;
   %let season=&&season&i..;
   %if &season=Spring %then %do;
      %if "%sysfunc(today(),month2.)"=" 1" %then %do;
         %let admit_sem="2&fall_entry.1";*semester;
         %let hist_sem="2&hist_entry.1";*comparison semester;
         %let hist_semester=2&hist_entry.1;
         %let admit_semester=2&fall_entry.1;
	  %end;
	  %else %do;
         %let admit_sem="2&sprg_entry.1";*semester;
         %let hist_sem="2&fall_entry.1";*comparison semester;
         %let hist_semester=2&fall_entry.1;
         %let admit_semester=2&sprg_entry.1;
	  %end;
   %end;
   %else %do;
      %if "%sysfunc(today(),month2.)"=" 1" %then %do;
         %let admit_sem="2&fall_entry.6" "2&fall_entry.7" "2&fall_entry.8";*semesters;
         %let hist_sem="2&hist_entry.6" "2&hist_entry.7" "2&hist_entry.8";*comparison semesters;
         %let hist_semester=2&hist_entry.8;
         %let admit_semester=2&fall_entry.8;
	  %end;
	  %else %do;
         %let admit_sem="2&sprg_entry.6" "2&sprg_entry.7" "2&sprg_entry.8";*semesters;
         %let hist_sem="2&fall_entry.6" "2&fall_entry.7" "2&fall_entry.8";*comparison semesters;
         %let hist_semester=2&fall_entry.8;
      %let admit_semester=2&sprg_entry.8;
	  %end;
   %end;
   %main;
%end;
%else %if "%sysfunc(today(),month2.)"<" 9" %then %do;
   /*Fall*/
   %let season=Fall;
   %let admit_sem="2&fall_entry.6" "2&fall_entry.7" "2&fall_entry.8";*semesters;
   %let hist_sem="2&hist_entry.6" "2&hist_entry.7" "2&hist_entry.8";*comparison semesters;
   %let hist_semester=2&hist_entry.8;
   %let admit_semester=2&fall_entry.8;
   %main;
%end;
%else %do; 
   /*Spring*/
   %let season=Spring;
   %let admit_sem="2&sprg_entry.1";*semester;
   %let hist_sem="2&fall_entry.1";*comparison semester;
   %let hist_semester=2&fall_entry.1;
   %let admit_semester=2&sprg_entry.1;
   %main;
%end;
%mend;
%execute;

/************************Email Reports based on Weekday************************/
OPTIONS emailsys=SMTP emailhost=smtp.ncsu.edu emailid="&email.";
%macro email;
%if "2"<="%sysfunc(today(),weekday1.)" and "%sysfunc(today(),weekday1.)"<="6" %then %do; /*Monday through Friday*/ 
FILENAME Mailbox 
EMAIL TO=('snstewar@ncsu.edu' 'ldhunt@ncsu.edu' 'jrwestov@ncsu.edu' 'aibrocke@ncsu.edu' 'blpearso@ncsu.edu'
      'jcpowell@ncsu.edu' 'sara_mackenzie@ncsu.edu' 'slwhite5@ncsu.edu' 'tjmai@ncsu.edu' 'kmringle@ncsu.edu' 
      'rlchalme@ncsu.edu' 'tahollan@ncsu.edu')
SUBJECT="ASR" 
ATTACH=(%if "11"<="%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<="12" %then %do;
           "&dir.\PDF Output\NTR_NFR_2&sprg_entry.1_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_2&sprg_entry.8_&today..pdf"
		%end;
		%else %if "%sysfunc(today(),month2.)"=" 1" %then %do;
           "&dir.\PDF Output\NTR_NFR_2&fall_entry.1_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_2&fall_entry.8_&today..pdf"
		%end;
        %else %if " 6"<"%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<" 9" %then %do;
           "&dir.\PDF Output\SPR_CON_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_&admit_semester._&today..pdf"
        %end;
		%else %do;
           "&dir.\PDF Output\NTR_NFR_&admit_semester._&today..pdf"
		%end;);
data _null_;
FILE mailbox;
PUT "Hello,";
PUT;
PUT "Attached is today's ASR.";
PUT "Let me know if you have any questions.";
PUT "https://sva74prd.oit.ncsu.edu/SASVisualAnalytics/report?location=%2FEMAS%2FSAS%20Reports%2FDashboards%2FNew%20Incoming%20Students%2FASR&type=Report.BI&section=vi296714";
PUT;
PUT "Thanks,";
PUT "&name.";
run;

FILENAME Mailbox 
EMAIL TO=('snstewar@ncsu.edu' 'jcpowell@ncsu.edu')
SUBJECT="Countries ASR" 
ATTACH=(%if "11"<="%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<="12" %then %do;
           "&dir.\PDF Output\NTR_NFR_2&sprg_entry.1_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_2&sprg_entry.8_&today..pdf"
           "&dir.\PDF Output\Countries_2&sprg_entry.1_&today..pdf"
           "&dir.\PDF Output\Countries_2&sprg_entry.8_&today..pdf"
		%end;
		%else %if "%sysfunc(today(),month2.)"=" 1" %then %do;
           "&dir.\PDF Output\NTR_NFR_2&fall_entry.1_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_2&fall_entry.8_&today..pdf"
		   "&dir.\PDF Output\Countries_2&fall_entry.1_&today..pdf"
           "&dir.\PDF Output\Countries_2&fall_entry.8_&today..pdf"
		%end;
        %else %if " 6"<"%sysfunc(today(),month2.)" and "%sysfunc(today(),month2.)"<" 9" %then %do;
           "&dir.\PDF Output\SPR_CON_&today..pdf"
           "&dir.\PDF Output\NTR_NFR_&admit_semester._&today..pdf"
		   "&dir.\PDF Output\Countries_&admit_semester._&today..pdf"
        %end;
		%else %do;
           "&dir.\PDF Output\NTR_NFR_&admit_semester._&today..pdf"
		   "&dir.\PDF Output\Countries_&admit_semester._&today..pdf"
		%end;);
data _null_;
FILE mailbox;
PUT "Hello,";
PUT;
PUT "Attached is today's ASR.";
PUT "Let me know if you have any questions.";
PUT "https://sva74prd.oit.ncsu.edu/SASVisualAnalytics/report?location=%2FEMAS%2FSAS%20Reports%2FDashboards%2FNew%20Incoming%20Students%2FASR&type=Report.BI&section=vi296714";
PUT;
PUT "Thanks,";
PUT "&name.";
run;
%end;

%if "%sysfunc(today(),weekday1.)"="2" %then %do; /*Monday*/
FILENAME Mailbox 
EMAIL TO=('snstewar@ncsu.edu' 'tiffany_mcclean@ncsu.edu')
SUBJECT="CNR ASR" 
ATTACH=(%if "11"<="%sysfunc(today(),month2.)"<="12" %then %do;
           "&dir.\PDF Output\CNR_2&sprg_entry.1_&today..pdf"
           "&dir.\PDF Output\CNR_2&sprg_entry.8_&today..pdf"
		%end;
		%else %if "%sysfunc(today(),month2.)"=" 1" %then %do;
           "&dir.\PDF Output\CNR_2&fall_entry.1_&today..pdf"
           "&dir.\PDF Output\CNR_2&fall_entry.8_&today..pdf"
		%end;
		%else %do;
           "&dir.\PDF Output\CNR_&admit_semester._&today..pdf"
		%end;);
data _null_;
FILE mailbox;
PUT "Hello,";
PUT;
PUT "Attached is today's ASR.";
PUT "Let me know if you have any questions.";
PUT;
PUT "Thanks,";
PUT "&name.";
run;
%end;
%mend;
%email;
