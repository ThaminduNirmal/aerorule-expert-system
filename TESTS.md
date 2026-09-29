# Test log (Annex C)

Everything below comes from running the program's own test suite:

```
swipl -q -g run_tests -t halt aerorule.pl
```

(SWI-Prolog 9.0.4 on Linux. The same tests run from menu option 4, or with `?- run_tests.`)

**Result: 98 of 98 tests passed. Rules triggered at least once: 30 of 30.**

The suite has five parts:

1. **41 flight scenarios.** Each loads a full set of answers, runs forward chaining, and checks the verdict, that the expected rules fired, and that certain rules did *not* fire.
2. **13 minimum-table checks.** One for each row of the 14 CFR 91.155(a) table, plus the exact boundary values (10,000 ft MSL, 1,200 ft AGL). Exactly one minimum must apply.
3. **2 explanation checks.** The printed report must name the right rule and regulation, and a refusal must say which condition failed.
4. **41 forward/backward agreement checks.** For every scenario, the backward engine must reach the same verdict as the forward engine.
5. **1 backward proof check.** The proof for T03 must go through Special VFR (r17).

## 1. Scenario tests

| # | Scenario | Expected | Actual | Rules fired | Result |
|---|---|---|---|---|---|
| T01 | VFR Class C, good weather | legal | legal | r03, r26, r29 | PASS |
| T02 | VFR flight in Class A | not_legal | not_legal | r01, r26 | PASS |
| T03 | Class D marginal weather, day Special VFR | legal | legal | r04, r12, r14, r15, r16, r17, r26, r29 | PASS |
| T04 | Night Special VFR, pilot not instrument qualified | not_legal | not_legal | r04, r12, r14, r15, r16, r27 | PASS |
| T05 | Night Special VFR, pilot and aircraft qualified | legal | legal | r04, r12, r14, r15, r16, r18, r27, r29 | PASS |
| T06 | Special VFR but only 0.5 SM at the airport | not_legal | not_legal | r04, r12, r14, r15, r16, r17, r19, r26 | PASS |
| T07 | Class G day, 1.5 SM, low altitude | legal | legal | r07, r26, r29 | PASS |
| T08 | Class G night, only 2 SM | not_legal | not_legal | r08, r12, r27 | PASS |
| T09 | Class E at 12,000 ft with 4 SM | not_legal | not_legal | r06, r12, r26 | PASS |
| T10 | Class C, cloud only 300 ft above | not_legal | not_legal | r03, r13, r26 | PASS |
| T11 | VFR night flight, not enough fuel | not_legal | not_legal | r03, r27 | PASS |
| T12 | IFR, good destination weather, no alternate | legal | legal | r20, r28, r30 | PASS |
| T13 | IFR, low destination weather, good precision alternate | legal | legal | r21, r22, r25, r28, r30 | PASS |
| T14 | IFR, non-precision alternate below 800 ft | not_legal | not_legal | r21, r23, r28 | PASS |
| T15 | IFR, destination has no approach, alternate needed | legal | legal | r21, r22, r25, r28, r30 | PASS |
| T16 | IFR, alternate without approach, basic VFR forecast | legal | legal | r21, r24, r25, r28, r30 | PASS |
| T17 | IFR, published alternate minimum overrides 600-2 | not_legal | not_legal | r21, r22, r28 | PASS |
| T18 | IFR, a 1,500 ft ceiling alone triggers an alternate | legal | legal | r21, r22, r25, r28, r30 | PASS |
| T19 | IFR, 2 SM visibility alone triggers an alternate | legal | legal | r21, r22, r25, r28, r30 | PASS |
| T20 | IFR, exactly 2000 ft and 3 SM: no alternate (boundary) | legal | legal | r20, r28, r30 | PASS |
| T21 | Night Special VFR, pilot qualified but aircraft not IFR-equipped | not_legal | not_legal | r04, r12, r14, r15, r16, r27 | PASS |
| T22 | Class C, exactly 3 SM and exactly 500 ft below cloud (boundary) | legal | legal | r03, r26, r29 | PASS |
| T23 | VFR day, fuel exactly at the 30 minute reserve (boundary) | legal | legal | r03, r26, r29 | PASS |
| T24 | VFR day, one minute short of the reserve | not_legal | not_legal | r03, r26 | PASS |
| T25 | IFR, precision alternate forecast at 550 ft (below 600) | not_legal | not_legal | r21, r22, r28 | PASS |
| T26 | Special VFR, flight visibility exactly 1 SM (boundary) | legal | legal | r04, r12, r14, r15, r16, r17, r26, r29 | PASS |
| T27 | Special VFR, flight visibility 0.9 SM | not_legal | not_legal | r04, r12, r14, r15, r16, r26 | PASS |
| T28 | IFR with alternate, 10 minutes short of fuel | not_legal | not_legal | r21, r22, r25, r28 | PASS |
| T29 | IFR without alternate, 1 minute short of fuel | not_legal | not_legal | r20, r28 | PASS |
| T30 | Class A, low ceiling: Special VFR must not rescue it | not_legal | not_legal | r01, r26 | PASS |
| T31 | Class C, flying in cloud | not_legal | not_legal | r03, r13, r26 | PASS |
| T32 | Class C, cloud 1,999 ft away horizontally (needs 2,000) | not_legal | not_legal | r03, r13, r26 | PASS |
| T33 | Class D takeoff, ground visibility 2.5 SM, no Special VFR clearance | not_legal | not_legal | r04, r15, r16, r26 | PASS |
| T34 | Class D takeoff, ground visibility not reported, flight visibility 2.5 SM | not_legal | not_legal | r04, r12, r15, r16, r26 | PASS |
| T35 | Class E surface area at 10,500 ft MSL: no Special VFR above 10,000 | not_legal | not_legal | r06, r12, r26 | PASS |
| T36 | Class G has no surface area: Special VFR must not apply | not_legal | not_legal | r07, r12, r26 | PASS |
| T37 | Special VFR weather but no ATC clearance | not_legal | not_legal | r04, r12, r14, r15, r16, r26 | PASS |
| T38 | Special VFR at an airport where it is prohibited | not_legal | not_legal | r04, r12, r14, r15, r16, r26 | PASS |
| T39 | Special VFR clearance but flying in cloud | not_legal | not_legal | r04, r12, r13, r14, r15, r16, r26 | PASS |
| T40 | IFR, alternate without approach, forecast does not allow basic VFR | not_legal | not_legal | r21, r24, r28 | PASS |
| T41 | IFR, precision alternate with 1.9 SM forecast (needs 2) | not_legal | not_legal | r21, r22, r28 | PASS |

