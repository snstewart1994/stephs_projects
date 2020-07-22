/********************************************************************************
Program: S:\RR_Data_Share\Cyclical_Production\Clearinghouse\Enrollment_Reporting\
            Combine_Summer\Combine Summer.sas

Description: Combines Summer 1 and Summer 2 to calculate overall summer status
             for upload to clearinghouse.

Input: input.Sum1_&date.         *SIS snapshot*
       input.Sum2_&date.         *SIS snapshot*
       prd.ps_STDNT_CAR_TERM     *overall unit-hours/load information*
       prd.ps_nc_stdnt_stk_vw    *plan level status information to compare to snapshot*
       prd.ps_nc_gco_vw          *graduate information*
       prd.ps_acad_plan_tbl      *Cipcodes in order to match prog_status to snapshot*

Modifications:
07.12.2018 SStewart modified to fix Error 1520. Removed 'W' status from 
  if P_STAT_DT{i}=' ' and PRG_STAT{i} not in(' ','W') then P_STAT_DT{i}="&start_date"
  to fix blank status dates associated with hardcoded 'W'. 
  Because since we added the P_STAT_DT{i}=' ' condition it will no longer be overwriting 
  W status dates.
07.13.2018 SStewart modified to fix Error 2 and Error 29.  Added new step to 
  validation to ensure no duplicates
07.13.2018 SStewart modified to fix Error 275. If graduating updates term end date.
07.16.2018 SStewart modified to fix Error 1561. Made P_STAT_DT equal to whichever 
  date is more recent (Summer1 start date, or program start date) instead of 
  summer1 start date for everyone.
07.16.2018 SStewart modified to automatically determine student's audit status.
********************************************************************************/

%let year=18;
%let term=Summer 2018;
%let start_date=20180516;*enter term begin date;
%let sum1_grad_date=20180731;*enter term end date;

%let date=%sysfunc(today(),yymmddn8.);

libname input "S:\RR_Data_Share\Cyclical_Production\Clearinghouse\Enrollment_Reporting\Combine_Summer\20&year.\input";
libname output "S:\RR_Data_Share\Cyclical_Production\Clearinghouse\Enrollment_Reporting\Combine_Summer\20&year.";

/********************Coalesce summer1 and summer2 SIS snapshots*****************/
data CLHS_MERGE;
	MERGE input.Sum1_&date. (in=a)
          input.Sum2_&date.(in=b);
	by emplid;
	/*create variables for validation*/
	if a then do;
	   ACADEMIC_LOAD_NSLC_SUM1=ACADEMIC_LOAD_NSLC;
       STATUS_DT_NSLC_SUM1=STATUS_DT_NSLC;
	end;
    if b then do;
	   ACADEMIC_LOAD_NSLC_SUM2=ACADEMIC_LOAD_NSLC;
       STATUS_DT_NSLC_SUM2=STATUS_DT_NSLC;
	end;
run;

/********************Combine SIS snapshots with other SIS data******************/
/*sums units from summer1 and summer2 for total summer hours*/
/*Gets Graduated status*/
/*Creates an entry for each plan a student is in and gets program status from 
  nc_stdnt_stk_vw to compare against snapshot*/
PROC SQL;
CREATE TABLE CLHS_MERGE2 AS
SELECT A.*, 
       case when B.ACAD_CAREER ne ' ' then B.ACAD_CAREER
            else C.ACAD_CAREER end as ACAD_CAREER, 
       SUM(B.UNT_TAKEN_PRGRSS, C.UNT_TAKEN_PRGRSS) as Summer_hours,
	   SUM(B.UNT_AUDIT, C.UNT_AUDIT) as total_audit,
       b.ACADEMIC_LOAD AS ACADEMIC_LOAD_sum1, C.ACADEMIC_LOAD AS ACADEMIC_LOAD_SUM2,
	   B.FA_LOAD AS FA_LOAD_sum1, C.FA_LOAD AS FA_LOAD_SUM2,
	   B.UNT_AUDIT as UNT_AUDIT_SUM1, C.UNT_AUDIT as UNT_AUDIT_SUM2,
	   D.NC_DEGR_CKOUT_STAT, d.strm as grad_strm, 
       substr(F.ACAD_PLAN,length(F.acad_plan)-1,1) as degree, 
       cats(substr(e.cip_code,1,2),substr(e.cip_code,4)) as cip_code_SIS,
	   F.prog_status, F.acad_plan, f.COMPLETION_TERM as status_strm
