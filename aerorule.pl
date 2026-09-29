/*  AeroRule - a small rule-based advisor for basic US flight-rule legality
    ------------------------------------------------------------------------
    Assignment 2 (Expert Systems), University of Moratuwa.

    What it does
      Takes the facts of a planned flight (airspace, weather, fuel ...) and
      says whether the flight is legal to depart under the parts of
      14 CFR Part 91 that are modelled here (VFR minimums, Special VFR,
      IFR alternate airport, fuel reserves).

    Two ways to run it
      1. Forward chaining  - answer the questions, the engine fires every
                             rule it can and prints a full explanation.
      2. Backward chaining - pick a question ("is an alternate required?"),
                             the engine works backwards and only asks for
                             the facts it needs to prove it.

    How to start:   ?- main.        (menu; answers are typed one per line)
                    ?- run_tests.   (automatic tests, no typing needed)

    Every rule carries the exact paragraph of the regulation it came from,
    and RULES.md lists the eCFR link for each one. This is an educational
    project. Do not use it to plan a real flight.

    Scope: airplanes only (no helicopters), no Alaska sunrise clause.
*/

:- dynamic fact/2, derived/3, shown/1, covered/1, no_questions/0.

:- initialization(format("~nAeroRule loaded. Type  main.  to start, or  run_tests.  to run the tests.~n")).


%% ========================================================================
%%  PART 1 - INPUT QUESTIONS (the "facts" we can ask the user for)
%% ========================================================================
%  input(Name, Group, AnswerType, AskOnlyIf, Prompt, WhyWeAsk)
%  Groups are asked in this order: base, svfr, ifr, alt, fuel.
%  AskOnlyIf uses the same little condition language as the rules.

input(flight_rules, base, oneof([vfr,ifr]), [],
      'Are you flying under VFR or IFR?  (vfr / ifr)',
      'VFR flights are checked against the weather minimums, IFR flights against the alternate-airport and fuel rules.').

input(airspace_class, base, oneof([a,b,c,d,e,g]), [fact(flight_rules,vfr)],
      'Which airspace class are you in?  (a / b / c / d / e / g)',
      'The VFR weather minimums in 14 CFR 91.155 are different for every airspace class.').

input(altitude_msl_ft, base, number(-1500,60000), [fact(flight_rules,vfr)],
      'Altitude in feet above mean sea level (MSL)?',
      'Class E and Class G minimums change at 10,000 ft MSL, and Special VFR is only allowed below 10,000 ft MSL.').

input(altitude_agl_ft, base, number(0,60000), [fact(flight_rules,vfr), fact(airspace_class,g)],
      'Height in feet above the ground (AGL)?',
      'Class G has separate minimums at or below 1,200 ft AGL and above it.').

input(night, base, oneof([yes,no]), [fact(flight_rules,vfr)],
      'Is it night (after the end of evening civil twilight, before the start of morning civil twilight)?  (yes / no)',
      'Class G minimums and the VFR fuel reserve are different by day and by night.').

input(in_surface_area, base, oneof([yes,no]),
      [fact(flight_rules,vfr),
       any([[fact(airspace_class,b)],[fact(airspace_class,c)],[fact(airspace_class,d)],[fact(airspace_class,e)]])],
      'Are you inside the surface area of controlled airspace that belongs to an airport?  (yes / no)',
      'The 1,000 ft ceiling rule, the 3 SM ground-visibility rule and Special VFR only apply inside a surface area.').

input(takeoff_landing, base, oneof([yes,no]), [fact(flight_rules,vfr), fact(in_surface_area,yes)],
      'Are you taking off, landing or entering the traffic pattern?  (yes / no)',
      '14 CFR 91.155(d) and 91.157(c) check ground visibility only for takeoff, landing and the traffic pattern.').

input(flight_visibility_sm, base, number(0,100), [fact(flight_rules,vfr)],
      'Flight visibility in statute miles?',
      'It is compared with the visibility required for your airspace class.').

input(ceiling_ft, base, number_or_none(0,60000,99999), [fact(flight_rules,vfr), fact(in_surface_area,yes)],
      'Cloud ceiling in feet above the ground?  (type none if there is no ceiling)',
      '14 CFR 91.155(c) does not allow VFR under a ceiling lower than 1,000 ft in a surface area.').

input(ground_visibility_reported, base, oneof([yes,no]),
      [fact(flight_rules,vfr), fact(in_surface_area,yes), fact(takeoff_landing,yes)],
      'Does the airport report ground visibility?  (yes / no)',
      'If ground visibility is not reported, the rules fall back to flight visibility.').

input(ground_visibility_sm, base, number(0,100), [fact(ground_visibility_reported,yes)],
      'Reported ground visibility in statute miles?',
      'It is used for the 3 SM check (VFR) and the 1 SM check (Special VFR).').

input(in_clouds, base, oneof([yes,no]), [fact(flight_rules,vfr)],
      'Are you flying in cloud right now?  (yes / no)',
      'Every VFR minimum requires you to stay clear of clouds.').

input(dist_below_cloud_ft, base, number_or_none(0,99999,99999), [fact(flight_rules,vfr), fact(in_clouds,no)],
      'Vertical distance in feet between you and the nearest cloud ABOVE you?  (none if no cloud above)',
      'Compared with the required distance below clouds.').

input(dist_above_cloud_ft, base, number_or_none(0,99999,99999), [fact(flight_rules,vfr), fact(in_clouds,no)],
      'Vertical distance in feet between you and the nearest cloud BELOW you?  (none if no cloud below)',
      'Compared with the required distance above clouds.').

input(dist_horizontal_cloud_ft, base, number_or_none(0,99999,99999), [fact(flight_rules,vfr), fact(in_clouds,no)],
      'Horizontal distance in feet to the nearest cloud?  (none if no cloud nearby)',
      'Compared with the required horizontal distance from clouds.').

% ---- asked only when Special VFR turns out to be possible ----

input(between_sunrise_sunset, svfr, oneof([yes,no]), [],
      'Is it between sunrise and sunset?  (yes / no)',
      '14 CFR 91.157(b)(4): Special VFR at night needs extra qualifications.').

input(airport_svfr_prohibited, svfr, oneof([yes,no]), [],
      'Is this airport one where Special VFR is prohibited (Appendix D, section 3)?  (yes / no)',
      '14 CFR 91.157(a) excludes the airports listed in Appendix D section 3.').

input(atc_svfr_clearance, svfr, oneof([yes,no]), [],
      'Do you have a Special VFR clearance from ATC?  (yes / no)',
      '14 CFR 91.157(b)(1): Special VFR only with an ATC clearance.').

input(pilot_instrument_qualified, svfr, oneof([yes,no]), [fact(between_sunrise_sunset,no)],
      'Does the pilot meet the Part 61 requirements for instrument flight?  (yes / no)',
      '14 CFR 91.157(b)(4)(i): needed for Special VFR outside sunrise-sunset.').

input(aircraft_ifr_equipped, svfr, oneof([yes,no]), [fact(between_sunrise_sunset,no)],
      'Is the aircraft equipped for IFR as required by 91.205(d)?  (yes / no)',
      '14 CFR 91.157(b)(4)(ii): needed for Special VFR outside sunrise-sunset.').

% ---- IFR destination ----

input(dest_has_std_iap, ifr, oneof([yes,no]), [fact(flight_rules,ifr)],
      'Does the destination have a published standard instrument approach?  (yes / no)',
      '14 CFR 91.169(b)(1): the "no alternate" exception only works if there is an approach.').

input(dest_fcst_ceiling_ft, ifr, number_or_none(0,60000,99999), [fact(flight_rules,ifr)],
      'Lowest forecast ceiling (ft above airport elevation) from 1 hour before to 1 hour after your ETA?  (none if unlimited)',
      'Part of the 1-2-3 test in 14 CFR 91.169(b)(2)(i).').