## 2. Minimum table tests

`min(visibility SM, ft below cloud, ft above cloud, horizontal ft)`

| Rule | Expected | Got | Result |
|---|---|---|---|
| r02 | min(3,0,0,0) | min(3,0,0,0) | PASS |
| r03 | min(3,500,1000,2000) | min(3,500,1000,2000) | PASS |
| r04 | min(3,500,1000,2000) | min(3,500,1000,2000) | PASS |
| r05 | min(3,500,1000,2000) | min(3,500,1000,2000) | PASS |
| r06 | min(5,1000,1000,5280) | min(5,1000,1000,5280) | PASS |
| r07 | min(1,0,0,0) | min(1,0,0,0) | PASS |
| r08 | min(3,500,1000,2000) | min(3,500,1000,2000) | PASS |
| r09 | min(1,500,1000,2000) | min(1,500,1000,2000) | PASS |
| r10 | min(3,500,1000,2000) | min(3,500,1000,2000) | PASS |
| r11 | min(5,1000,1000,5280) | min(5,1000,1000,5280) | PASS |
| r06 | min(5,1000,1000,5280) | min(5,1000,1000,5280) | PASS |
| r07 | min(1,0,0,0) | min(1,0,0,0) | PASS |
| r09 | min(1,500,1000,2000) | min(1,500,1000,2000) | PASS |

## 3. Explanation tests

- PASS: explanation text for T03 names rule r17 and 14 CFR 91.157
- PASS: refusal text for T04 says the pilot is not instrument qualified

## 4. Backward chaining agrees with forward chaining