FROM CLHS_MERGE AS A
LEFT JOIN prd.ps_STDNT_CAR_TERM AS B
ON A.EMPLID=B.EMPLID AND B.STRM = "2&year.6" AND 
  (B.UNT_TAKEN_PRGRSS>=1 or B.UNT_AUDIT>=1)
LEFT JOIN prd.ps_STDNT_CAR_TERM AS C
ON A.EMPLID=C.EMPLID AND C.STRM = "2&year.7" AND 
  (C.UNT_TAKEN_PRGRSS>=1 or C.UNT_AUDIT>=1)

LEFT JOIN prd.ps_nc_stdnt_stk_vw as F
on A.EMPLID=F.EMPLID and 
   case when B.ACAD_CAREER ne ' ' then B.ACAD_CAREER
        else C.ACAD_CAREER end/*B&C.ACAD_CAREER*/=F.ACAD_CAREER 

LEFT JOIN prd.ps_nc_gco_vw as D
ON A.EMPLID=D.EMPLID and F.acad_plan=D.acad_plan and 
   case when B.ACAD_CAREER ne ' ' then B.ACAD_CAREER
        else C.ACAD_CAREER end/*B&C.ACAD_CAREER*/=D.ACAD_CAREER and 
   D.STRM in("2&year.6","2&year.7") and D.ACAD_PLAN_TYPE='MAJ' and 
   D.NC_DEGR_CKOUT_STAT='AP'

left join prd.ps_acad_plan_tbl as E
on e.acad_plan=F.acad_plan and 
   (E.EFFDT = (SELECT MAX(E_ED.EFFDT) 
               FROM prd.PS_ACAD_PLAN_TBL E_ED
               WHERE E.INSTITUTION = E_ED.INSTITUTION
                 AND E.ACAD_PLAN = E_ED.ACAD_PLAN
                 AND E_ED.EFFDT <= today()))
order by emplid;
QUIT;

/**************************Creating combined variables**************************/
data /*output.*/summer_combine&date. W_check;
set CLHS_MERGE2; 
by emplid;
if summer_hours=. then summer_hours=0;

if ACADEMIC_LOAD_NSLC='W' and summer_hours=0 then ACAD_SUMMER_STANDING='W';
if ACAD_CAREER in ('GRAD','VETM') then do;
   if SUMMER_HOURS >=9 then ACAD_SUMMER_STANDING = 'F';
   if SUMMER_HOURS >=7 and SUMMER_HOURS <=8.5  then ACAD_SUMMER_STANDING = 'Q';
   if SUMMER_HOURS >=4.5 and SUMMER_HOURS <=6.5  then ACAD_SUMMER_STANDING = 'H';
   if SUMMER_HOURS >=1 and SUMMER_HOURS <=4  then ACAD_SUMMER_STANDING = 'L';
end;
if ACAD_CAREER in ('UGRD','AGI','NDS') then do;
   if SUMMER_HOURS >=12 then ACAD_SUMMER_STANDING = 'F';
   if SUMMER_HOURS >=9 and SUMMER_HOURS <=11  then ACAD_SUMMER_STANDING = 'Q';
   if SUMMER_HOURS >=6 and SUMMER_HOURS <=8  then ACAD_SUMMER_STANDING = 'H';
   if SUMMER_HOURS >=1 and SUMMER_HOURS <=5  then ACAD_SUMMER_STANDING = 'L';
end;

/*AUDIT VALIDATION: Validate W_check. Should be all W*/
if ACAD_SUMMER_STANDING = ' ' then do;
   if TOTAL_AUDIT>0 then ACAD_SUMMER_STANDING = 'L';
   else do; 
      output W_check;
	  ACAD_SUMMER_STANDING = 'L';
   end;