input(dest_fcst_vis_sm, ifr, number(0,100), [fact(flight_rules,ifr)],
      'Lowest forecast visibility (SM) from 1 hour before to 1 hour after your ETA?',
      'Part of the 1-2-3 test in 14 CFR 91.169(b)(2)(i).').

% ---- alternate airport (only asked if an alternate is required) ----

input(alt_iap_type, alt, oneof([precision,nonprecision,none]), [],
      'What instrument approach does your alternate have?  (precision / nonprecision / none)',
      '14 CFR 91.169(c) sets different alternate minimums for each case.').

input(alt_published, alt, oneof([yes,no]),
      [any([[fact(alt_iap_type,precision)],[fact(alt_iap_type,nonprecision)]])],
      'Does the approach procedure publish its own alternate minimums?  (yes / no)',
      '14 CFR 91.169(c)(1)(i): published alternate minimums come first, the standard ones apply only if none are specified.').

input(alt_pub_ceiling_ft, alt, number(0,60000), [fact(alt_published,yes)],
      'Published alternate ceiling minimum (ft)?',
      'Used as the required ceiling at the alternate.').

input(alt_pub_vis_sm, alt, number(0,100), [fact(alt_published,yes)],
      'Published alternate visibility minimum (SM)?',
      'Used as the required visibility at the alternate.').

input(alt_fcst_ceiling_ft, alt, number_or_none(0,60000,99999),
      [any([[fact(alt_iap_type,precision)],[fact(alt_iap_type,nonprecision)]])],
      'Forecast ceiling at the alternate at your ETA there (ft)?  (none if unlimited)',
      'Compared with the alternate minimum.').

input(alt_fcst_vis_sm, alt, number(0,100),
      [any([[fact(alt_iap_type,precision)],[fact(alt_iap_type,nonprecision)]])],
      'Forecast visibility at the alternate at your ETA there (SM)?',
      'Compared with the alternate minimum.').

input(alt_forecast_basic_vfr, alt, oneof([yes,no]), [fact(alt_iap_type,none)],
      'Does the forecast at the alternate allow descent, approach and landing under basic VFR?  (yes / no)',
      '14 CFR 91.169(c)(2): with no published approach the basic VFR minimums apply.').

% ---- fuel ----

input(fuel_to_dest_min, fuel, number(0,3000), [],
      'Flying time to the destination, in minutes?',
      'Fuel rules are written as flying time at normal cruise.').

input(fuel_dest_to_alt_min, fuel, number(0,3000), [fact(flight_rules,ifr), fact(alternate,required)],
      'Flying time from the destination to the alternate, in minutes?',
      '14 CFR 91.167(a)(2): IFR fuel must cover the leg to the alternate when one is required.').

input(fuel_onboard_min, fuel, number(0,3000), [],
      'How many minutes of flying can your fuel on board give you, at normal cruise?',
      'Compared with the fuel you are required to have.').


%% ------------------------------------------------------------------------
%%  Where the knowledge comes from
%% ------------------------------------------------------------------------
%  regulation(Short, Title, Link)   - the pages the 30 rules were read from