| Scenario | Forward | Backward | Result |
|---|---|---|---|
| T01 | legal | legal | PASS |
| T02 | not_legal | not_legal | PASS |
| T03 | legal | legal | PASS |
| T04 | not_legal | not_legal | PASS |
| T05 | legal | legal | PASS |
| T06 | not_legal | not_legal | PASS |
| T07 | legal | legal | PASS |
| T08 | not_legal | not_legal | PASS |
| T09 | not_legal | not_legal | PASS |
| T10 | not_legal | not_legal | PASS |
| T11 | not_legal | not_legal | PASS |
| T12 | legal | legal | PASS |
| T13 | legal | legal | PASS |
| T14 | not_legal | not_legal | PASS |
| T15 | legal | legal | PASS |
| T16 | legal | legal | PASS |
| T17 | not_legal | not_legal | PASS |
| T18 | legal | legal | PASS |
| T19 | legal | legal | PASS |
| T20 | legal | legal | PASS |
| T21 | not_legal | not_legal | PASS |
| T22 | legal | legal | PASS |
| T23 | legal | legal | PASS |
| T24 | not_legal | not_legal | PASS |
| T25 | not_legal | not_legal | PASS |
| T26 | legal | legal | PASS |
| T27 | not_legal | not_legal | PASS |
| T28 | not_legal | not_legal | PASS |
| T29 | not_legal | not_legal | PASS |
| T30 | not_legal | not_legal | PASS |
| T31 | not_legal | not_legal | PASS |
| T32 | not_legal | not_legal | PASS |
| T33 | not_legal | not_legal | PASS |
| T34 | not_legal | not_legal | PASS |
| T35 | not_legal | not_legal | PASS |
| T36 | not_legal | not_legal | PASS |
| T37 | not_legal | not_legal | PASS |
| T38 | not_legal | not_legal | PASS |
| T39 | not_legal | not_legal | PASS |
| T40 | not_legal | not_legal | PASS |
| T41 | not_legal | not_legal | PASS |

## 5. Backward proof

- PASS: backward proof for T03 goes through r17 (Special VFR)

## Extra checks done while building (not part of the suite above)

These were run with separate scripts during development. They are described here so it is clear how the system was checked.

**Breaking rules on purpose (mutation testing).** 36 small errors were planted in the rules, one at a time: a number changed (for example the 1-2-3 ceiling from 2,000 to 1,000 ft, or the IFR reserve from 45 to 30 minutes), a `<` turned into `=<`, or a condition removed (for example the ATC clearance for Special VFR). **All 36 were caught** by at least one test. Earlier versions of the suite missed 13 of them, which is why tests T31 to T41 and the boundary checks were added.

**Random flights (fuzz testing).** About 20,000 random combinations of answers were run through both engines. For each one I checked that forward and backward chaining give the same verdict, that nothing crashes, and that the result never breaks common sense: never legal in Class A under VFR, never legal with too little fuel, never two different minimums or "alternate required" and "not required" at the same time.

This found one real bug. A VFR flight in Class A with a low ceiling could be "rescued" by Special VFR, because the surface-area rules did not check the airspace class. 14 CFR 91.155(d) only talks about the surface areas of Class B, C, D and E, so r14, r15 and r16 now check that too. T30 and T36 keep it fixed. After the fix, all random flights passed.

**Online editor check.** The program was checked with SWI-Prolog's own `sandbox` library, the security layer the SWISH online editor uses, so that it does not call anything SWISH would block. For this reason input is read with `read_line_to_string/2`, which SWISH supports. It has not been tried on the real SWISH website.

**Input handling.** Answers can be typed with or without a full stop and in any case (`VFR`, `vfr.`, `Yes`). Numbers like `.5` are read as 0.5, and empty or nonsense answers are asked again.

## Raw output

