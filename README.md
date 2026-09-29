# AeroRule

A small expert system, written in Prolog, that checks whether a planned flight is legal to depart under some of the US flight rules (14 CFR Part 91): VFR weather minimums, Special VFR, the IFR alternate-airport rule and fuel reserves.

I built it for Assignment 2 of the Expert Systems module (University of Moratuwa). I picked this field because the rules already exist in writing, so nothing had to be made up. Each of the 30 rules points to the paragraph of the regulation it comes from, and `RULES.md` has the links.

> This is a study project. Please don't use it to plan a real flight.

## What's in the folder

| File | Contents |
|---|---|
| `aerorule.pl` | The whole system in one file: questions, 30 rules, forward and backward chaining, explanations, the menu and the tests |
| `RULES.md` | Every rule in plain words with its source and link, the list of facts, and the assumptions |
| `TESTS.md` | The results of the 98 automatic tests, and how the system was checked |

## How to run it

You only need **SWI-Prolog**. There are no libraries to install.

### On Windows

1. Install SWI-Prolog from <https://www.swi-prolog.org/Download.html> (the "stable release" for Windows).
2. Unzip this folder somewhere, for example on the Desktop.
3. Start the system in one of these ways:
   - Double-click `aerorule.pl`. Windows opens it in SWI-Prolog.
   - Or open SWI-Prolog and use **File > Consult...** to select `aerorule.pl`.
4. You will see `AeroRule loaded`. At the `?-` prompt, type:

   ```
   main.
   ```
   and press Enter. The full stop after `main` is needed here, because this is a Prolog command.

### On macOS or Linux

```
cd aerorule-expert-system
swipl aerorule.pl
?- main.
```

### In the browser (no installation)

1. Open <https://swish.swi-prolog.org/> and click **Program** to create a new program.
2. Paste the whole content of `aerorule.pl` into the left pane.
3. Type `main.` in the query box at the bottom right and press **Run!**.
4. Answer each question in the input box that appears.

I checked the code against SWISH's security rules (see `TESTS.md`), but I have not tried it on the SWISH website itself. If something doesn't work there, please use the local installation.

## Using it

The menu:

```
1. New consultation (forward chaining, full explanation)
2. Ask one question (backward chaining)
3. List the 30 rules and their sources
4. Run the built-in test cases
5. Exit
```

- Type your answer and press Enter: `vfr`, `3.5`, `yes`. A full stop at the end is optional, and capital letters are fine.
- Type `why` at any question to see why it is asked and which rules use the answer.
- Type `none` when there is no ceiling or no cloud nearby.
- Type `quit` to stop a consultation and go back to the menu.

**Option 1** asks about the flight and then prints:

- the result (legal or not legal to depart),
- if not legal, what went wrong and which rule and regulation says so,
- every rule that fired, in order,
- a tree showing how the conclusion was reached, including the numbers compared (for example `check: 160 >= 150`).

**Option 2** lets you choose one question, such as "is an alternate airport required?". The system works backwards from that goal, asks only for the facts it needs, and prints the proof.

## Example to try

Choose option 1 and give these answers. This is a Class D airport in poor weather with a Special VFR clearance:

| Question | Answer |
|---|---|
| VFR or IFR | `vfr` |
| airspace class | `d` |
| altitude MSL | `3000` |
| night | `no` |
| inside surface area | `yes` |
| taking off / landing | `yes` |
| flight visibility | `2` |
| ceiling | `800` |
| ground visibility reported | `yes` |
| ground visibility | `1.5` |
| in cloud | `no` |
| cloud above / below / horizontal | `none`, `none`, `none` |
| between sunrise and sunset | `yes` |
| Special VFR prohibited here | `no` |
| ATC Special VFR clearance | `yes` |
| minutes to destination | `90` |
| minutes of fuel on board | `150` |

Expected result: **LEGAL TO DEPART**. The trace shows that 2 SM is below the Class D minimum of 3 SM (r04, r12), that the ceiling and airport visibility are too low (r14, r15), that Special VFR is therefore possible (r16) and authorised (r17), that the fuel is enough (r26), and finally the verdict (r29).

Answer `no` to the ATC clearance question instead, and the result is **NOT LEGAL**. The report then shows which Special VFR condition failed.

## Running the tests

From the menu choose 4, or type `run_tests.` at the `?-` prompt. From a terminal:

```
swipl -q -g run_tests -t halt aerorule.pl
```

The last lines should read:

```
98 of 98 tests passed
rules triggered at least once: 30 of 30
```

## Limits

Airplanes only (no helicopters). Some exceptions in the regulations are not modelled, for example the night traffic-pattern exception in 91.155(b), and ATC's freedom to refuse Special VFR. The full list is at the end of `RULES.md`.