regulation('14 CFR 91.135', 'Operations in Class A airspace',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRe4c59b5f5506932/section-91.135').
regulation('14 CFR 91.151', 'Fuel requirements for flight in VFR conditions',
    'https://www.law.cornell.edu/cfr/text/14/91.151').
regulation('14 CFR 91.155', 'Basic VFR weather minimums',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFR4d5279ba676bedc/section-91.155').
regulation('14 CFR 91.157', 'Special VFR weather minimums',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFR4d5279ba676bedc/section-91.157').
regulation('14 CFR 91.167', 'Fuel requirements for flight in IFR conditions',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRef6e8c57f580cfd/section-91.167').
regulation('14 CFR 91.169', 'IFR flight plan: information required (alternate airport)',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRef6e8c57f580cfd/section-91.169').
regulation('14 CFR 1.1', 'Definitions (meaning of "night")',
    'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-A/part-1').


%% ========================================================================
%%  PART 2 - THE 30 RULES (the knowledge base)
%% ========================================================================
%  rule(ID, Name, Source, Conditions, Conclusion)
%  A rule with two "alternative" bodies is written twice with the same ID.
%
%  Condition language:
%     fact(N,V)    N = V is known          no(N,V)   no such fact is known
%     lt/le/gt/ge/eq(A,B)   comparisons    calc(X,Expr)   X is Expr
%     any([[..],[..]])      one of the listed condition groups holds
%     surface_class         airspace is Class B, C, D or E
%
%  Rules are listed in layers (low to high). When two rules could fire, the
%  earlier one in the file goes first, so the verdict rules (last) only fire
%  when everything below them has already been worked out.

% ----- Layer 1: airspace class A ------------------------------------------

rule(r01, 'VFR is not allowed in Class A', '14 CFR 91.135 (opening paragraph)',
     [fact(flight_rules,vfr), fact(airspace_class,a)],
     fact(violation, class_a_requires_ifr)).

% ----- Layer 2: which VFR minimum applies (91.155(a) table) ----------------
%  Conclusion: vfr_minimum = min(Visibility_SM, Below_ft, Above_ft, Horizontal_ft)
%  "Clear of clouds" is written as 0,0,0.  1 statute mile = 5280 ft.

rule(r02, 'VFR minimum, Class B', '14 CFR 91.155(a) table, Class B',
     [fact(flight_rules,vfr), fact(airspace_class,b)],
     fact(vfr_minimum, min(3,0,0,0))).

rule(r03, 'VFR minimum, Class C', '14 CFR 91.155(a) table, Class C',
     [fact(flight_rules,vfr), fact(airspace_class,c)],
     fact(vfr_minimum, min(3,500,1000,2000))).

rule(r04, 'VFR minimum, Class D', '14 CFR 91.155(a) table, Class D',
     [fact(flight_rules,vfr), fact(airspace_class,d)],
     fact(vfr_minimum, min(3,500,1000,2000))).

rule(r05, 'VFR minimum, Class E below 10,000 ft MSL', '14 CFR 91.155(a) table, Class E less than 10,000 ft MSL',
     [fact(flight_rules,vfr), fact(airspace_class,e), fact(altitude_msl_ft,M), lt(M,10000)],
     fact(vfr_minimum, min(3,500,1000,2000))).

rule(r06, 'VFR minimum, Class E at or above 10,000 ft MSL', '14 CFR 91.155(a) table, Class E at or above 10,000 ft MSL',
     [fact(flight_rules,vfr), fact(airspace_class,e), fact(altitude_msl_ft,M), ge(M,10000)],
     fact(vfr_minimum, min(5,1000,1000,5280))).

rule(r07, 'VFR minimum, Class G day, 1,200 ft AGL or less', '14 CFR 91.155(a) table, Class G 1,200 ft or less above the surface, day',
     [fact(flight_rules,vfr), fact(airspace_class,g), fact(altitude_agl_ft,H), le(H,1200), fact(night,no)],
     fact(vfr_minimum, min(1,0,0,0))).

rule(r08, 'VFR minimum, Class G night, 1,200 ft AGL or less', '14 CFR 91.155(a) table, Class G 1,200 ft or less above the surface, night',
     [fact(flight_rules,vfr), fact(airspace_class,g), fact(altitude_agl_ft,H), le(H,1200), fact(night,yes)],
     fact(vfr_minimum, min(3,500,1000,2000))).

rule(r09, 'VFR minimum, Class G day, above 1,200 ft AGL and below 10,000 ft MSL', '14 CFR 91.155(a) table, Class G more than 1,200 ft above the surface but less than 10,000 ft MSL, day',
     [fact(flight_rules,vfr), fact(airspace_class,g), fact(altitude_agl_ft,H), gt(H,1200),
      fact(altitude_msl_ft,M), lt(M,10000), fact(night,no)],
     fact(vfr_minimum, min(1,500,1000,2000))).

rule(r10, 'VFR minimum, Class G night, above 1,200 ft AGL and below 10,000 ft MSL', '14 CFR 91.155(a) table, Class G more than 1,200 ft above the surface but less than 10,000 ft MSL, night',
     [fact(flight_rules,vfr), fact(airspace_class,g), fact(altitude_agl_ft,H), gt(H,1200),
      fact(altitude_msl_ft,M), lt(M,10000), fact(night,yes)],
     fact(vfr_minimum, min(3,500,1000,2000))).

rule(r11, 'VFR minimum, Class G above 1,200 ft AGL and at or above 10,000 ft MSL', '14 CFR 91.155(a) table, Class G more than 1,200 ft above the surface and at or above 10,000 ft MSL',
     [fact(flight_rules,vfr), fact(airspace_class,g), fact(altitude_agl_ft,H), gt(H,1200),
      fact(altitude_msl_ft,M), ge(M,10000)],
     fact(vfr_minimum, min(5,1000,1000,5280))).

% ----- Layer 3: violations -------------------------------------------------

rule(r12, 'Flight visibility is below the VFR minimum', '14 CFR 91.155(a)',
     [fact(flight_rules,vfr), fact(vfr_minimum, min(RV,_,_,_)), fact(flight_visibility_sm,F), lt(F,RV)],
     fact(violation, visibility_below_minimum)).

rule(r13, 'Too close to clouds for the VFR minimum', '14 CFR 91.155(a)',
     [fact(flight_rules,vfr), fact(vfr_minimum, min(_,RB,RA,RH)),
      any([[fact(in_clouds,yes)],
           [fact(in_clouds,no), fact(dist_below_cloud_ft,Db), lt(Db,RB)],
           [fact(in_clouds,no), fact(dist_above_cloud_ft,Da), lt(Da,RA)],
           [fact(in_clouds,no), fact(dist_horizontal_cloud_ft,Dh), lt(Dh,RH)]])],
     fact(violation, cloud_clearance)).

rule(r14, 'Ceiling below 1,000 ft in a surface area', '14 CFR 91.155(c)',
     [fact(flight_rules,vfr), surface_class, fact(in_surface_area,yes), fact(ceiling_ft,C), lt(C,1000)],
     fact(violation, surface_ceiling_below_1000)).

rule(r15, 'Airport visibility below 3 SM for takeoff, landing or pattern', '14 CFR 91.155(d)(1) and (d)(2)',
     [fact(flight_rules,vfr), surface_class, fact(in_surface_area,yes), fact(takeoff_landing,yes),
      any([[fact(ground_visibility_reported,yes), fact(ground_visibility_sm,G), lt(G,3)],
           [fact(ground_visibility_reported,no), fact(flight_visibility_sm,F), lt(F,3)]])],
     fact(violation, surface_visibility_below_3)).

% ----- Layer 4: Special VFR ------------------------------------------------

rule(r16, 'Special VFR could be requested', '14 CFR 91.157(a)',
     [fact(flight_rules,vfr), surface_class, fact(in_surface_area,yes), fact(altitude_msl_ft,M), lt(M,10000),
      any([[fact(violation,visibility_below_minimum)],
           [fact(violation,cloud_clearance)],
           [fact(violation,surface_ceiling_below_1000)],
           [fact(violation,surface_visibility_below_3)]])],
     fact(svfr, possible)).

rule(r17, 'Special VFR authorised (daytime)', '14 CFR 91.157(a), (b)(1), (b)(2), (b)(3), (b)(4)',
     [fact(svfr,possible), fact(airport_svfr_prohibited,no), fact(atc_svfr_clearance,yes),
      fact(flight_visibility_sm,F), ge(F,1), fact(in_clouds,no), fact(between_sunrise_sunset,yes)],
     fact(svfr, authorized)).

rule(r18, 'Special VFR authorised (outside sunrise-sunset)', '14 CFR 91.157(a), (b)(1), (b)(2), (b)(3), (b)(4)(i) and (ii)',
     [fact(svfr,possible), fact(airport_svfr_prohibited,no), fact(atc_svfr_clearance,yes),
      fact(flight_visibility_sm,F), ge(F,1), fact(in_clouds,no), fact(between_sunrise_sunset,no),
      fact(pilot_instrument_qualified,yes), fact(aircraft_ifr_equipped,yes)],
     fact(svfr, authorized)).

rule(r19, 'Special VFR takeoff/landing needs 1 SM airport visibility', '14 CFR 91.157(c)(1) and (c)(2)',
     [fact(svfr,authorized), fact(takeoff_landing,yes),
      any([[fact(ground_visibility_reported,yes), fact(ground_visibility_sm,G), lt(G,1)],
           [fact(ground_visibility_reported,no), fact(flight_visibility_sm,F), lt(F,1)]])],
     fact(svfr_block, ground_visibility_below_1)).

% ----- Layer 5: IFR alternate airport --------------------------------------

rule(r20, 'No alternate needed (the 1-2-3 exception)', '14 CFR 91.169(b)(1) and (b)(2)(i)',
     [fact(flight_rules,ifr), fact(dest_has_std_iap,yes),
      fact(dest_fcst_ceiling_ft,C), fact(dest_fcst_vis_sm,V), ge(C,2000), ge(V,3)],
     fact(alternate, not_required)).

rule(r21, 'An alternate airport is required', '14 CFR 91.169(a)(2), (b)(1), (b)(2)(i)',
     [fact(flight_rules,ifr), fact(dest_has_std_iap,I),
      fact(dest_fcst_ceiling_ft,C), fact(dest_fcst_vis_sm,V),
      any([[eq(I,no)], [lt(C,2000)], [lt(V,3)]])],
     fact(alternate, required)).

rule(r22, 'Alternate minimum, precision approach', '14 CFR 91.169(c)(1)(i) and (c)(1)(i)(A)',
     [fact(alternate,required), fact(alt_iap_type,precision), fact(alt_published,yes),
      fact(alt_pub_ceiling_ft,C), fact(alt_pub_vis_sm,V)],
     fact(alt_minimum, min(C,V))).
rule(r22, 'Alternate minimum, precision approach', '14 CFR 91.169(c)(1)(i) and (c)(1)(i)(A)',
     [fact(alternate,required), fact(alt_iap_type,precision), fact(alt_published,no)],
     fact(alt_minimum, min(600,2))).

rule(r23, 'Alternate minimum, non-precision approach', '14 CFR 91.169(c)(1)(i) and (c)(1)(i)(B)',
     [fact(alternate,required), fact(alt_iap_type,nonprecision), fact(alt_published,yes),
      fact(alt_pub_ceiling_ft,C), fact(alt_pub_vis_sm,V)],
     fact(alt_minimum, min(C,V))).
rule(r23, 'Alternate minimum, non-precision approach', '14 CFR 91.169(c)(1)(i) and (c)(1)(i)(B)',
     [fact(alternate,required), fact(alt_iap_type,nonprecision), fact(alt_published,no)],
     fact(alt_minimum, min(800,2))).

rule(r24, 'Alternate minimum, no instrument approach', '14 CFR 91.169(c)(2)',
     [fact(alternate,required), fact(alt_iap_type,none)],
     fact(alt_minimum, basic_vfr)).

rule(r25, 'The alternate airport is acceptable', '14 CFR 91.169(c)',
     [fact(alt_minimum, min(RC,RV)), fact(alt_fcst_ceiling_ft,C), fact(alt_fcst_vis_sm,V), ge(C,RC), ge(V,RV)],
     fact(alternate_status, acceptable)).
rule(r25, 'The alternate airport is acceptable', '14 CFR 91.169(c)',
     [fact(alt_minimum, basic_vfr), fact(alt_forecast_basic_vfr,yes)],
     fact(alternate_status, acceptable)).

% ----- Layer 6: fuel -------------------------------------------------------

rule(r26, 'VFR fuel: destination plus 30 minutes (day)', '14 CFR 91.151(a)(1)',
     [fact(flight_rules,vfr), fact(night,no), fact(fuel_to_dest_min,T), calc(R,T+30)],
     fact(fuel_required_min, R)).

rule(r27, 'VFR fuel: destination plus 45 minutes (night)', '14 CFR 91.151(a)(2)',
     [fact(flight_rules,vfr), fact(night,yes), fact(fuel_to_dest_min,T), calc(R,T+45)],
     fact(fuel_required_min, R)).

rule(r28, 'IFR fuel: destination, alternate if required, plus 45 minutes', '14 CFR 91.167(a)(1), (a)(2), (a)(3) and (b)',
     [fact(flight_rules,ifr), fact(alternate,not_required), fact(fuel_to_dest_min,T), calc(R,T+45)],
     fact(fuel_required_min, R)).
rule(r28, 'IFR fuel: destination, alternate if required, plus 45 minutes', '14 CFR 91.167(a)(1), (a)(2), (a)(3) and (b)',
     [fact(flight_rules,ifr), fact(alternate,required), fact(fuel_to_dest_min,T),
      fact(fuel_dest_to_alt_min,A), calc(R,T+A+45)],
     fact(fuel_required_min, R)).

% ----- Layer 7: final verdict (these just put the rules above together) ----

rule(r29, 'Verdict for a VFR flight', '14 CFR 91.135, 91.151, 91.155, 91.157 (combined)',
     [fact(flight_rules,vfr), no(violation,_),
      fact(fuel_required_min,R), fact(fuel_onboard_min,O), ge(O,R)],
     fact(verdict, legal)).
rule(r29, 'Verdict for a VFR flight', '14 CFR 91.135, 91.151, 91.155, 91.157 (combined)',
     [fact(flight_rules,vfr), fact(svfr,authorized), no(svfr_block,_),
      fact(fuel_required_min,R), fact(fuel_onboard_min,O), ge(O,R)],
     fact(verdict, legal)).

rule(r30, 'Verdict for an IFR flight', '14 CFR 91.167, 91.169 (combined)',
     [fact(flight_rules,ifr), fact(alternate,not_required),
      fact(fuel_required_min,R), fact(fuel_onboard_min,O), ge(O,R)],
     fact(verdict, legal)).
rule(r30, 'Verdict for an IFR flight', '14 CFR 91.167, 91.169 (combined)',
     [fact(flight_rules,ifr), fact(alternate,required), fact(alternate_status,acceptable),
      fact(fuel_required_min,R), fact(fuel_onboard_min,O), ge(O,R)],
     fact(verdict, legal)).


%% ========================================================================
%%  PART 3 - INFERENCE ENGINE
%% ========================================================================

% ---- shorthand used inside rules ------------------------------------------
% surface_class = "the airspace is Class B, C, D or E", the only classes that
% have surface areas (14 CFR 91.155(d) names exactly these four).
expand_cond(surface_class, any([[fact(airspace_class,b)],[fact(airspace_class,c)],[fact(airspace_class,d)],[fact(airspace_class,e)]])) :- !.
expand_cond(C, C).

% ---- checking conditions -------------------------------------------------
% holds(Condition, Support): Support is the list of facts that made it true,
% we keep it so we can explain the answer later.

holds_all([], []).
holds_all([C0|Cs], S) :-
    expand_cond(C0, C),
    holds(C, S1),
    holds_all(Cs, S2),
    append(S1, S2, S).

holds(fact(N,V), [fact(N,V)]) :- fact(N,V).
holds(no(N,V),   [absent(N,V)]) :- \+ fact(N,V).
holds(any(Alts), S) :- member(Alt, Alts), holds_all(Alt, S).
holds(C, [test(C)]) :- test_cond(C).

test_cond(lt(A,B))   :- A <  B.
test_cond(le(A,B))   :- A =< B.
test_cond(gt(A,B))   :- A >  B.
test_cond(ge(A,B))   :- A >= B.
test_cond(eq(A,B))   :- A == B.
test_cond(calc(X,E)) :- X is E.

% ---- forward chaining ----------------------------------------------------
% Look for the first rule (in file order) that can fire and has not fired
% yet, add its conclusion, write down how we got it, and start again. It
% stops when nothing new can be added.

forward_chain :-
    (   rule(ID, _, _, Conds, fact(N,V)),
        holds_all(Conds, Support),
        \+ fact(N,V)
    ->  assertz(fact(N,V)),
        assertz(derived(fact(N,V), ID, Support)),
        forward_chain
    ;   true
    ).

% ---- backward chaining ---------------------------------------------------
% bc(Goal, Proof): to prove a fact, either it is something we can ask the
% user, or we find a rule that concludes it and prove its conditions.

bc(fact(N,V), given(N,V)) :-
    is_input(N), !,
    ensure_known(N),
    fact(N,V).
bc(fact(N,V), by(fact(N,V), ID, Src, Subs)) :-
    rule(ID, _, Src, Conds, fact(N,V)),
    bc_all(Conds, Subs).

bc_all([], []).
bc_all([C0|Cs], [P|Ps]) :- expand_cond(C0, C), bc_cond(C, P), bc_all(Cs, Ps).

bc_cond(fact(N,V), P)        :- bc(fact(N,V), P).
bc_cond(no(N,V), absent(N,V)) :- \+ bc(fact(N,V), _).
bc_cond(any(Alts), alt(Subs)) :- member(Alt, Alts), bc_all(Alt, Subs).
bc_cond(C, test(C))          :- test_cond(C).

is_input(N) :- input(N, _, _, _, _, _), !.

ensure_known(N) :-
    (   fact(N,_) -> true
    ;   no_questions -> true          % test mode: an unknown fact is just unknown
    ;   ask_input(N)
    ).

reset_session :-
    retractall(fact(_,_)),
    retractall(derived(_,_,_)),
    retractall(shown(_)).


%% ========================================================================
%%  PART 4 - ASKING THE USER
%% ========================================================================

% Answers are read one line at a time, so the user can type  vfr  or  vfr.
% (the full stop is optional), in any mix of upper and lower case. Numbers
% like  3.5  are turned into numbers. read_line_to_string/2 also works in
% the online SWISH editor, which shows an input box for it.

read_answer(A) :-
    catch(read_line_to_string(user_input, Line), _, Line = end_of_file),
    (   Line == end_of_file
    ->  A = quit
    ;   clean_answer(Line, A)
    ).

clean_answer(Line, A) :-
    normalize_space(string(S0), Line),          % trim spaces and tabs
    string_lower(S0, S1),
    drop_final_dot(S1, S),
    (   S == ""                   -> A = bad_input
    ;   as_number(S, N)           -> A = N
    ;   atom_string(A0, S), short_form(A0, A)
    ).

% "3.5" -> 3.5, ".5" -> 0.5; anything with a space inside is not a number
as_number(S, N) :-
    \+ sub_string(S, _, _, _, " "),
    (   sub_string(S, 0, 1, _, ".") -> string_concat("0", S, S1) ; S1 = S ),
    number_string(N, S1).

drop_final_dot(S0, S) :-
    (   sub_string(S0, Before, 1, 0, ".")
    ->  sub_string(S0, 0, Before, 1, S1), normalize_space(string(S), S1)
    ;   S = S0
    ).

short_form(y, yes) :- !.
short_form(n, no)  :- !.
short_form(A, A).

valid(oneof(L), A, A) :- memberchk(A, L).
valid(number(Min,Max), A, A) :- number(A), A >= Min, A =< Max.
valid(number_or_none(_,_,S), none, S) :- !.
valid(number_or_none(Min,Max,_), A, A) :- number(A), A >= Min, A =< Max.

ask_input(Name) :-
    input(Name, _, Type, _, Prompt, Why),
    repeat,
        format("~n~w~n", [Prompt]),
        flush_output,
        read_answer(A),
        (   A == quit
        ->  throw(stop_consultation)
        ;   A == why
        ->  show_why(Name, Why), fail
        ;   valid(Type, A, V)
        ->  assertz(fact(Name, V)), !
        ;   format("  That is not a valid answer, please try again.~n"), fail
        ).

show_why(Name, Why) :-
    used_by(Name, IDs),
    format("  Why I ask: ~w~n", [Why]),
    format("  Rules that use this fact: ~w~n", [IDs]).

used_by(Name, IDs) :-
    findall(ID, ( rule(ID,_,_,Conds,_), mentions(Conds, Name) ), L),
    sort(L, IDs).

% true if some condition (at any depth) talks about the fact called Name
mentions(Conds, Name) :-
    sub_term(X, Conds),
    nonvar(X),
    (   X = fact(Name,_) ; X = no(Name,_)
    ;   X == surface_class, Name == airspace_class
    ),
    !.

% Ask every question of one group that is still unanswered and applies.
ask_group(G) :-
    forall(input(Name, G, _, Applies, _, _),
           (   fact(Name,_)
           ->  true
           ;   holds_all(Applies, _)
           ->  ask_input(Name)
           ;   true
           )).


%% ========================================================================
%%  PART 5 - CONSULTATIONS (what the menu options do)
%% ========================================================================

consult_forward :-
    reset_session,
    catch(forward_session, stop_consultation,
          format("~nConsultation stopped.~n")).

forward_session :-
    format("~n--- New consultation (forward chaining) ---~n"),
    ask_group(base),  forward_chain,
    (   fact(svfr, possible)
    ->  format("~nThe weather is below VFR minimums, but Special VFR might be possible. A few more questions.~n"),
        ask_group(svfr), forward_chain
    ;   true
    ),
    ask_group(ifr),   forward_chain,
    (   fact(alternate, required)
    ->  format("~nAn alternate airport is required. Questions about the alternate.~n"),
        ask_group(alt), forward_chain
    ;   true
    ),
    ask_group(fuel),  forward_chain,
    report.

% Backward chaining: pick a question and let the engine work back from it.
backward_menu :-
    format("~nGoal-driven mode (backward chaining). Which question do you want answered?~n"),
    format("  1. Is this flight legal to depart?~n"),
    format("  2. Is an alternate airport required? (IFR)~n"),
    format("  3. Can Special VFR be authorised?~n"),
    format("  4. What are the VFR weather minimums here?~n"),
    format("  5. How many minutes of fuel are required?~n"),
    flush_output,
    read_answer(C),
    (   goal_for(C, Goal)
    ->  reset_session,
        catch(prove_goal(Goal), stop_consultation,
              format("~nStopped.~n"))
    ;   C == quit
    ->  true
    ;   format("Please pick 1 to 5.~n")
    ).

goal_for(1, fact(verdict, legal)).
goal_for(2, fact(alternate, _)).
goal_for(3, fact(svfr, authorized)).
goal_for(4, fact(vfr_minimum, _)).
goal_for(5, fact(fuel_required_min, _)).

prove_goal(Goal) :-
    goal_text(Goal, Text),
    format("~nGoal: ~w~nWorking backwards from the goal. I will only ask for the facts it needs.~n", [Text]),
    (   bc(Goal, Proof)
    ->  Goal = fact(N, V),
        format("~nANSWER: ~w = ~w~n~nProof (each line is proved by the lines indented under it):~n", [N, V]),
        print_proof(Proof, 1)
    ;   format("~nANSWER: this could NOT be proved from your answers, so the answer is no.~n"),
        format("(Use option 1 for a full report that shows which rule failed.)~n")
    ).

goal_text(fact(verdict,_),           'is this flight legal to depart?').
goal_text(fact(alternate,_),         'is an alternate airport required?').
goal_text(fact(svfr,_),              'can Special VFR be authorised?').
goal_text(fact(vfr_minimum,_),       'which VFR weather minimum applies?').
goal_text(fact(fuel_required_min,_), 'how many minutes of fuel are required?').

print_proof(given(N,V), D) :-
    indent(D), format("~w = ~w   (your answer)~n", [N,V]).
print_proof(by(fact(N,V), ID, Src, Subs), D) :-
    indent(D),
    format("~w = ~w   <- rule ~w [~w]~n", [N,V,ID,Src]),
    D1 is D + 1,
    forall(member(S, Subs), print_proof(S, D1)).
print_proof(absent(N,_), D) :-
    indent(D), format("no ~w was found~n", [N]).
print_proof(test(T), D) :-
    indent(D), show_check(T).
print_proof(alt(Subs), D) :-
    forall(member(S, Subs), print_proof(S, D)).

indent(D) :- N is D * 3, format("~*c", [N, 0' ]).

show_check(lt(A,B))   :- !, format("check: ~w < ~w~n", [A,B]).
show_check(le(A,B))   :- !, format("check: ~w =< ~w~n", [A,B]).
show_check(gt(A,B))   :- !, format("check: ~w > ~w~n", [A,B]).
show_check(ge(A,B))   :- !, format("check: ~w >= ~w~n", [A,B]).
show_check(eq(A,B))   :- !, format("check: ~w is ~w~n", [A,B]).
show_check(calc(X,E)) :- !, format("calculation: ~w = ~w~n", [X,E]).
show_check(T)         :- format("check: ~w~n", [T]).


%% ========================================================================
%%  PART 6 - REPORT AND EXPLANATION
%% ========================================================================

report :-
    format("~n=========================================================~n"),
    (   fact(verdict, legal)
    ->  format(" RESULT: LEGAL TO DEPART (under the rules modelled here)~n")
    ;   format(" RESULT: NOT LEGAL TO DEPART~n")
    ),
    format("=========================================================~n"),
    problems,
    format("~n--- Rules fired, in order (forward chaining trace) ---~n"),
    forall(derived(fact(N,V), ID, _),
           ( rule_info(ID, Name, Src),
             format("~w  ~w~n      => ~w = ~w      [~w]~n", [ID,Name,N,V,Src]) )),
    format("~n--- How the conclusion was reached ---~n"),
    retractall(shown(_)),
    (   fact(verdict, legal)
    ->  explain_fact(fact(verdict,legal), 0)
    ;   forall(( key_fact(F), derived(F, _, _) ), explain_fact(F, 0))
    ),
    nl.

% What to explain when the flight is refused.
key_fact(fact(violation,_)).
key_fact(fact(svfr_block,_)).
key_fact(fact(alt_minimum,_)).
key_fact(fact(fuel_required_min,_)).

% Say what went wrong when the answer is "not legal".
problems :-
    (   fact(verdict, legal) -> true
    ;   format("~nWhy not:~n"),
        forall(derived(fact(violation,K), ID, _),
               ( rule_info(ID, Name, Src),
                 format("  - ~w: ~w [~w, ~w]~n", [K,Name,ID,Src]) )),
        svfr_problem,
        block_problem,
        alternate_problem,
        fuel_problem
    ).

svfr_problem :-
    (   fact(svfr, possible), \+ fact(svfr, authorized)
    ->  format("  - Special VFR could not be authorised. Checking the conditions of 14 CFR 91.157:~n"),
        (   fact(between_sunrise_sunset, yes) -> why_not(r17, 1) ; why_not(r18, 1) )
    ;   true
    ).

block_problem :-
    forall(derived(fact(svfr_block,K), ID, _),
           ( rule_info(ID, Name, Src),
             format("  - ~w: ~w [~w, ~w]~n", [K,Name,ID,Src]) )).

alternate_problem :-
    (   fact(alternate, required), \+ fact(alternate_status, acceptable)
    ->  format("  - The alternate airport does not meet the alternate minimums (14 CFR 91.169(c)):~n"),
        (   fact(alt_iap_type, none) -> K = 2 ; K = 1 ),
        why_not(r25, K)
    ;   true
    ).

fuel_problem :-
    (   fact(fuel_required_min, R), fact(fuel_onboard_min, O), O < R
    ->  derived(fact(fuel_required_min,R), ID, _),
        rule_info(ID, _, Src),
        format("  - Not enough fuel: you have ~w min but need ~w min [~w, ~w]~n", [O,R,ID,Src])
    ;   true
    ).

rule_info(ID, Name, Src) :- rule(ID, Name, Src, _, _), !.

% why_not(ID, K): walk the conditions of the K-th version of rule ID and
% show the first one that does not hold.
why_not(ID, K) :-
    findall(C, rule(ID,_,_,C,_), All),
    nth1(K, All, Conds),
    rule_info(ID, Name, Src),
    format("      rule ~w (~w) [~w]~n", [ID,Name,Src]),
    first_fail(Conds).

first_fail([]) :- format("        every condition holds~n").
first_fail([C0|Cs]) :-
    expand_cond(C0, C),
    (   holds(C, _)
    ->  first_fail(Cs)
    ;   describe_failure(C)
    ).

describe_failure(fact(N,V)) :-
    (   fact(N,A)
    ->  format("        not met: ~w is ~w, the rule needs ~w~n", [N,A,V])
    ;   format("        not met: ~w is not known~n", [N])
    ).
describe_failure(any(_)) :-
    format("        not met: none of the alternatives holds~n").
describe_failure(C) :-
    C \= fact(_,_), C \= any(_),
    format("        not met: ~w~n", [C]).

% Tree explanation of one fact: what rule gave it, and what that rule used.
explain_fact(fact(N,V), D) :-
    indent(D),
    (   derived(fact(N,V), ID, Support)
    ->  rule_info(ID, Name, Src),
        (   shown(fact(N,V))
        ->  format("~w = ~w   (explained above)~n", [N,V])
        ;   assertz(shown(fact(N,V))),
            format("~w = ~w   <- ~w ~w [~w]~n", [N,V,ID,Name,Src]),
            D1 is D + 1,
            forall(member(S, Support), explain_support(S, D1))
        )
    ;   format("~w = ~w   (your answer)~n", [N,V])
    ).

explain_support(fact(N,V), D) :- explain_fact(fact(N,V), D).
explain_support(absent(N,_), D) :- indent(D), format("no ~w was found~n", [N]).
explain_support(test(C), D) :- indent(D), show_check(C).


%% ========================================================================
%%  PART 7 - MENU
%% ========================================================================

main :-
    format("~n*********************************************************~n"),
    format("  AeroRule - flight rule legality advisor (14 CFR Part 91)~n"),
    format("  Educational project. Not for real flight planning.~n"),
    format("*********************************************************~n"),
    format("Type your answer and press Enter, e.g.  vfr   3.5   yes   (a full stop is optional).~n"),
    format("Type  why  at any question to see why it is asked, or  quit  to stop.~n"),
    menu_loop.

menu_loop :-
    repeat,
        format("~nMENU~n"),
        format("  1. New consultation (forward chaining, full explanation)~n"),
        format("  2. Ask one question (backward chaining)~n"),
        format("  3. List the 30 rules and their sources~n"),
        format("  4. Run the built-in test cases~n"),
        format("  5. Exit~n"),
        flush_output,
        read_answer(C),
        (   C == 1 -> consult_forward, fail
        ;   C == 2 -> backward_menu, fail
        ;   C == 3 -> list_rules, fail
        ;   C == 4 -> run_tests, fail
        ;   ( C == 5 ; C == quit ) -> format("Goodbye.~n"), !
        ;   format("Please type a number from 1 to 5.~n"), fail
        ).

list_rules :-
    format("~nID    Rule / source~n"),
    findall(ID, rule(ID,_,_,_,_), L0), list_to_set(L0, IDs),
    forall(member(ID, IDs),
           ( rule_info(ID, Name, Src),
             format("~w   ~w~n       ~w~n", [ID,Name,Src]) )),
    length(IDs, Count),
    format("~nTotal: ~w rules~n", [Count]),
    format("~nSources (read on the eCFR, September 2026):~n"),
    forall(regulation(Sec, Title, Url),
           format("  ~w  ~w~n      ~w~n", [Sec, Title, Url])).


%% ========================================================================
%%  PART 8 - BUILT-IN TESTS (no typing needed)
%% ========================================================================
%  case(Name, Kind, Overrides, ExpectedVerdict, MustFire, MustNotFire)
%  Kind picks a set of default answers, Overrides change some of them.
%  use(Template) inside Overrides pulls in a shared block of answers; if a
%  name appears twice, the later answer wins.

defaults(vfr, [flight_rules-vfr, airspace_class-c, altitude_msl_ft-3000, night-no,
               in_surface_area-no, flight_visibility_sm-8, in_clouds-no,
               dist_below_cloud_ft-99999, dist_above_cloud_ft-99999,
               dist_horizontal_cloud_ft-99999,
               fuel_to_dest_min-90, fuel_onboard_min-150]).
defaults(ifr, [flight_rules-ifr, dest_has_std_iap-yes, dest_fcst_ceiling_ft-3000,
               dest_fcst_vis_sm-6, fuel_to_dest_min-120, fuel_onboard_min-165]).

% a class D airport, poor weather, day, Special VFR clearance in hand
template(svfr_day, [airspace_class-d, in_surface_area-yes, takeoff_landing-yes,
                    flight_visibility_sm-2, ceiling_ft-800,
                    ground_visibility_reported-yes, ground_visibility_sm-1.5,
                    between_sunrise_sunset-yes, airport_svfr_prohibited-no,
                    atc_svfr_clearance-yes]).

% same airport at night, pilot and aircraft not qualified
template(svfr_night_unqualified, [night-yes, between_sunrise_sunset-no,
                                  pilot_instrument_qualified-no,
                                  aircraft_ifr_equipped-yes]).

% low weather at the destination and a precision-approach alternate
template(ifr_alt, [dest_fcst_ceiling_ft-1500, dest_fcst_vis_sm-2, alt_iap_type-precision,
                   alt_published-no, alt_fcst_ceiling_ft-700, alt_fcst_vis_sm-3,
                   fuel_dest_to_alt_min-30, fuel_to_dest_min-100, fuel_onboard_min-175]).

case('T01 VFR Class C, good weather', vfr, [], legal,
     [r03,r26,r29], [r01,r12,r13]).
case('T02 VFR flight in Class A', vfr, [airspace_class-a, altitude_msl_ft-24000], not_legal,
     [r01], [r29]).
case('T03 Class D marginal weather, day Special VFR', vfr, [use(svfr_day)], legal,
     [r04,r12,r14,r15,r16,r17,r29], [r18,r19]).
case('T04 Night Special VFR, pilot not instrument qualified', vfr,
     [use(svfr_day), use(svfr_night_unqualified)], not_legal,
     [r16,r12], [r17,r18,r29]).
case('T05 Night Special VFR, pilot and aircraft qualified', vfr,
     [use(svfr_day), night-yes, between_sunrise_sunset-no,
      pilot_instrument_qualified-yes, aircraft_ifr_equipped-yes], legal,
     [r16,r18,r27,r29], [r17]).
case('T06 Special VFR but only 0.5 SM at the airport', vfr,
     [use(svfr_day), ground_visibility_sm-0.5], not_legal,
     [r17,r19], [r29]).
case('T07 Class G day, 1.5 SM, low altitude', vfr,
     [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-800, flight_visibility_sm-1.5],
     legal, [r07,r29], [r12]).
case('T08 Class G night, only 2 SM', vfr,
     [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-800, flight_visibility_sm-2, night-yes],
     not_legal, [r08,r12], [r29]).
case('T09 Class E at 12,000 ft with 4 SM', vfr,
     [airspace_class-e, altitude_msl_ft-12000, flight_visibility_sm-4],
     not_legal, [r06,r12], [r29]).
case('T10 Class C, cloud only 300 ft above', vfr, [dist_below_cloud_ft-300], not_legal,
     [r13], [r29]).
case('T11 VFR night flight, not enough fuel', vfr,
     [night-yes, fuel_to_dest_min-90, fuel_onboard_min-120], not_legal,
     [r27], [r29]).
case('T12 IFR, good destination weather, no alternate', ifr, [], legal,
     [r20,r28,r30], [r21]).
case('T13 IFR, low destination weather, good precision alternate', ifr,
     [use(ifr_alt)], legal,
     [r21,r22,r25,r28,r30], [r20]).
case('T14 IFR, non-precision alternate below 800 ft', ifr,
     [use(ifr_alt), alt_iap_type-nonprecision], not_legal,
     [r21,r23], [r25,r30]).
case('T15 IFR, destination has no approach, alternate needed', ifr,
     [dest_has_std_iap-no, alt_iap_type-precision, alt_published-no,
      alt_fcst_ceiling_ft-700, alt_fcst_vis_sm-3,
      fuel_dest_to_alt_min-30, fuel_onboard_min-200], legal,
     [r21,r22,r25,r30], [r20]).
case('T16 IFR, alternate without approach, basic VFR forecast', ifr,
     [dest_fcst_ceiling_ft-1000, alt_iap_type-none, alt_forecast_basic_vfr-yes,
      fuel_dest_to_alt_min-20, fuel_onboard_min-190], legal,
     [r21,r24,r25], [r22,r23]).
case('T17 IFR, published alternate minimum overrides 600-2', ifr,
     [dest_fcst_ceiling_ft-1500, alt_iap_type-precision, alt_published-yes,
      alt_pub_ceiling_ft-800, alt_pub_vis_sm-2,
      alt_fcst_ceiling_ft-700, alt_fcst_vis_sm-3,
      fuel_dest_to_alt_min-30, fuel_onboard_min-200], not_legal,
     [r22], [r25,r30]).

case('T18 IFR, a 1,500 ft ceiling alone triggers an alternate', ifr,
     [use(ifr_alt), dest_fcst_vis_sm-6], legal,
     [r21,r22,r25,r30], [r20]).
case('T19 IFR, 2 SM visibility alone triggers an alternate', ifr,
     [use(ifr_alt), dest_fcst_ceiling_ft-3000], legal,
     [r21,r22,r25,r30], [r20]).
case('T20 IFR, exactly 2000 ft and 3 SM: no alternate (boundary)', ifr,
     [dest_fcst_ceiling_ft-2000, dest_fcst_vis_sm-3], legal,
     [r20,r28,r30], [r21]).
case('T21 Night Special VFR, pilot qualified but aircraft not IFR-equipped', vfr,
     [use(svfr_day), night-yes, between_sunrise_sunset-no,
      pilot_instrument_qualified-yes, aircraft_ifr_equipped-no], not_legal,
     [r16,r12], [r17,r18,r29]).
case('T22 Class C, exactly 3 SM and exactly 500 ft below cloud (boundary)', vfr,
     [flight_visibility_sm-3, dist_below_cloud_ft-500], legal,
     [r03,r29], [r12,r13]).
case('T23 VFR day, fuel exactly at the 30 minute reserve (boundary)', vfr,
     [fuel_to_dest_min-90, fuel_onboard_min-120], legal,
     [r26,r29], []).
case('T24 VFR day, one minute short of the reserve', vfr,
     [fuel_to_dest_min-90, fuel_onboard_min-119], not_legal,
     [r26], [r29]).

case('T25 IFR, precision alternate forecast at 550 ft (below 600)', ifr,
     [use(ifr_alt), alt_fcst_ceiling_ft-550], not_legal,
     [r22], [r25,r30]).
case('T26 Special VFR, flight visibility exactly 1 SM (boundary)', vfr,
     [use(svfr_day), flight_visibility_sm-1], legal,
     [r17,r29], []).
case('T27 Special VFR, flight visibility 0.9 SM', vfr,
     [use(svfr_day), flight_visibility_sm-0.9], not_legal,
     [r16], [r17,r29]).
case('T28 IFR with alternate, 10 minutes short of fuel', ifr,
     [use(ifr_alt), fuel_onboard_min-165], not_legal,
     [r28], [r30]).
case('T29 IFR without alternate, 1 minute short of fuel', ifr,
     [fuel_onboard_min-164], not_legal,
     [r28], [r30]).

% Regression test: found by random testing. A low ceiling must not open the
% Special VFR route in Class A (Class A has no surface area).
case('T30 Class A, low ceiling: Special VFR must not rescue it', vfr,
     [airspace_class-a, altitude_msl_ft-3000, in_surface_area-yes, takeoff_landing-yes,
      flight_visibility_sm-2, ceiling_ft-400, ground_visibility_reported-yes,
      ground_visibility_sm-1.5, between_sunrise_sunset-yes, airport_svfr_prohibited-no,
      atc_svfr_clearance-yes], not_legal,
     [r01], [r14,r15,r16,r17,r29]).

% More tests added after deliberately breaking rules showed gaps (see TESTS.md).
case('T31 Class C, flying in cloud', vfr, [in_clouds-yes], not_legal,
     [r03,r13], [r29]).
case('T32 Class C, cloud 1,999 ft away horizontally (needs 2,000)', vfr,
     [dist_horizontal_cloud_ft-1999], not_legal,
     [r13], [r29]).
case('T33 Class D takeoff, ground visibility 2.5 SM, no Special VFR clearance', vfr,
     [airspace_class-d, in_surface_area-yes, takeoff_landing-yes, ceiling_ft-3000,
      ground_visibility_reported-yes, ground_visibility_sm-2.5, flight_visibility_sm-5,
      between_sunrise_sunset-yes, airport_svfr_prohibited-no, atc_svfr_clearance-no], not_legal,
     [r15,r16], [r12,r17,r29]).
case('T34 Class D takeoff, ground visibility not reported, flight visibility 2.5 SM', vfr,
     [airspace_class-d, in_surface_area-yes, takeoff_landing-yes, ceiling_ft-3000,
      ground_visibility_reported-no, flight_visibility_sm-2.5,
      between_sunrise_sunset-yes, airport_svfr_prohibited-no, atc_svfr_clearance-no], not_legal,
     [r12,r15], [r29]).
case('T35 Class E surface area at 10,500 ft MSL: no Special VFR above 10,000', vfr,
     [airspace_class-e, altitude_msl_ft-10500, in_surface_area-yes, takeoff_landing-no,
      ceiling_ft-3000, flight_visibility_sm-4, between_sunrise_sunset-yes,
      airport_svfr_prohibited-no, atc_svfr_clearance-yes], not_legal,
     [r06,r12], [r16,r17,r29]).
case('T36 Class G has no surface area: Special VFR must not apply', vfr,
     [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-800, in_surface_area-yes,
      flight_visibility_sm-0.5, between_sunrise_sunset-yes, airport_svfr_prohibited-no,
      atc_svfr_clearance-yes], not_legal,
     [r07,r12], [r16,r17,r29]).
case('T37 Special VFR weather but no ATC clearance', vfr,
     [use(svfr_day), atc_svfr_clearance-no], not_legal,
     [r16], [r17,r29]).
case('T38 Special VFR at an airport where it is prohibited', vfr,
     [use(svfr_day), airport_svfr_prohibited-yes], not_legal,
     [r16], [r17,r29]).
case('T39 Special VFR clearance but flying in cloud', vfr,
     [use(svfr_day), in_clouds-yes], not_legal,
     [r13,r16], [r17,r29]).
case('T40 IFR, alternate without approach, forecast does not allow basic VFR', ifr,
     [dest_fcst_ceiling_ft-1000, alt_iap_type-none, alt_forecast_basic_vfr-no,
      fuel_dest_to_alt_min-20, fuel_onboard_min-190], not_legal,
     [r21,r24], [r25,r30]).
case('T41 IFR, precision alternate with 1.9 SM forecast (needs 2)', ifr,
     [use(ifr_alt), alt_fcst_vis_sm-1.9], not_legal,
     [r22], [r25,r30]).

% One test per row of the 91.155(a) table (rules r02 to r11).
min_case(r02, [airspace_class-b, altitude_msl_ft-4000, night-no], min(3,0,0,0)).
min_case(r03, [airspace_class-c, altitude_msl_ft-4000, night-no], min(3,500,1000,2000)).
min_case(r04, [airspace_class-d, altitude_msl_ft-2500, night-no], min(3,500,1000,2000)).
min_case(r05, [airspace_class-e, altitude_msl_ft-5000, night-no], min(3,500,1000,2000)).
min_case(r06, [airspace_class-e, altitude_msl_ft-12000, night-no], min(5,1000,1000,5280)).
min_case(r07, [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-800, night-no], min(1,0,0,0)).
min_case(r08, [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-800, night-yes], min(3,500,1000,2000)).
min_case(r09, [airspace_class-g, altitude_msl_ft-4000, altitude_agl_ft-2000, night-no], min(1,500,1000,2000)).
min_case(r10, [airspace_class-g, altitude_msl_ft-4000, altitude_agl_ft-2000, night-yes], min(3,500,1000,2000)).
min_case(r11, [airspace_class-g, altitude_msl_ft-11000, altitude_agl_ft-3000, night-no], min(5,1000,1000,5280)).
% boundary values: exactly 10,000 ft MSL and exactly 1,200 ft AGL
min_case(r06, [airspace_class-e, altitude_msl_ft-10000, night-no], min(5,1000,1000,5280)).
min_case(r07, [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-1200, night-no], min(1,0,0,0)).
min_case(r09, [airspace_class-g, altitude_msl_ft-1500, altitude_agl_ft-1201, night-no], min(1,500,1000,2000)).

% ---- helpers for the tests ----

expand_over([], []).
expand_over([use(T)|Rest], All) :- !,
    template(T, Block),
    expand_over(Rest, More),
    append(Block, More, All).
expand_over([X|Rest], [X|More]) :- expand_over(Rest, More).

last_wins([], []).
last_wins([N-V|T], R) :-
    (   memberchk(N-_, T) -> R = R1 ; R = [N-V|R1] ),
    last_wins(T, R1).

build_facts(Kind, Over0, Facts) :-
    defaults(Kind, Def),
    expand_over(Over0, Over1),
    last_wins(Over1, Over),
    findall(N-V, ( member(N-V, Def), \+ memberchk(N-_, Over) ), Keep),
    append(Keep, Over, Facts).

load_facts(Pairs) :-
    forall(member(N-V, Pairs), assertz(fact(N,V))).

run_forward_on(Kind, Over) :-
    build_facts(Kind, Over, Facts),
    reset_session,
    load_facts(Facts),
    forward_chain.

actual_verdict(legal)     :- fact(verdict, legal), !.
actual_verdict(not_legal).

fired_ids(L) :-
    findall(ID, derived(_,ID,_), L0),
    sort(L0, L).

remember_coverage(Fired) :-
    forall(member(F, Fired), ( covered(F) -> true ; assertz(covered(F)) )).

% ---- the test runners ----

run_case(Name, Kind, Over, Expected, Must, MustNot, Result) :-
    run_forward_on(Kind, Over),
    actual_verdict(Actual),
    fired_ids(Fired),
    remember_coverage(Fired),
    (   Actual == Expected,
        subset(Must, Fired),
        \+ ( member(X, MustNot), memberchk(X, Fired) )
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  ~w~n      expected: ~w   actual: ~w~n      rules fired: ~w~n",
           [Tag, Name, Expected, Actual, Fired]).

run_min_case(ID, Over, Expected, Result) :-
    run_forward_on(vfr, Over),
    fired_ids(Fired),
    remember_coverage(Fired),
    findall(G, fact(vfr_minimum, G), Gs),
    (   Gs = [Got] -> true ; Got = Gs ),          % must be exactly one minimum
    (   Got == Expected, memberchk(ID, Fired)
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  minimum table, rule ~w: expected ~w, got ~w~n", [Tag, ID, Expected, Got]).

% Checks that the explanation text itself mentions the right rule and law.
run_explain_test(Result) :-
    run_forward_on(vfr, [use(svfr_day)]),
    with_output_to(string(Text), report),
    (   sub_string(Text, _, _, _, "RESULT: LEGAL TO DEPART"),
        sub_string(Text, _, _, _, "r17"),
        sub_string(Text, _, _, _, "14 CFR 91.157")
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  explanation text for T03 names rule r17 and 14 CFR 91.157~n", [Tag]).

% Same idea for the "why not" text of a refused flight.
run_whynot_test(Result) :-
    run_forward_on(vfr, [use(svfr_day), use(svfr_night_unqualified)]),
    with_output_to(string(Text), report),
    (   sub_string(Text, _, _, _, "RESULT: NOT LEGAL"),
        sub_string(Text, _, _, _, "pilot_instrument_qualified is no")
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  refusal text for T04 says the pilot is not instrument qualified~n", [Tag]).

% Backward chaining must reach the same verdict as forward chaining. We load
% the same answers, but instead of firing rules we ask the backward engine
% to PROVE verdict = legal. No questions are asked (no_questions flag).
run_agree_case(Name, Kind, Over, Result) :-
    run_forward_on(Kind, Over),
    actual_verdict(Fwd),
    build_facts(Kind, Over, Facts),
    reset_session, load_facts(Facts),
    setup_call_cleanup(assertz(no_questions),
                       ( bc(fact(verdict,legal), _) -> Bwd = legal ; Bwd = not_legal ),
                       retractall(no_questions)),
    (   Fwd == Bwd -> Result = pass, Tag = 'PASS' ; Result = fail, Tag = 'FAIL' ),
    sub_atom(Name, 0, 3, _, Id),
    format("~w  ~w  forward: ~w   backward: ~w~n", [Tag, Id, Fwd, Bwd]).

% The backward proof for T03 must go through Special VFR (rule r17).
run_backward_proof_test(Result) :-
    template(svfr_day, Over),
    build_facts(vfr, Over, Facts),
    reset_session, load_facts(Facts),
    setup_call_cleanup(assertz(no_questions),
                       ( bc(fact(verdict,legal), Proof) -> true ; Proof = none ),
                       retractall(no_questions)),
    (   sub_term(by(fact(svfr,authorized), r17, _, _), Proof)
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  backward proof for T03 goes through r17 (Special VFR)~n", [Tag]).

run_tests :-
    retractall(covered(_)),
    format("~n===== Scenario tests =====~n"),
    findall(R, ( case(N,K,O,E,M,X), run_case(N,K,O,E,M,X,R) ), R1),
    format("~n===== Minimum table tests (rules r02 - r11) =====~n"),
    findall(R, ( min_case(ID,O2,E2), run_min_case(ID,O2,E2,R) ), R2),
    format("~n===== Explanation tests =====~n"),
    run_explain_test(R3),
    run_whynot_test(R4),
    format("~n===== Backward chaining agrees with forward chaining =====~n"),
    findall(R, ( case(N5,K5,O5,_,_,_), run_agree_case(N5,K5,O5,R) ), R5),
    run_backward_proof_test(R6),
    append([R1,R2,[R3,R4],R5,[R6]], All),
    include(==(pass), All, Passed),
    length(All, Total), length(Passed, P),
    format("~n===== Summary =====~n"),
    format("~w of ~w tests passed~n", [P, Total]),
    findall(I, rule(I,_,_,_,_), Ids0), list_to_set(Ids0, Ids),
    findall(I, ( member(I, Ids), \+ covered(I) ), Missing),
    length(Ids, NRules), length(Missing, NMiss), Cov is NRules - NMiss,
    format("rules triggered at least once: ~w of ~w~n", [Cov, NRules]),
    (   Missing == [] -> true
    ;   format("rules never triggered: ~w~n", [Missing])
    ).
