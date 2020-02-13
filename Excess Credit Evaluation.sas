/********************************************************************************
Program: S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\ 
            Excess Credit Evaluation.sas

Description: Creates a list of UGRD students who have graduated in the past year 
             with demographic and transfer credit information for analysis by 
             Belk Center for Community College Leadership & Research 

Input: prd.ps_nc_gco_plan_vw       graduation information
       prd.ps_acad_plan_tbl        cip code
       prd.ps_nc_dnrm_stu_bio      demographic info
       prd.ps_nc_dnrm_term_vw      gpa and total credit hours 
       prd.ps_NC_ADV_MSTR_TOT      units counted towards degree
       prd.PS_TRNS_CRSE_SCH        transfer credit info from NCCC school
       prd.PS_NC_NCCC_ORG_VW       NCCC School info
       prd.ps_EXT_DEGREE           Transfer degree info
       prd.ps_NC_FA_AID_VW         Pell eligibility info
       prd.PS_TRNS_CRSE_DTL        course level transfer info 
       prd.PS_NC_ADV_MSTR_DTL      degree audit info
       prd.PS_RQ_GRP_TBL           min credit hours required
       prd.PS_NC_HIST_ADMAPPL      new freshmen status

Modifications:

Notes: Since prd.PS_NC_ADV_MSTR_DTL is often missing information for students, run
       bottom validation.  If only a few students, then manually update by viewing
       their degree audit in SIS.  If several students send list to sherwood for 
       mass updates.
********************************************************************************/
libname out "S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output";

proc import datafile="B:\Documents\New_Unsaved_Query_1375.xlsx"
out=ps_NC_TCE_SCH_INFO
dbms=excel
replace;
run;

proc sql;
create table grads as 
select unique a.emplid, a.ACAD_CAREER, a.ACAD_PROG, a.ACAD_PLAN,
       case when a.acad_plan=d.acad_plan then 'Y' else 'N' end as primary_plan,
       b.NC_GENDER, b.BIRTHDATE, 
       case when b.nc_ipeds_summary = '1' then 'International'
	        when b.nc_ipeds_summary = '2' then 'Unknown'
	        when b.nc_ipeds_summary = '3' then 'Hispanic'
	        when b.nc_ipeds_summary = '4' then 'Native American'
	        when b.nc_ipeds_summary = '5' then 'Asian'
	        when b.nc_ipeds_summary = '6' then 'African American'
	        when b.nc_ipeds_summary = '7' then 'Pacific Islander'
	        when b.nc_ipeds_summary = '8' then 'White'
	        else 'Two or More'
	   end as Ethnicity, b.TUITION_RES, c.CIP_CODE, e.CUM_GPA, p.MIN_UNITS_REQD, 
       sum(e.tot_taken_gpa,e.tot_taken_nogpa) as tot_attempted, 
       e.TOT_CUMULATIVE as tot_completed, a.COMPLETION_TERM,
	   case when h.EXT_ORG_ID ne '' then 'Y' else 'N' end as NCCCS,
	   case when g.ext_org_id ne '' then 'Y' else 'N' end as Transfer,
	   case when n.emplid ne '' then 'Y' else 'N' end as New_freshmen,
	   h.descr as Trnsfr_school, g.ext_org_id, g.LS_SCHOOL_TYPE,
	   case when h.EXT_ORG_ID ne '' then sum(g.TRF_TAKEN_NOGPA,g.TRF_TAKEN_GPA) end as NCCC_transfer_accept,
	   sum(f.NC_UNT_NONDGR_TRNS,f.NC_UNT_DGR_TRNS) as tot_transfer_accept,
	   f.NC_UNT_DGR_TOT as credits_towards_degree,
	   f.NC_UNT_DGR_TRNS as trf_towards_degree,
       e.TOT_TAKEN_PRGRSS-f.NC_UNT_DGR_TOT as excess_attempted,
	   e.TOT_CUMULATIVE-f.NC_UNT_DGR_TOT as excess_earned, j.NC_EXT_AGREEMENT as CAA_Met,
	   i.degree, i.descr as degree_descr, i.FIELD_OF_STUDY_1 as degree_field,
	   k.pell_eligibility, 
       case when l.COURSE_LEVEL='RM' then 'Y' 
            when h.EXT_ORG_ID ne '' then 'N' end as NCCC_Dev_ed,
	   case when m.emplid ne '' then 'Y' else 'N' end as multiple_plan
/*grad info*/
from prd.ps_nc_gco_plan_vw as a
left join prd.ps_nc_dnrm_stu_bio as b
on a.EMPLID=b.EMPLID
/*cip code*/
left join prd.ps_acad_plan_tbl as c
on a.ACAD_PLAN=c.ACAD_PLAN and c.EFF_STATUS='A' and
   c.EFFDT=(select max(cc.EFFDT)
            from prd.ps_acad_plan_tbl as cc
			where c.ACAD_PLAN=cc.ACAD_PLAN)
