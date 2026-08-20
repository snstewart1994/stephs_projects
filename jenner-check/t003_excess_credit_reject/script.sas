/* Adapted from "Excess Credit Evaluation.sas". The original is a large
   PROC SQL pulling from a dozen Oracle PeopleSoft views (grad plan,
   demographics, transfer credit, degree audit, etc.) with no local/sample
   data of its own. Two of its embedded lookup mappings are self-contained
   business logic independent of the Oracle connection: the IPEDS ethnicity
   code map used when building the "grads" table (lines 43-51), and the
   transfer-credit reject-reason code map used when building
   "course_detail" (lines 157-181). Both CASE WHEN expressions are
   reproduced unmodified below and exercised against small mock inputs
   shaped like prd.ps_nc_dnrm_stu_bio and prd.ps_trns_crse_dtl. */

/* mock demographic snapshot, shaped like prd.ps_nc_dnrm_stu_bio */
data stu_bio;
  length emplid $11 nc_ipeds_summary $1 tuition_res $1;
  input emplid $ nc_ipeds_summary $ tuition_res $;
  datalines;
E0001 1 R
E0002 3 R
E0003 5 N
E0004 8 R
E0005 6 R
E0006 2 N
E0007 9 R
;
run;

/* unmodified ethnicity mapping from lines 43-51 of the original (PROC SQL
   CASE expression, same context the original uses it in) */
proc sql;
create table grads as
select emplid, nc_ipeds_summary,
       case when nc_ipeds_summary = '1' then 'International'
            when nc_ipeds_summary = '2' then 'Unknown'
            when nc_ipeds_summary = '3' then 'Hispanic'
            when nc_ipeds_summary = '4' then 'Native American'
            when nc_ipeds_summary = '5' then 'Asian'
            when nc_ipeds_summary = '6' then 'African American'
            when nc_ipeds_summary = '7' then 'Pacific Islander'
            when nc_ipeds_summary = '8' then 'White'
            else 'Two or More'
       end as Ethnicity
from stu_bio;
quit;

proc freq data=grads;
tables Ethnicity;
run;

/* mock transfer-course detail, shaped like prd.ps_trns_crse_dtl */
data trns_crse_dtl;
  length emplid $11 reject_reason $2;
  input emplid $ reject_reason $;
  datalines;
E0001 05
E0002 06
E0003 13
E0004 17
E0005 24
E0006 61
E0007 99
;
run;

/* unmodified reject-reason mapping from lines 157-181 of the original
   (PROC SQL CASE expression, same context the original uses it in) */
proc sql;
create table course_detail as
select emplid, reject_reason,
  case when reject_reason in('05','25') then 'Grade Points out of range'
       when reject_reason in('06','26') then 'Units out of range'
       when reject_reason in('07','27') then 'Date taken out of range'
       when reject_reason='08' then 'Multi course req not met'
       when reject_reason='11' then 'Invalid Institution'
       when reject_reason='13' then 'No equivalency'
       when reject_reason='15' then 'Transfer Rule not found'
       when reject_reason='16' then 'Blank Grade'
       when reject_reason='17' then 'Technical or Remedial'
       when reject_reason='18' then 'Student Agreement found'
       when reject_reason='20' then 'No rules for course'
       when reject_reason in('30','22') then 'No rules found in table'
       when reject_reason='24' then 'Course too old'
       when reject_reason='31' then 'Blank Start Date'
       when reject_reason='33' then 'Class table record not found'
       when reject_reason='34' then 'Equiv course of WC rule not found'
       when reject_reason='35' then 'No crs_nbr match for WC rule'
       when reject_reason='61' then 'Zero score and percent'
       when reject_reason='62' then 'Test date blank'
       when reject_reason='63' then 'Negative test age'
       when reject_reason='64' then 'Test too old'
       when reject_reason='65' then 'Test date out of range'
       when reject_reason='66' then 'Score out of range'
       when reject_reason='67' then 'Percentile too low'
       when reject_reason='68' then 'Score/Percen out of range'
       else 'Unmapped'
  end as reject_reason_desc
from trns_crse_dtl;
quit;

proc print data=course_detail noobs;
var emplid reject_reason reject_reason_desc;
run;
