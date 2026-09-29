# Rules and facts (Annex A)

All 30 rules come from the text of 14 CFR Part 91, read on the eCFR (the page says it is up to date as of 24-25 September 2026). Nothing here was invented or taken from a chatbot's memory: each rule points to a paragraph that you can open and read yourself.

Where the rule is written in the code: `aerorule.pl`, Part 2. Rules with two bodies (r22, r23, r25, r28, r29, r30) are one rule with two alternative ways of being true, so the code has 36 clauses for 30 rules.

## Source pages

| Short name | Regulation | Link |
|---|---|---|
| 91.135 | Operations in Class A airspace | https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRe4c59b5f5506932/section-91.135 |
| 91.151 | Fuel requirements, VFR | https://www.law.cornell.edu/cfr/text/14/91.151 (Cornell copy of the eCFR text) |
| 91.155 | Basic VFR weather minimums | https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFR4d5279ba676bedc/section-91.155 |
| 91.157 | Special VFR weather minimums | https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFR4d5279ba676bedc/section-91.157 |
| 91.167 | Fuel requirements, IFR | https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRef6e8c57f580cfd/section-91.167 |
| 91.169 | IFR flight plan: alternate airport | https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91/subpart-B/subject-group-ECFRef6e8c57f580cfd/section-91.169 |

The meaning of "night" (end of evening civil twilight to start of morning civil twilight) is from 14 CFR 1.1: https://www.ecfr.gov/current/title-14/chapter-I/subchapter-A/part-1

## The 30 rules

`SM` = statute miles. `1 SM = 5280 ft`. "Clear of clouds" is stored as 0/0/0.

### Layer 1 - Class A

| ID | IF | THEN | Source |
|---|---|---|---|
| r01 | flight is VFR and airspace is Class A | violation: Class A requires IFR | 91.135 (opening paragraph) |

### Layer 2 - which VFR minimum applies (the 91.155(a) table)

Each rule concludes `vfr_minimum = min(visibility SM, ft below cloud, ft above cloud, horizontal ft)`.

| ID | IF (flight is VFR and ...) | THEN vfr_minimum | Source |
|---|---|---|---|
| r02 | Class B | 3 SM, clear of clouds | 91.155(a) table |
| r03 | Class C | 3 SM, 500 below, 1,000 above, 2,000 horizontal | 91.155(a) table |
| r04 | Class D | 3 SM, 500 / 1,000 / 2,000 | 91.155(a) table |
| r05 | Class E and below 10,000 ft MSL | 3 SM, 500 / 1,000 / 2,000 | 91.155(a) table |
| r06 | Class E and at or above 10,000 ft MSL | 5 SM, 1,000 / 1,000 / 5,280 (1 SM) | 91.155(a) table |
| r07 | Class G, 1,200 ft AGL or less, day | 1 SM, clear of clouds | 91.155(a) table |
| r08 | Class G, 1,200 ft AGL or less, night | 3 SM, 500 / 1,000 / 2,000 | 91.155(a) table |
| r09 | Class G, above 1,200 ft AGL, below 10,000 ft MSL, day | 1 SM, 500 / 1,000 / 2,000 | 91.155(a) table |
| r10 | Class G, above 1,200 ft AGL, below 10,000 ft MSL, night | 3 SM, 500 / 1,000 / 2,000 | 91.155(a) table |
| r11 | Class G, above 1,200 ft AGL, at or above 10,000 ft MSL | 5 SM, 1,000 / 1,000 / 5,280 | 91.155(a) table |

### Layer 3 - violations

"Class B/C/D/E" appears in r14 to r16 because only these classes have surface areas (91.155(d) names exactly these four). In the code it is written as the shorthand `surface_class`.

| ID | IF | THEN | Source |
|---|---|---|---|
| r12 | VFR and flight visibility < required visibility | violation: visibility below minimum | 91.155(a) |
| r13 | VFR and (in cloud, or nearest cloud is closer than required below / above / horizontally) | violation: cloud clearance | 91.155(a) |
| r14 | VFR, Class B/C/D/E, in a surface area, ceiling < 1,000 ft | violation: surface ceiling below 1,000 | 91.155(c) |
| r15 | VFR, Class B/C/D/E, in a surface area, taking off / landing / in the pattern, and ground visibility < 3 SM (or flight visibility < 3 SM when ground visibility is not reported) | violation: airport visibility below 3 SM | 91.155(d)(1), (d)(2) |

### Layer 4 - Special VFR

| ID | IF | THEN | Source |
|---|---|---|---|
| r16 | VFR, Class B/C/D/E, in a surface area, below 10,000 ft MSL, and any of r12 / r13 / r14 / r15 fired | Special VFR is possible | 91.157(a) |
| r17 | Special VFR possible, airport not on the Appendix D list, ATC clearance, flight visibility >= 1 SM, not in cloud, between sunrise and sunset | Special VFR authorised | 91.157(a), (b)(1)-(4) |
| r18 | Same as r17 but outside sunrise-sunset, **and** the pilot meets Part 61 instrument requirements **and** the aircraft is equipped per 91.205(d) | Special VFR authorised | 91.157(b)(4)(i), (ii) |
| r19 | Special VFR authorised, taking off or landing, and ground visibility < 1 SM (or flight visibility < 1 SM when not reported) | takeoff / landing blocked | 91.157(c)(1), (c)(2) |

### Layer 5 - IFR alternate airport