/*primary plan and final enrolled term*/
left join prd.ps_nc_sr_eot_term as d
on a.EMPLID=d.EMPLID and d.acad_career=a.acad_career and 
   d.strm=(select max(dd.strm)
           from prd.ps_nc_sr_eot_term as dd
		   where d.EMPLID=dd.EMPLID and d.ACAD_CAREER=dd.ACAD_CAREER and 
                 dd.STRM<=a.COMPLETION_TERM)
/*total credits (term table still has inc & doesn't have grade exclu)*/
left join prd.ps_stdnt_car_term as e
on a.EMPLID=e.EMPLID and e.acad_career=a.acad_career and d.strm=e.strm
/*credits towards degree*/
left join prd.ps_NC_ADV_MSTR_TOT as f
on a.emplid=f.emplid and a.acad_plan=f.acad_plan
/*transfer school info*/ 
left join prd.PS_TRNS_CRSE_SCH as g
on a.emplid=g.emplid and g.SRC_INSTITUTION ne 'NCSU1' and g.LS_SCHOOL_TYPE ne 'NA'
/*nc community colleges*/
left join prd.PS_NC_NCCC_ORG_VW as h
on h.ext_org_id=g.ext_org_id
/*transfer degree info*/
left join prd.ps_EXT_DEGREE as i
on a.emplid=i.emplid and h.ext_org_id=i.ext_org_id
left join ps_NC_TCE_SCH_INFO as j
on a.emplid=j.emplid and h.ext_org_id=j.ext_org_id and j.NC_EXT_AGREEMENT='CAAM'
/*pell eligibility*/
left join prd.ps_NC_FA_AID_VW as k
on a.emplid=k.emplid and aid_year=cats('20',substr(a.COMPLETION_TERM,2,2))
/*NCCC_Dev_ed remedial flag*/
left join prd.PS_TRNS_CRSE_DTL as l
on a.emplid=l.emplid and h.ext_org_id=l.TRNSFR_SRC_ID and l.COURSE_LEVEL='RM'
/*multiple plan information*/
left join prd.ps_nc_sr_eot_prog as m
on a.emplid=m.emplid and d.strm=m.strm and a.acad_plan ne m.acad_plan and 
   m.acad_plan_type ne 'MIN'
/*New freshmen info*/
left join prd.PS_NC_HIST_ADMAPPL as n
on a.emplid=n.emplid and n.nc_hist_type='CEN' and n.admit_type in('FRD','FRI') and n.nc_enrolled='Y'
/*to get subplan info for credits required*/
left join prd.ps_nc_sr_eot_prog as o
on a.emplid=o.emplid and a.acad_plan=o.acad_plan and d.strm=o.strm and o.acad_plan_type ne 'MIN'
/*credit hours required for plan*/
left join prd.PS_RQ_GRP_TBL as p
on o.acad_plan=p.acad_plan and p.RQRMNT_LIST_SEQ=30 and p.eff_status='A' and 
   p.acad_sub_plan=(case when o.acad_sub_plan=' ' then 'NOSUBPLAN' else o.acad_sub_plan end) and 
   p.effdt=(select max(pp.effdt) 
            from prd.ps_rq_grp_tbl as pp
			where n.acad_plan=nn.acad_plan and p.acad_sub_plan=pp.acad_sub_plan and 
                  pp.RQRMNT_LIST_SEQ=30 and pp.eff_status='A')

where '2111'<=a.COMPLETION_TERM<='2187' and 
      a.NC_DEGR_CKOUT_STAT in ("AG","AP","CC","DR","CH","CP") and
	  a.ACAD_PLAN_TYPE='MAJ' and a.ACAD_CAREER='UGRD' and a.ACAD_PLAN ne '14BMJBS'
order by a.emplid, a.acad_plan, NCCCS desc;
quit;

/*Removing duplicate rows with missing transfer school*/
data overview;
set grads;
by emplid acad_plan;
/*retaining nccc transfer flag*/
retain NCCCS_Transfer;
if first.emplid then NCCCS_Transfer='N';
if NCCCS='Y' then NCCCS_Transfer='Y';
if trnsfr_school ne '' then output;
else if last.acad_plan then output;
run;