end;

/*Assigning overall status the status we have calculated*/
ACADEMIC_LOAD_NSLC = ACAD_SUMMER_STANDING;

/********************************CREATING G STATUS******************************/
/*crd level to match to snapshot*/
if degree='A' then crd_lvl_SIS='02'; *associate;
else if degree='B' then crd_lvl_SIS='03'; *bachelors;
else if degree='T'/*CTG*/ then crd_lvl_SIS='04'; *post-bacc cert;
else if degree='M' then crd_lvl_SIS='05'; *masters;
else if degree='V'/*DVM*/ then crd_lvl_SIS='07'; *professional;
else if degree in('H'/*PHD*/,'E') then crd_lvl_SIS='06'; *Graduate;
else crd_lvl_SIS='99';

/*arrays*/
array crd_lvl{6} $;
array cipcode{6} $;
array prg_stat{6} $;
array prg_stat_SIS{6} $;
array P_STAT_DT{6} $;
array prg_start{6} $;

/*initializing variables*/
retain prg_stat_SIS1 prg_stat_SIS2 prg_stat_SIS3 prg_stat_SIS4 prg_stat_SIS5 prg_stat_SIS6;
if first.emplid then do i= 1 to 6;
   prg_stat_SIS{i}=' ';
end;
do i=1 to 6;
   /*if student is not currently enrolled in courses (W) then 
     (1)check SIS for grad
     (2)check SIS if they are active in program
     (3)check SIS if they are discont,cancelled,leave of abs,dismissed*/
   if cipcode{i}=cip_code_SIS and prg_stat{i}='W' and crd_lvl{i}=crd_lvl_SIS then do;
      if nc_degr_ckout_stat='AP' or prog_status='CM' then do;
         prg_stat_SIS{i}='G';
		 if grad_strm="2&year.6" or status_strm="2&year.6" then end_date="&sum1_grad_date.";
	  end;
	  else if prog_status='AC' then prg_stat{i}=ACADEMIC_LOAD_NSLC;
      else if prog_status in('DC','CN','LA','DM') then prg_stat_SIS{i}='W'; 
   end;
end;

/**********************************Fixing Dates*********************************/
BEGIN_DT = "&start_date"; 
if STATUS_DT_NSLC = ' ' then STATUS_DT_NSLC = "&date.";

/*******************************Fixing Prog level*******************************/
if last.emplid then do; *outputs a single entry per student;
   do i=1 to 6;
      /*set prog status to overall status (if prog not W)*/
      if prg_stat{i} not in (' ','W') then PRG_STAT{i} = ACADEMIC_LOAD_NSLC;
	  /*else (prog W) set prog status to SIS prog status*/
	  else if prg_stat_SIS{i} ne ' ' then PRG_STAT{i} = prg_stat_SIS{i};
	  *else prg_stat{i}=prg_stat{i};
	  /*set status date to beginning of semester or prog_start*/
	  if P_STAT_DT{i}=' ' and PRG_STAT{i} not in(' ') then P_STAT_DT{i}=max("&start_date",prg_start{i});
   end;
   /*Excluding students with PI='Y' and blank cip_code*/
   if program_indicator ne 'Y' or cipcode1 ne ' ' then output /*output.*/summer_combine&date.;
end;
run;

/******************************Fixing Overwritten W*****************************/
/*by checking status in SIS and overwriting Ws we are potentially overwriting
  correct Ws for programs with same CIPCODE. For example a student switching 
  from Chem-BA to Chem-BS.  To avoid clearinghouse error we are removing older
  program and will manually fix errors in Clearinghouse*/
/*if they had a W in snapshot*/
data W_status;
set input.sum1_&date.;
array prg_stat{6} $;
do i=1 to 6;
   if prg_STAT{I}='W' then output;