| ID | IF | THEN | Source |
|---|---|---|---|
| r20 | IFR, destination has a standard instrument approach, and forecast ceiling >= 2,000 ft **and** visibility >= 3 SM from 1 hour before to 1 hour after ETA | alternate not required (the "1-2-3" exception) | 91.169(b)(1), (b)(2)(i) |
| r21 | IFR and (destination has no standard approach, or forecast ceiling < 2,000 ft, or forecast visibility < 3 SM) | alternate required | 91.169(a)(2), (b) |
| r22 | alternate required, alternate has a precision approach: if the approach publishes alternate minimums, use them; otherwise use ceiling 600 ft and 2 SM | alternate minimum | 91.169(c)(1)(i), (c)(1)(i)(A) |
| r23 | same for a non-precision approach; standard minimum is ceiling 800 ft and 2 SM | alternate minimum | 91.169(c)(1)(i), (c)(1)(i)(B) |
| r24 | alternate required and the alternate has no instrument approach | minimum = what basic VFR needs | 91.169(c)(2) |
| r25 | forecast ceiling and visibility at the alternate are at or above the alternate minimum (or, with no approach, the forecast allows basic VFR) | alternate acceptable | 91.169(c) |

### Layer 6 - fuel (times are minutes of flying at normal cruise)

| ID | IF | THEN required fuel | Source |
|---|---|---|---|
| r26 | VFR, day | time to destination + 30 | 91.151(a)(1) |
| r27 | VFR, night | time to destination + 45 | 91.151(a)(2) |
| r28 | IFR | time to destination + 45 if no alternate is required; time to destination + destination-to-alternate + 45 if one is | 91.167(a)(1)-(3), (b) |

### Layer 7 - verdict (puts the rules above together)

| ID | IF | THEN | Source |
|---|---|---|---|
| r29 | VFR, fuel on board >= required, and either no violation was found or Special VFR is authorised with no takeoff/landing block | verdict: legal | 91.135, 91.151, 91.155, 91.157 combined |
| r30 | IFR, fuel on board >= required, and either no alternate is required or the alternate is acceptable | verdict: legal | 91.167, 91.169 combined |

If no rule concludes `legal`, the program says the flight is not legal and lists which rules found a problem.

## Facts

The knowledge base has three kinds of facts:

- **33 input facts**, the things the user tells the system (listed below). Each is stored in the code as `input/6`, together with its question, the allowed answers, when it is asked, and the "why" text.
- **7 source facts** (`regulation/3`), one for each page the rules were read from (the table at the top of this file). Menu option 3 prints them.
- **9 kinds of derived facts**, which the rules create while reasoning.

**Input facts (33)**

| Group | Facts |
|---|---|
| Flight (9) | flight_rules, airspace_class, altitude_msl_ft, altitude_agl_ft, night, in_surface_area, takeoff_landing, ground_visibility_reported, in_clouds |
| Weather (6) | flight_visibility_sm, ceiling_ft, ground_visibility_sm, dist_below_cloud_ft, dist_above_cloud_ft, dist_horizontal_cloud_ft |
| Special VFR (5) | between_sunrise_sunset, airport_svfr_prohibited, atc_svfr_clearance, pilot_instrument_qualified, aircraft_ifr_equipped |
| IFR destination (3) | dest_has_std_iap, dest_fcst_ceiling_ft, dest_fcst_vis_sm |
| Alternate (7) | alt_iap_type, alt_published, alt_pub_ceiling_ft, alt_pub_vis_sm, alt_fcst_ceiling_ft, alt_fcst_vis_sm, alt_forecast_basic_vfr |
| Fuel (3) | fuel_to_dest_min, fuel_dest_to_alt_min, fuel_onboard_min |

**Derived facts (9 kinds):** vfr_minimum, violation, svfr, svfr_block, alternate, alt_minimum, alternate_status, fuel_required_min, verdict.

## How the two engines use the rules

- **Forward chaining** (`forward_chain/0`): repeatedly takes the first rule, in file order, whose conditions all hold and whose conclusion is new. It adds that conclusion and records which rule and facts produced it, then starts again, until no rule can add anything. Because the rules are listed in layers (limits, then violations, then Special VFR, and so on, with the verdict last), a rule that says "no violation was found" only runs after every violation rule has had its chance.
- **Backward chaining** (`bc/2`): starts from a goal such as `alternate = required`, finds rules that conclude it, and tries to prove their conditions one by one. It only asks the user when it reaches an input fact that is still unknown.
- The test suite checks that the two engines reach the same verdict on every test scenario.

## Assumptions and limits

- **Airplanes only.** Helicopter rows and the Alaska sunrise clause are left out.
- **Two meanings of "night".** 91.155 and 91.151 say "day" and "night", which this project takes from the 14 CFR 1.1 definition (civil twilight). 91.157(b)(4) says "between sunrise and sunset". So the program asks both questions and uses each where the regulation does.
- **Appendix D, section 3** (airports where Special VFR is prohibited) was not read in full. The program asks you whether your airport is one of them.
- **Left out on purpose:** the 91.155(b) exception for airplanes in a night traffic pattern (Class G, at or below 1,200 ft AGL), ATC's discretion to refuse Special VFR, and the "considering wind and forecast weather" part of the fuel rules. The fuel rules compare two numbers that you enter.
- **Alternate with no approach (r24, r25):** "minimums that allow descent, approach and landing under basic VFR" is reduced to one yes/no question about the forecast.
- **IFR.** The fuel and alternate rules are applied to any flight you say is IFR.
- **Closed world.** "No violation found" means no rule found one from the answers given, not that the flight is safe.
- This is a study project, not a flight planning tool.