/**Adding course level information**/
proc sql;
/*transfer courses*/
create table course_detail as
select unique a.emplid, a.acad_plan, a.Trnsfr_school as school, c.subject as ncsu_subject, 
       c.catalog_nbr as ncsu_nbr, b.COMP_SUBJECT_AREA, 
       case when b.COURSE_LEVEL='RM' then 'Y' else 'N' end as NCCC_Dev_ed,
       case when substr(c.grade,1,1)='T' then 'Y'
            else 'N' end as Transfer_credit, b.articulation_term,
	   b.unt_taken, b.unt_trnsfr, b.REJECT_REASON as reject_reason_code,
	   case when b.reject_reason in('05','25') then 'Grade Points out of range'
	        when b.reject_reason in('06','26') then 'Units out of range'
			when b.reject_reason in('07','27') then 'Date taken out of range'
            when b.reject_reason='08' then 'Multi course req not met'
	        when b.reject_reason='11' then 'Invalid Institution'
			when b.reject_reason='13' then 'No equivalency'
			when b.reject_reason='15' then 'Transfer Rule not found'
			when b.reject_reason='16' then 'Blank Grade'
			when b.reject_reason='17' then 'Technical or Remedial'
			when b.reject_reason='18' then 'Student Agreement found'
			when b.reject_reason='20' then 'No rules for course'
			when b.reject_reason in('30','22') then 'No rules found in table'
			when b.reject_reason='24' then 'Course too old'
			when b.reject_reason='31' then 'Blank Start Date'
			when b.reject_reason='33' then 'Class table record not found'
			when b.reject_reason='34' then 'Equiv course of WC rule not found'
            when b.reject_reason='35' then 'No crs_nbr match for WC rule'
			when b.reject_reason='61' then 'Zero score and percent'
			when b.reject_reason='62' then 'Test date blank'
			when b.reject_reason='63' then 'Negative test age'
            when b.reject_reason='64' then 'Test too old'
			when b.reject_reason='65' then 'Test date out of range'
			when b.reject_reason='66' then 'Score out of range'
			when b.reject_reason='67' then 'Percentile too low'
			when b.reject_reason='68' then 'Score/Percen out of range' end as reject_reason,
	   case when c.RQRMNT_GROUP='999999' then 'N' else 'Y' end as Counts_toward_degree
from overview as a
inner join prd.ps_trns_crse_dtl as b
on a.emplid=b.emplid and a.ext_org_id=b.TRNSFR_SRC_ID and a.ext_org_id ne ' '
left join prd.PS_NC_ADV_MSTR_DTL as c
on a.emplid=c.emplid and a.acad_career=c.acad_career and a.acad_plan=c.acad_plan and
   b.crse_id=c.crse_id and b.ARTICULATION_TERM = c.strm and substr(c.grade,1,1)='T' 
union 
/*ncsu courses*/
select unique d.emplid, d.acad_plan, 'NCSU' as school, e.subject as ncsu_subject, e.catalog_nbr as ncsu_nbr,
       '' as COMP_SUBJECT_AREA, '' as NCCC_Dev_ed, '' as Transfer_credit, '' as articulation_term,
       e.UNT_OTHER as unt_taken, '' as unt_trnsfr, '' as reject_reason_code, '' as reject_reason,
	   case when e.RQRMNT_GROUP='999999' then 'N' else 'Y' end as Counts_toward_degree
from overview as d
left join prd.PS_NC_ADV_MSTR_DTL as e
on d.emplid=e.emplid and d.acad_career=e.acad_career and d.acad_plan=e.acad_plan and
   substr(e.grade,1,1) ne 'T' and e.NC_XSCRIPTDATA_SRC not in('REQR',' ')
order by emplid ;
quit;

/*Creating Random IDs to remove Student ID*/
/*
proc sort data=overview (keep=emplid) nodupkey
          out=emplids;
by emplid;
run;
data random_num;
set emplids;
num=ranuni(0);
run;
proc sort data=random_num;
by num;
run;
data obs_num;
set random_num;
obs+1;
run;
proc sql;
create table overview_final as 
select a.*, b.obs 
from overview as a
left join obs_num as b
on a.emplid=b.emplid;
create table course_final as 
select a.*, b.obs 
from course_detail as a
left join obs_num as b
on a.emplid=b.emplid;
quit;

data out.ID_xwalk;
set obs_num;
run;
*/
proc sql;
create table overview_final as 
select a.*, b.obs 
from overview as a
left join out.ID_xwalk as b
on a.emplid=b.emplid;
create table course_final as 
select a.*, b.obs 
from course_detail as a
left join out.ID_xwalk as b
on a.emplid=b.emplid;
quit;

proc export 
   data=overview_final
   outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\ECE_internal.xlsx"
   dbms=excel
   replace;
run;
proc export 
   data=course_final
   outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\ECE_internal.xlsx"
   dbms=excel
   replace;
run;

proc export 
   data=overview_final (drop=emplid)
   outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\Excess Credit Evaluation.csv"
   dbms=csv
   replace;
run;
proc export 
   data=course_final (drop=emplid)
   outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\Excess Credit Evaluation.csv"
   dbms=csv
   replace;
run;

/*exports list of students to be updated in ADV_MSTR table*/
/*
proc export data=overview (where=(credits_towards_degree=.))
outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\ADV_MSTR table update 20190122.xlsx"
dbms=excel
replace;
run;

proc export data=course_detail (where=((UNT_TRNSFR not in (.,0) or school='NCSU') and ncsu_subject=''))
outfile="S:\RR_Data_Share\Data Stewardship\Data Requests\Academic Performance\output\ADV_MSTR table update 20190122.xlsx"
dbms=excel
replace;
run;
*/