end;
run;
/*if they had a W in snapshot but no W or G in combined dataset create flag*/
proc sql;
create table W_compare as 
select unique a.*, case when b.emplid=' ' then 'N' else 'Y' end as W_comp
from summer_combine&date. as a
left join W_status as b
on a.emplid=b.emplid and
  ((b.prg_stat1='W'^=a.prg_stat1 and a.prg_stat1 ne 'G') or 
   (b.prg_stat2='W'^=a.prg_stat2 and a.prg_stat2 ne 'G') or 
   (b.prg_stat3='W'^=a.prg_stat3 and a.prg_stat3 ne 'G') or 
   (b.prg_stat4='W'^=a.prg_stat4 and a.prg_stat4 ne 'G') or 
   (b.prg_stat5='W'^=a.prg_stat5 and a.prg_stat5 ne 'G') or 
   (b.prg_stat6='W'^=a.prg_stat6 and a.prg_stat3 ne 'G'));
quit;
data output.summer_combine&date.;
set w_compare;
array cipcode{6}$;
array crd_lvl{6}$;
array prog_len{6}$;
array prg_start{6}$;
array prg_stat{6}$;
array cip_yr{6}$;
array nc_nslc_prglen_tp{6}$;
array nc_nslc_sp_prg_fl{6}$;
array p_stat_dt{6}$;

/*if student has a mismatched W then loop through to find match*/
if w_comp='Y' then do;
do i=1 to 6;
   do j=1 to 6;
      /*if match then overwrite older program info(i) with newer program info(j) 
        and blank new program(j)*/
      if cipcode{i}=cipcode{j} and crd_lvl{i}=crd_lvl{j} and prog_len{i}=prog_len{j} and i<j then do;
	     if prg_start{i}<prg_start{j} then do;
            cipcode{i}=cipcode{j};
		    crd_lvl{i}=crd_lvl{j};
		    prog_len{i}=prog_len{j};
            prg_start{i}=prg_start{j};
            prg_stat{i}=prg_stat{j};
            cip_yr{i}=cip_yr{j};
			p_stat_dt{i}=p_stat_dt{j};
            nc_nslc_prglen_tp{i}=nc_nslc_prglen_tp{j};
            nc_nslc_sp_prg_fl{i}=nc_nslc_sp_prg_fl{j};
		 end;
         cipcode{j}=' ';
		 crd_lvl{j}=' ';
		 prog_len{j}=' ';
         prg_start{j}=' ';
         prg_stat{j}=' ';
         cip_yr{j}=' ';
		 p_stat_dt{j}=' ';
         nc_nslc_prglen_tp{j}=' ';
         nc_nslc_sp_prg_fl{j}=' ';
      end;
   end;
end;
end;
run;

/***********************************VALIDATION**********************************/
/*MAKE SURE YOU HAVE TODAY'S DATE*/
data checkrun; set prd.ps_nc_clhs_hdr;
where strm in ("2&year.6","2&year.7"); 
run;

proc freq data=summer_combine&date.;
tables ACAD_SUMMER_STANDING*ACAD_CAREER;
run;
proc freq data=summer_combine&date.;
tables STATUS_DT_NSLC*ACAD_SUMMER_STANDING / norow nocol nopercent;
run;
proc freq data=summer_combine&date.;
tables PROGRAM_INDICATOR*STATUS_DT_NSLC / norow nocol nopercent;
run;

/*MAKE SURE NO DUPES*/
proc sort data=output.summer_combine&date. out=test dupout=dupes;
by emplid;
run;

/*SHOULD BE 0 OBS*/
proc sql;
create table W_CHECK2 as
select a.emplid, c.nc_reg_STatus, c.strm
from summer_combine&date. as a
left join PRD.PS_NC_SR_DNRM_TERM as c
on a.emplid=c.emplid and c.strm in ('2186','2187')
where a.ACADEMIC_LOAD_NSLC = 'W' and c.NC_REG_STATUS = '1'
order by a.emplid;
quit;

/*Check to make sure W not overwritten*/
/*W_COMPARE should have 0 obs*/
data W_status;
set input.sum1_&date.;
array prg_stat{6} $;
do i=1 to 6;
   if prg_STAT{I}='W' then output;
