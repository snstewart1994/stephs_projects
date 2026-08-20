/* Adapted from "Combine Summer Clearinghouse.sas". The original computes an
   ACAD_SUMMER_STANDING code (F/Q/H/L/W/G) per student from summer credit
   hours, then runs the validation PROC FREQs (lines 273-281) and writes a
   fixed-column-position enrollment file for the National Student
   Clearinghouse (lines 333-457) — the same standing-code thresholds and the
   same @-column PUT layout as the original, reproduced unmodified. The
   Oracle PRD joins that assemble summer_combine&date. are site-specific and
   replaced here with a small mock dataset shaped like that table.

   One mechanical edit: the trailer PUT in the original uses the colon
   format modifier (e.g. "TotalFull : z6."); this bundle uses the equivalent
   column/format pair without the colon ("TotalFull z6.") because it hits an
   unrelated Jenner parser gap in the colon-modifier form of PUT, filed
   separately as a regression test. The column positions, formats and
   computed totals are otherwise unchanged from the original. */

data summer_combine;
  length national_id $9 first_name $20 last_name $20 middle_initial $1
         name_suffix $5 address1 $30 address2 $30 city $20 state $2 zip $10
         country $2 dob $8 begin_dt $8 end_dt $8 ferpa $1 emplid $11
         email_addr $40 middle_name $20 program_indicator $1
         acad_career $4 academic_load_nslc $1 status_dt_nslc $8;
  array summer_hours_v {1} summer_hours;
  input emplid $ national_id $ first_name $ last_name $ acad_career $ summer_hours program_indicator $;
  address1=''; address2=''; city='Raleigh'; state='NC'; zip='27607'; country='US';
  dob='19990101'; begin_dt='20260516'; end_dt='20260731'; ferpa='N';
  email_addr=cats(lowcase(first_name),'.',lowcase(last_name),'@ncsu.edu');
  middle_name=''; middle_initial=''; name_suffix='';
  status_dt_nslc='20260820';
  datalines;
E0001 100000001 Ana   Diaz    UGRD 12 N
E0002 100000002 Bao   Nguyen  UGRD 9  N
E0003 100000003 Carl  Owens   UGRD 6  N
E0004 100000004 Dina  Patel   UGRD 2  N
E0005 100000005 Eli   Ramos   GRAD 9  N
E0006 100000006 Fay   Singh   GRAD 5  N
E0007 100000007 Gus   Torres  UGRD 0  N
;
run;

/* unmodified standing thresholds from lines 111-123 of the original */
data summer_combine;
set summer_combine;
if summer_hours=. then summer_hours=0;

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
if ACAD_SUMMER_STANDING = ' ' then ACAD_SUMMER_STANDING = 'W';
ACADEMIC_LOAD_NSLC = ACAD_SUMMER_STANDING;
run;

/***********************************VALIDATION**********************************/
/* unmodified from lines 273-281 of the original */
proc freq data=summer_combine;
tables ACAD_SUMMER_STANDING*ACAD_CAREER;
run;
proc freq data=summer_combine;
tables STATUS_DT_NSLC*ACAD_SUMMER_STANDING / norow nocol nopercent;
run;
proc freq data=summer_combine;
tables PROGRAM_INDICATOR*STATUS_DT_NSLC / norow nocol nopercent;
run;

/************************************OUTPUT*************************************/
/* unmodified header/detail/trailer layout from lines 333-457 of the original,
   trimmed to the fields populated by this bundle's mock data */
%let term=Summer 2026;
%let date=20260820;
data _null_;
retain TotalFull Total3Quar TotalHalf TotalLess TotalWith TotalGrad TotalLOA
TotalDead TotalCount;

set summer_combine end=eof;
file "./output/297200_&date..CLR";

if _n_ = 1 then do;
  TotalCount = 2;
  TotalFull = 0;
  Total3Quar = 0;
  TotalHalf = 0;
  TotalLess = 0;
  TotalWith = 0;
  TotalGrad = 0;
  TotalLOA = 0;
  TotalDead = 0;
  put @1  'A3'
      @3  '002972'
	  @9  '00'
	  @11 "&term."
	  @26 'N'
	  @27 "&date."
	  @35 'F'
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
	@202 DOB
	@210 DOB
	@218 BEGIN_DT
	@226 END_DT
	@235 FERPA
	@420 EMPLID
	@470 EMAIL_ADDR
;
if EOF then do;
 put @1 'T1'
     @3 TotalFull z6.
	 @9 Total3Quar z6.
     @15 TotalHalf z6.
     @21 TotalLess z6.
	 @27 TotalWith z6.
     @33 TotalGrad z6.
     @39 TotalLOA z6.
     @45 '000000'
     @51 TotalDead z6.
	 @57 TotalCount z8.;
end;
run;

data _null_;
infile "./output/297200_&date..CLR";
input;
put _infile_;
run;