```
===== Scenario tests =====
PASS  T01 VFR Class C, good weather
      expected: legal   actual: legal
      rules fired: [r03,r26,r29]
PASS  T02 VFR flight in Class A
      expected: not_legal   actual: not_legal
      rules fired: [r01,r26]
PASS  T03 Class D marginal weather, day Special VFR
      expected: legal   actual: legal
      rules fired: [r04,r12,r14,r15,r16,r17,r26,r29]
PASS  T04 Night Special VFR, pilot not instrument qualified
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r27]
PASS  T05 Night Special VFR, pilot and aircraft qualified
      expected: legal   actual: legal
      rules fired: [r04,r12,r14,r15,r16,r18,r27,r29]
PASS  T06 Special VFR but only 0.5 SM at the airport
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r17,r19,r26]
PASS  T07 Class G day, 1.5 SM, low altitude
      expected: legal   actual: legal
      rules fired: [r07,r26,r29]
PASS  T08 Class G night, only 2 SM
      expected: not_legal   actual: not_legal
      rules fired: [r08,r12,r27]
PASS  T09 Class E at 12,000 ft with 4 SM
      expected: not_legal   actual: not_legal
      rules fired: [r06,r12,r26]
PASS  T10 Class C, cloud only 300 ft above
      expected: not_legal   actual: not_legal
      rules fired: [r03,r13,r26]
PASS  T11 VFR night flight, not enough fuel
      expected: not_legal   actual: not_legal
      rules fired: [r03,r27]
PASS  T12 IFR, good destination weather, no alternate
      expected: legal   actual: legal
      rules fired: [r20,r28,r30]
PASS  T13 IFR, low destination weather, good precision alternate
      expected: legal   actual: legal
      rules fired: [r21,r22,r25,r28,r30]
PASS  T14 IFR, non-precision alternate below 800 ft
      expected: not_legal   actual: not_legal
      rules fired: [r21,r23,r28]
PASS  T15 IFR, destination has no approach, alternate needed
      expected: legal   actual: legal
      rules fired: [r21,r22,r25,r28,r30]
PASS  T16 IFR, alternate without approach, basic VFR forecast
      expected: legal   actual: legal
      rules fired: [r21,r24,r25,r28,r30]
PASS  T17 IFR, published alternate minimum overrides 600-2
      expected: not_legal   actual: not_legal
      rules fired: [r21,r22,r28]
PASS  T18 IFR, a 1,500 ft ceiling alone triggers an alternate
      expected: legal   actual: legal
      rules fired: [r21,r22,r25,r28,r30]
PASS  T19 IFR, 2 SM visibility alone triggers an alternate
      expected: legal   actual: legal
      rules fired: [r21,r22,r25,r28,r30]
PASS  T20 IFR, exactly 2000 ft and 3 SM: no alternate (boundary)
      expected: legal   actual: legal
      rules fired: [r20,r28,r30]
PASS  T21 Night Special VFR, pilot qualified but aircraft not IFR-equipped
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r27]
PASS  T22 Class C, exactly 3 SM and exactly 500 ft below cloud (boundary)
      expected: legal   actual: legal
      rules fired: [r03,r26,r29]
PASS  T23 VFR day, fuel exactly at the 30 minute reserve (boundary)
      expected: legal   actual: legal
      rules fired: [r03,r26,r29]
PASS  T24 VFR day, one minute short of the reserve
      expected: not_legal   actual: not_legal
      rules fired: [r03,r26]
PASS  T25 IFR, precision alternate forecast at 550 ft (below 600)
      expected: not_legal   actual: not_legal
      rules fired: [r21,r22,r28]
PASS  T26 Special VFR, flight visibility exactly 1 SM (boundary)
      expected: legal   actual: legal
      rules fired: [r04,r12,r14,r15,r16,r17,r26,r29]
PASS  T27 Special VFR, flight visibility 0.9 SM
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r26]
PASS  T28 IFR with alternate, 10 minutes short of fuel
      expected: not_legal   actual: not_legal
      rules fired: [r21,r22,r25,r28]
PASS  T29 IFR without alternate, 1 minute short of fuel
      expected: not_legal   actual: not_legal
      rules fired: [r20,r28]
PASS  T30 Class A, low ceiling: Special VFR must not rescue it
      expected: not_legal   actual: not_legal
      rules fired: [r01,r26]
PASS  T31 Class C, flying in cloud
      expected: not_legal   actual: not_legal
      rules fired: [r03,r13,r26]
PASS  T32 Class C, cloud 1,999 ft away horizontally (needs 2,000)
      expected: not_legal   actual: not_legal
      rules fired: [r03,r13,r26]
PASS  T33 Class D takeoff, ground visibility 2.5 SM, no Special VFR clearance
      expected: not_legal   actual: not_legal
      rules fired: [r04,r15,r16,r26]
PASS  T34 Class D takeoff, ground visibility not reported, flight visibility 2.5 SM
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r15,r16,r26]
PASS  T35 Class E surface area at 10,500 ft MSL: no Special VFR above 10,000
      expected: not_legal   actual: not_legal
      rules fired: [r06,r12,r26]
PASS  T36 Class G has no surface area: Special VFR must not apply
      expected: not_legal   actual: not_legal
      rules fired: [r07,r12,r26]
PASS  T37 Special VFR weather but no ATC clearance
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r26]
PASS  T38 Special VFR at an airport where it is prohibited
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r14,r15,r16,r26]
PASS  T39 Special VFR clearance but flying in cloud
      expected: not_legal   actual: not_legal
      rules fired: [r04,r12,r13,r14,r15,r16,r26]
PASS  T40 IFR, alternate without approach, forecast does not allow basic VFR
      expected: not_legal   actual: not_legal
      rules fired: [r21,r24,r28]
PASS  T41 IFR, precision alternate with 1.9 SM forecast (needs 2)
      expected: not_legal   actual: not_legal
      rules fired: [r21,r22,r28]

===== Minimum table tests (rules r02 - r11) =====
PASS  minimum table, rule r02: expected min(3,0,0,0), got min(3,0,0,0)
PASS  minimum table, rule r03: expected min(3,500,1000,2000), got min(3,500,1000,2000)
PASS  minimum table, rule r04: expected min(3,500,1000,2000), got min(3,500,1000,2000)
PASS  minimum table, rule r05: expected min(3,500,1000,2000), got min(3,500,1000,2000)
PASS  minimum table, rule r06: expected min(5,1000,1000,5280), got min(5,1000,1000,5280)
PASS  minimum table, rule r07: expected min(1,0,0,0), got min(1,0,0,0)
PASS  minimum table, rule r08: expected min(3,500,1000,2000), got min(3,500,1000,2000)
PASS  minimum table, rule r09: expected min(1,500,1000,2000), got min(1,500,1000,2000)
PASS  minimum table, rule r10: expected min(3,500,1000,2000), got min(3,500,1000,2000)
PASS  minimum table, rule r11: expected min(5,1000,1000,5280), got min(5,1000,1000,5280)
PASS  minimum table, rule r06: expected min(5,1000,1000,5280), got min(5,1000,1000,5280)
PASS  minimum table, rule r07: expected min(1,0,0,0), got min(1,0,0,0)
PASS  minimum table, rule r09: expected min(1,500,1000,2000), got min(1,500,1000,2000)

===== Explanation tests =====
PASS  explanation text for T03 names rule r17 and 14 CFR 91.157
PASS  refusal text for T04 says the pilot is not instrument qualified

===== Backward chaining agrees with forward chaining =====
PASS  T01  forward: legal   backward: legal
PASS  T02  forward: not_legal   backward: not_legal
PASS  T03  forward: legal   backward: legal
PASS  T04  forward: not_legal   backward: not_legal
PASS  T05  forward: legal   backward: legal
PASS  T06  forward: not_legal   backward: not_legal
PASS  T07  forward: legal   backward: legal
PASS  T08  forward: not_legal   backward: not_legal
PASS  T09  forward: not_legal   backward: not_legal
PASS  T10  forward: not_legal   backward: not_legal
PASS  T11  forward: not_legal   backward: not_legal
PASS  T12  forward: legal   backward: legal
PASS  T13  forward: legal   backward: legal
PASS  T14  forward: not_legal   backward: not_legal
PASS  T15  forward: legal   backward: legal
PASS  T16  forward: legal   backward: legal
PASS  T17  forward: not_legal   backward: not_legal
PASS  T18  forward: legal   backward: legal
PASS  T19  forward: legal   backward: legal
PASS  T20  forward: legal   backward: legal
PASS  T21  forward: not_legal   backward: not_legal
PASS  T22  forward: legal   backward: legal
PASS  T23  forward: legal   backward: legal
PASS  T24  forward: not_legal   backward: not_legal
PASS  T25  forward: not_legal   backward: not_legal
PASS  T26  forward: legal   backward: legal
PASS  T27  forward: not_legal   backward: not_legal
PASS  T28  forward: not_legal   backward: not_legal
PASS  T29  forward: not_legal   backward: not_legal
PASS  T30  forward: not_legal   backward: not_legal
PASS  T31  forward: not_legal   backward: not_legal
PASS  T32  forward: not_legal   backward: not_legal
PASS  T33  forward: not_legal   backward: not_legal
PASS  T34  forward: not_legal   backward: not_legal
PASS  T35  forward: not_legal   backward: not_legal
PASS  T36  forward: not_legal   backward: not_legal
PASS  T37  forward: not_legal   backward: not_legal
PASS  T38  forward: not_legal   backward: not_legal
PASS  T39  forward: not_legal   backward: not_legal
PASS  T40  forward: not_legal   backward: not_legal
PASS  T41  forward: not_legal   backward: not_legal
PASS  backward proof for T03 goes through r17 (Special VFR)

===== Summary =====
98 of 98 tests passed
rules triggered at least once: 30 of 30
```