end;
run;
proc sql;
create table W_compare as
select a.emplid, a.cipcode1, a.prg_stat1,a.crd_lvl1, a.cipcode2, a.prg_stat2, a.crd_lvl2,
       a.cipcode3, a.prg_stat3, a.crd_lvl3, a.cipcode4, a.prg_stat4, a.crd_lvl4,
       a.cipcode5, a.prg_stat5, a.crd_lvl5,a.cipcode6, a.prg_stat6, a.crd_lvl6,
       b.cipcode1 as cipcode1_combine, b.prg_stat1 as prg_stat1_combine, b.crd_lvl1 as crd_lvl1_combine,
       b.cipcode2 as cipcode2_combine, b.prg_stat2 as prg_stat2_combine, b.crd_lvl2 as crd_lvl2_combine,
       b.cipcode3 as cipcode3_combine, b.prg_stat3 as prg_stat3_combine, b.crd_lvl3 as crd_lvl3_combine,
       b.cipcode4 as cipcode4_combine, b.prg_stat4 as prg_stat4_combine, b.crd_lvl4 as crd_lvl4_combine,
       b.cipcode5 as cipcode5_combine, b.prg_stat5 as prg_stat5_combine, b.crd_lvl5 as crd_lvl5_combine,
       b.cipcode6 as cipcode6_combine, b.prg_stat6 as prg_stat6_combine, b.crd_lvl6 as crd_lvl6_combine
from W_status as a, 
output.summer_combine&date. AS B
where a.emplid=b.emplid and 
     ((a.prg_stat1='W'^=b.prg_stat1 and b.prg_stat1 ne 'G') or 
      (a.prg_stat2='W'^=b.prg_stat2 and b.prg_stat2 ne 'G') or 
      (a.prg_stat3='W'^=b.prg_stat3 and b.prg_stat3 ne 'G') or 
      (a.prg_stat4='W'^=b.prg_stat4 and b.prg_stat4 ne 'G') or 
      (a.prg_stat5='W'^=b.prg_stat5 and b.prg_stat5 ne 'G') or 
      (a.prg_stat6='W'^=b.prg_stat6 and b.prg_stat3 ne 'G'));
quit;

/*********************************END VALIDATION********************************/

/************************************OUTPUT*************************************/
data _null_;
retain TotalFull Total3Quar TotalHalf TotalLess TotalWith TotalGrad TotalLOA 
TotalDead TotalCount;

set output.summer_combine&date. end=eof; 
file "S:\RR_Data_Share\Cyclical_Production\Clearinghouse\Enrollment_Reporting\2018\Summer\297200_&date..CLR" ;

if _n_ = 1 then do;
  TotalCount = 2; /*Number of student detail records +2 (header and trailer records included in total)*/
  TotalFull = 0;
  Total3Quar = 0;
  TotalHalf = 0;
  TotalLess = 0;
  TotalWith = 0;
  TotalGrad = 0;
  TotalLOA = 0;
  TotalDead = 0;
  /*Header record layout */
  put @1  'A3'     /*Record Type:  "A3” for enrollment data and “P3” for advanced registration data*/
      @3  '002972' /*School Code: Dept. of Education "FICE" code (OPE ID)*/
	  @9  '00'     /*Branch Code: School branch code suffix or 00, if none*/
	  @11 "&term." /*Academic Term*/
	  @26 'N'      /*Standard Report Flag: Y=Standard,N=Non-standard (early/advanced registration, summer terms, graduates only)*/
	  @27 "&date." /*Certification Date:Date enrollment data was certified by school(YYYYMMDD)*/
	  @35 'F'      /*Reporting Level: 'F'=full reporting,'A'=add records (advanced registration only)*/
;
end;

TotalCount + 1;
SELECT (ACADEMIC_LOAD_NSLC );
  when ('F') TotalFull + 1;
  when ('Q') Total3Quar + 1;
  when ('H') TotalHalf + 1;
  when ('L') TotalLess + 1;
  when ('W') TotalWith + 1;
  when ('G') TotalGrad + 1;
  when ('A') TotalLOA + 1;
  when ('D') TotalDead + 1;
  otherwise;
