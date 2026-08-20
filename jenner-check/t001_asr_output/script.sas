/* Adapted from "00 ASR.sas" (Daily Admission Status Report).
   The %output macro is the core reporting routine of the original script:
   it builds a PROC TABULATE breakdown of applied/admitted/enrolling
   applicants by demographic group, plus a day-over-day trend table.
   The surrounding Oracle PRD connection, hist_dat snapshot logic and PDF
   mailer are site-specific and are not part of this bundle; the macro body
   itself (lines 40-59 of the original) is reproduced unmodified. Mock
   applicant-snapshot data replaces the ORACLE/outdir/hist_dat libnames. */

/* mock applicant snapshot data, shaped like the "together"/"tiers" dataset
   the original script builds from PRD + ACTSAT before calling %output */
data tiers;
  length applicant_type $10 gender $1 race $20 res_st $2 tier_designation $10 day $9;
  input day :$9. applicant_type :$10. gender :$1. race :$20. res_st :$2. tier_designation :$10. apply admit will_enter;
  datalines;
19AUG2026 Freshmen  F White             NC Tier1 1 1 1
19AUG2026 Freshmen  M Black             NC Tier1 1 1 0
19AUG2026 Freshmen  F Hispanic          SC Tier2 1 0 0
19AUG2026 Freshmen  M White             NC Tier1 1 1 1
19AUG2026 Freshmen  F Asian             VA Tier2 1 1 1
19AUG2026 Freshmen  M White             NC Tier3 1 0 0
19AUG2026 Ext_Trans F Black             NC Tier1 1 1 1
19AUG2026 Ext_Trans M White             SC Tier2 1 1 0
19AUG2026 Ext_Trans F White             NC Tier1 1 0 0
19AUG2026 Ext_Trans M Hispanic          VA Tier3 1 1 1
20AUG2026 Freshmen  F White             NC Tier1 1 1 1
20AUG2026 Freshmen  M Black             NC Tier1 1 1 1
20AUG2026 Freshmen  F Hispanic          SC Tier2 1 1 0
20AUG2026 Ext_Trans F Black             NC Tier1 1 1 1
20AUG2026 Ext_Trans M White             SC Tier2 1 0 0
;
run;

%let today_dt=20AUG2026;

proc format;
   picture mypct (round) low-high='009.99%';
run;

/***************************Macro-create output PDFs***************************/
/* unmodified from 00 ASR.sas lines 40-59 */
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

%output(Freshmen,gender race RES_ST tier_designation,);
%output(Ext_Trans,gender race RES_ST tier_designation,);