end;


put @1   'D1'           
    @3   NATIONAL_ID  
	@12  FIRST_NAME    
    @32  MIDDLE_INITIAL 
    @33  LAST_NAME      
    @53  NAME_SUFFIX    
	@87  ACADEMIC_LOAD_NSLC  
	@88  STATUS_DT_NSLC      
	@96  ADDRESS1       
	@126 ADDRESS2       
	@156 CITY           
	@176 STATE          
	@178 ZIP        
	@187 COUNTRY        
	@202 AGD        
	@210 DOB             
	@218 BEGIN_DT     
	@226 END_DT     
	@235 FERPA   
	@420 EMPLID 
	@470 EMAIL_ADDR
	@599 MIDDLE_NAME
	@674 PROGRAM_INDICATOR
	@675 CIPCODE1
	@681 CIP_YR1
	@685 CRD_LVL1
	@687 PROG_LEN1
	@693 NC_NSLC_PRGLEN_TP1
	@700 PRG_START1
	@708 NC_NSLC_SP_PRG_FL1
	@709 PRG_STAT1
	@710 P_STAT_DT1

	@718 CIPCODE2
	@724 CIP_YR2
	@728 CRD_LVL2
	@730 PROG_LEN2
	@736 NC_NSLC_PRGLEN_TP2
	@743 PRG_START2
	@751 NC_NSLC_SP_PRG_FL2
	@752 PRG_STAT2
	@753 P_STAT_DT2

	@761 CIPCODE3
	@767 CIP_YR3
	@771 CRD_LVL3
	@773 PROG_LEN3
	@779 NC_NSLC_PRGLEN_TP3
	@786 PRG_START3
	@794 NC_NSLC_SP_PRG_FL3
	@795 PRG_STAT3
	@796 P_STAT_DT3

	@804 CIPCODE4
	@810 CIP_YR4
	@814 CRD_LVL4
	@816 PROG_LEN4
	@822 NC_NSLC_PRGLEN_TP4
	@829 PRG_START4
	@837 NC_NSLC_SP_PRG_FL4
	@838 PRG_STAT4
	@839 P_STAT_DT4

	@847 CIPCODE5
	@853 CIP_YR5
	@857 CRD_LVL5
	@859 PROG_LEN5
	@865 NC_NSLC_PRGLEN_TP5
	@872 PRG_START5
	@880 NC_NSLC_SP_PRG_FL5
	@881 PRG_STAT5
	@882 P_STAT_DT5

	@890 CIPCODE6
	@896 CIP_YR6
	@900 CRD_LVL6
	@902 PROG_LEN6
	@908 NC_NSLC_PRGLEN_TP6
	@915 PRG_START6
	@923 NC_NSLC_SP_PRG_FL6
	@924 PRG_STAT6
	@925 P_STAT_DT6
;
/* Trailer record layout */
if EOF then do;
 put @1 'T1'             /*Record Type*/
     @3 TotalFull : z6.  /*Number of records where enrollment status = "F"*/
	 @9 Total3Quar: z6.  /*Number of records where enrollment status = "Q"*/
     @15 TotalHalf : z6. /*Number of records where enrollment status = "H"*/
     @21 TotalLess : z6. /*Number of records where enrollment status = "L"*/
	 @27 TotalWith : z6. /*Number of records where enrollment status = "W"*/
     @33 TotalGrad : z6. /*Number of records where enrollment status = "G"*/
     @39 TotalLOA : z6.  /*Number of records where enrollment status = "A"*/
     @45 '000000'        /*Fill with zeros. (Not currently used, may be in the future.)*/
     @51 TotalDead : z6. /*Number of records where enrollment status = "D"*/
	 @57 TotalCount: z8.;/*Total count equals the number of student detail records plus
                           two (the header and trailer records are included in the total)*/
;
end;
run;
