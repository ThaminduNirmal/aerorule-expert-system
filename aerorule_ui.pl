/*  AeroRule web interface
    ------------------------------------------------------------------------
    A browser front end for aerorule.pl. It does not change or copy the
    expert system: it loads aerorule.pl as it is and calls the same
    predicates (input/6, forward_chain/0, bc/2, problems/0, run_tests/0 ...).

    Start it with
        swipl -g ui_start aerorule_ui.pl
    then open  http://localhost:8080/  (the page opens by itself if it can).

    How it works
      The browser keeps the list of answers given so far. Every request sends
      that whole list; the server loads it as facts, lets the engine work,
      and replies with either the next question or the final result. Nothing
      is stored between requests, and only one request touches the fact base
      at a time (a mutex), because the engine keeps its facts in global
      dynamic predicates.

    Educational project. Do not use it to plan a real flight.
*/

:- ensure_loaded(aerorule).

:- use_module(library(http/http_server)).
:- use_module(library(http/http_json)).
:- use_module(library(www_browser)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(memfile)).

:- dynamic ui_dir/1.
:- prolog_load_context(directory, D), assertz(ui_dir(D)).

:- multifile user:file_search_path/2.
:- dynamic user:file_search_path/2.
:- ui_dir(D), directory_file_path(D, ui, U), asserta(user:file_search_path(aerorule_ui, U)).

:- http_handler(root(.),            ui_page,      []).
:- http_handler(root('api/forward'),  api_forward,  [method(post)]).
:- http_handler(root('api/backward'), api_backward, [method(post)]).
:- http_handler(root('api/rules'),    api_rules,    [method(get)]).
:- http_handler(root('api/tests'),    api_tests,    [method(get)]).


%% ========================================================================
%%  Starting the server
%% ========================================================================

% ui_start/0 also opens the page in the default browser; ui_start/1 only
% starts the server on the given port.
ui_start :-
    ui_serve(8080),
    catch(www_open_url('http://localhost:8080/'), _, true),
    ui_wait.

ui_start(Port) :-
    ui_serve(Port),
    ui_wait.

ui_serve(Port) :-
    http_server(http_dispatch, [port(localhost:Port)]),
    format("~nAeroRule web interface running at http://localhost:~w/~n", [Port]),
    format("Press Ctrl+C to stop.~n").

ui_wait :- thread_get_message(ui_never_arrives).

ui_page(Request) :-
    http_reply_file(aerorule_ui('index.html'), [cache(false)], Request).


%% ========================================================================
%%  Forward chaining: one question at a time
%% ========================================================================

api_forward(Request) :-
    http_read_json_dict(Request, Body, [value_string_as(string)]),
    ui_answer_pairs(Body, Pairs),
    with_mutex(aerorule_ui, ui_forward(Pairs, Reply)),
    reply_json_dict(Reply).

ui_forward(Pairs, Reply) :-
    setup_call_cleanup(
        true,
        (   catch(( ui_load_answers(Pairs), forward_chain,
                    ui_forward_reply(Reply) ),
                  ui_bad_answer(Name, Msg),
                  Reply = _{status:"error", name:Name, message:Msg})
        ),
        reset_session).

ui_forward_reply(Reply) :-
    (   ui_next_question(Name)
    ->  ui_question_json(Name, Q),
        input(Name, Group, _, _, _, _),
        ui_group_note(Group, Note),
        Reply = _{status:"question", question:Q, note:Note}
    ;   ui_result_json(R),
        Reply = R.put(status, "done")
    ).

% The same order as forward_session/0 in aerorule.pl: base questions first,
% then Special VFR (only if it is possible), IFR destination, alternate (only
% if one is required) and fuel.
ui_next_question(Name) :-
    member(G, [base,svfr,ifr,alt,fuel]),
    ui_group_active(G),
    input(Name, G, _, Applies, _, _),
    \+ fact(Name, _),
    holds_all(Applies, _),
    !.

ui_group_active(svfr) :- !, fact(svfr, possible).
ui_group_active(alt)  :- !, fact(alternate, required).
ui_group_active(_).

ui_group_note(svfr, "The weather is below VFR minimums, but Special VFR might be possible. A few more questions.") :- !.
ui_group_note(alt,  "An alternate airport is required. Questions about the alternate.") :- !.
ui_group_note(_, "").


%% ========================================================================
%%  Backward chaining: the real bc/2, asked one question at a time
%% ========================================================================
%  bc/2 asks its questions through ask_input/1, which reads standard input.
%  We give it an empty input, so the first missing fact makes it stop with
%  stop_consultation. The prompt it printed just before stopping tells us
%  which question to put to the user. Once every needed fact is known,
%  bc/2 simply succeeds or fails.

api_backward(Request) :-
    http_read_json_dict(Request, Body, [value_string_as(string)]),
    ui_answer_pairs(Body, Pairs),
    (   integer(Body.get(goal)) -> Choice = Body.goal ; Choice = 0 ),
    (   goal_for(Choice, Goal)
    ->  with_mutex(aerorule_ui, ui_backward(Goal, Pairs, Reply))
    ;   Reply = _{status:"error", message:"Pick a goal from 1 to 5."}
    ),
    reply_json_dict(Reply).

ui_backward(Goal, Pairs, Reply) :-
    setup_call_cleanup(
        true,
        catch(( ui_load_answers(Pairs), ui_prove(Goal, Reply) ),
              ui_bad_answer(Name, Msg),
              Reply = _{status:"error", name:Name, message:Msg}),
        ( retractall(no_questions), reset_session )).

ui_prove(Goal, Reply) :-
    retractall(no_questions),
    goal_text(Goal, Text),
    ui_run_bc(Goal, Outcome),
    (   Outcome = proved(Proof)
    ->  Goal = fact(N, V),
        ui_proof(Proof, Node),
        format(string(Ans), "~w = ~w", [N, V]),
        Reply = _{status:"done", goal:Text, proved:true, answer:Ans, proof:Node}
    ;   Outcome = ask(Name)
    ->  ui_question_json(Name, Q),
        Reply = _{status:"question", goal:Text, question:Q, note:""}
    ;   Reply = _{status:"done", goal:Text, proved:false,
                  answer:"This could not be proved from your answers, so the answer is no."}
    ).

ui_run_bc(Goal, Outcome) :-
    new_memory_file(MF),
    setup_call_cleanup(
        (   current_output(OldOut),
            open_memory_file(MF, write, Out),
            set_output(Out),
            stream_property(OldIn, alias(user_input)),
            open_string("", In),
            set_stream(In, alias(user_input))
        ),
        catch(( bc(Goal, Proof) -> R = proved(Proof) ; R = failed ),
              stop_consultation,
              R = asked),
        (   set_output(OldOut),
            set_stream(OldIn, alias(user_input)),
            close(In),
            close(Out)
        )),
    (   R == asked
    ->  memory_file_to_string(MF, Printed),
        (   input(Name, _, _, _, Prompt, _),
            format(string(Printed), "~n~w~n", [Prompt])
        ->  Outcome = ask(Name)
        ;   Outcome = failed
        )
    ;   Outcome = R
    ),
    free_memory_file(MF).


%% ========================================================================
%%  Answers coming from the browser
%% ========================================================================
%  Each answer is checked with the engine's own clean_answer/2 and valid/3,
%  so "y", "3.5", "None" and so on behave exactly as they do at the console.

ui_answer_pairs(Body, Pairs) :-
    (   is_list(Body.get(answers)) -> L = Body.answers ; L = [] ),
    maplist(ui_pair, L, Pairs).

ui_pair(D, Name-Text) :-
    atom_string(Name, D.name),
    format(string(Text), "~w", [D.value]).

ui_load_answers(Pairs) :-
    reset_session,
    forall(member(Name-Text, Pairs), ui_load_one(Name, Text)).

ui_load_one(Name, Text) :-
    (   input(Name, _, Type, _, _, _)
    ->  true
    ;   format(string(M), "Unknown question ~w.", [Name]),
        throw(ui_bad_answer(Name, M))
    ),
    clean_answer(Text, A),
    (   valid(Type, A, V)
    ->  assertz(fact(Name, V))
    ;   throw(ui_bad_answer(Name, "That is not a valid answer."))
    ).


%% ========================================================================
%%  Questions as JSON
%% ========================================================================

ui_question_json(Name, _{name:Name, group:Group, prompt:Prompt, why:Why,
                         rules:IDs, type:TypeJson}) :-
    input(Name, Group, Type, _, Prompt0, Why),
    used_by(Name, IDs),
    ui_type_json(Type, TypeJson),
    ui_clean_prompt(Type, Prompt0, Prompt).

ui_type_json(oneof(L), _{kind:"choice", options:L}).
ui_type_json(number(Min,Max), _{kind:"number", min:Min, max:Max, none:false}).
ui_type_json(number_or_none(Min,Max,_), _{kind:"number", min:Min, max:Max, none:true}).

% The console prompts end with a hint such as "(vfr / ifr)" or "(none if ...)".
% The page has buttons for those, so the hint is cut off.
ui_clean_prompt(Type, Prompt0, Prompt) :-
    (   Type \= number(_,_),
        sub_string(Prompt0, Before, _, 0, Tail),
        string_concat("  (", _, Tail),
        string_concat(_, ")", Tail),
        \+ ( sub_string(Tail, S, _, _, "  (" ), S > 0 )
    ->  sub_string(Prompt0, 0, Before, _, Prompt)
    ;   Prompt = Prompt0
    ).


%% ========================================================================
%%  The final result of a consultation
%% ========================================================================

ui_result_json(_{verdict:Verdict, problems:Problems, fired:Fired, tree:Tree}) :-
    (   fact(verdict, legal) -> Verdict = "legal" ; Verdict = "not_legal" ),
    with_output_to(string(P0), problems),
    split_string(P0, "\n", "", Ls0),
    exclude(ui_blank_or_heading, Ls0, Problems),
    findall(_{id:ID, name:Name, source:Src, conclusion:C},
            ( derived(fact(N,V), ID, _),
              rule_info(ID, Name, Src),
              format(string(C), "~w = ~w", [N,V]) ),
            Fired),
    ui_roots(Roots),
    ui_trees(Roots, [], Tree).

ui_blank_or_heading(S) :- normalize_space(string(T), S), ( T == "" ; T == "Why not:" ), !.

% same choice as report/0: explain the verdict if legal, else the key facts
ui_roots([fact(verdict,legal)]) :- fact(verdict, legal), !.
ui_roots(Roots) :- findall(F, ( key_fact(F), derived(F,_,_) ), Roots).

ui_trees([], _, []).
ui_trees([F|Fs], S0, [T|Ts]) :-
    ui_tree(F, S0, S1, T),
    ui_trees(Fs, S1, Ts).

ui_tree(F, S0, S, Node) :-
    F = fact(N, V),
    format(string(Text), "~w = ~w", [N,V]),
    (   derived(F, ID, Support)
    ->  (   memberchk(F, S0)
        ->  S = S0, Node = _{kind:"ref", text:Text}
        ;   rule_info(ID, Name, Src),
            ui_supports(Support, [F|S0], S, Kids),
            Node = _{kind:"rule", text:Text, rule:ID, name:Name, source:Src, children:Kids}
        )
    ;   S = S0, Node = _{kind:"given", text:Text}
    ).

ui_supports([], S, S, []).
ui_supports([X|Xs], S0, S, [K|Ks]) :-
    ui_support(X, S0, S1, K),
    ui_supports(Xs, S1, S, Ks).

ui_support(fact(N,V), S0, S, K) :- !, ui_tree(fact(N,V), S0, S, K).
ui_support(absent(N,_), S, S, _{kind:"absent", text:T}) :- !,
    format(string(T), "no ~w was found", [N]).
ui_support(test(C), S, S, _{kind:"check", text:T}) :- ui_check_text(C, T).

ui_check_text(C, T) :-
    with_output_to(string(T0), show_check(C)),
    split_string(T0, "", "\n", [T]).


%% ------------------------------------------------------------------------
%%  A backward-chaining proof as JSON
%% ------------------------------------------------------------------------

ui_proof(given(N,V), _{kind:"given", text:T}) :-
    format(string(T), "~w = ~w", [N,V]).
ui_proof(by(fact(N,V), ID, Src, Subs), _{kind:"rule", text:T, rule:ID, name:Name,
                                         source:Src, children:Kids}) :-
    format(string(T), "~w = ~w", [N,V]),
    rule_info(ID, Name, _),
    ui_proofs(Subs, Kids).
ui_proof(absent(N,_), _{kind:"absent", text:T}) :-
    format(string(T), "no ~w was found", [N]).
ui_proof(test(C), _{kind:"check", text:T}) :- ui_check_text(C, T).

% an alt(...) step is only a choice between condition groups; its conditions
% are shown at the same level as their neighbours, like print_proof/2 does
ui_proofs([], []).
ui_proofs([alt(Subs)|Rest], Nodes) :- !,
    ui_proofs(Subs, N1),
    ui_proofs(Rest, N2),
    append(N1, N2, Nodes).
ui_proofs([P|Rest], [N|Ns]) :-
    ui_proof(P, N),
    ui_proofs(Rest, Ns).


%% ========================================================================
%%  The rule list
%% ========================================================================

api_rules(_Request) :-
    findall(ID, rule(ID,_,_,_,_), L0), list_to_set(L0, IDs),
    findall(R, ( member(ID, IDs), ui_rule_json(ID, R) ), Rules),
    findall(_{short:S, title:T, url:U}, regulation(S,T,U), Regs),
    reply_json_dict(_{rules:Rules, regulations:Regs}).

ui_rule_json(ID, _{id:ID, name:Name, source:Src, variants:Vs}) :-
    rule_info(ID, Name, Src),
    findall(_{'if':Conds, then:Then},
            ( rule(ID,_,_,C0,fact(N0,V0)),
              % one numbervars over the whole rule, so A means the same thing everywhere in it
              copy_term(C0-(N0=V0), C-Concl),
              numbervars(C-Concl, 0, _),
              maplist(ui_cond_text_, C, Conds),
              ui_eq_text(Concl, Then) ),
            Vs).

ui_eq_text(N=V, T) :-
    ui_term_text(N, TN), ui_term_text(V, TV),
    format(string(T), "~w = ~w", [TN, TV]).
ui_cond_text_(surface_class, "airspace is Class B, C, D or E") :- !.
ui_cond_text_(fact(N,V), T)  :- !, ui_eq_text(N=V, T).
ui_cond_text_(no(N,_), T)    :- !, format(string(T), "no ~w is known", [N]).
ui_cond_text_(lt(A,B), T)    :- !, ui_cmp(A, "<", B, T).
ui_cond_text_(le(A,B), T)    :- !, ui_cmp(A, "<=", B, T).
ui_cond_text_(gt(A,B), T)    :- !, ui_cmp(A, ">", B, T).
ui_cond_text_(ge(A,B), T)    :- !, ui_cmp(A, ">=", B, T).
ui_cond_text_(eq(A,B), T)    :- !, ui_cmp(A, "is", B, T).
ui_cond_text_(calc(X,E), T)  :- !, ui_term_text(X, TX), ui_term_text(E, TE), format(string(T), "~w is ~w", [TX, TE]).
ui_cond_text_(any(Alts), T)  :- !,
    findall(S, ( member(Alt, Alts), maplist(ui_cond_text_, Alt, Ts),
                 atomic_list_concat(Ts, ' and ', S0), format(string(S), "(~w)", [S0]) ), Ss),
    atomic_list_concat(Ss, ' or ', Body),
    format(string(T), "one of: ~w", [Body]).
ui_cond_text_(C, T) :- ui_term_text(C, T).

ui_cmp(A, Op, B, T) :-
    ui_term_text(A, TA), ui_term_text(B, TB),
    format(string(T), "~w ~w ~w", [TA, Op, TB]).

ui_term_text(Term, Text) :-
    format(string(Text), "~W", [Term, [numbervars(true), quoted(false), spacing(next_argument)]]).


%% ========================================================================
%%  The built-in tests
%% ========================================================================

api_tests(_Request) :-
    with_mutex(aerorule_ui,
               setup_call_cleanup(true,
                                  with_output_to(string(Out), run_tests),
                                  reset_session)),
    split_string(Out, "\n", "", Lines),
    reply_json_dict(_{output:Out, lines:Lines}).


%% ========================================================================
%%  Self-test of the web layer (no browser, no HTTP)
%% ========================================================================
%  Plays every scenario of the built-in test list (case/6 in aerorule.pl)
%  through the same code the web page uses, answering each question the page
%  would ask, and checks that the verdict matches the expected one. It also
%  checks that the goal-driven route reaches the same verdict.
%
%      swipl -q -g ui_selftest -t halt aerorule_ui.pl

ui_selftest :-
    findall(R, ( case(Name, Kind, Over, Expected, _, _),
                 ui_selftest_case(Name, Kind, Over, Expected, R) ), Rs),
    include(==(pass), Rs, Passed),
    length(Rs, Total), length(Passed, P),
    format("~n~w of ~w web-interface checks passed~n", [P, Total]),
    (   P == Total -> true ; halt(1) ).

ui_selftest_case(Name, Kind, Over, Expected, Result) :-
    build_facts(Kind, Over, Facts),
    sub_atom(Name, 0, 3, _, Id),
    catch(( ui_drive(fwd, Facts, [], RF),
            ui_drive(bwd, Facts, [], RB),
            ui_verdict(RF, Fwd),
            ui_verdict(RB, Bwd)
          ),
          E, ( Fwd = error(E), Bwd = none )),
    (   Fwd == Expected, Bwd == Expected
    ->  Result = pass, Tag = 'PASS'
    ;   Result = fail, Tag = 'FAIL'
    ),
    format("~w  ~w  expected: ~w  forward: ~w  backward: ~w~n", [Tag, Id, Expected, Fwd, Bwd]).

ui_drive(Mode, Facts, Acc, Reply) :-
    (   Mode == fwd -> ui_forward(Acc, R)
    ;   goal_for(1, G), ui_backward(G, Acc, R)
    ),
    (   R.status == "question"
    ->  Name = R.question.name,
        (   memberchk(Name-V, Facts) -> true ; throw(no_answer_for(Name)) ),
        format(string(T), "~w", [V]),
        append(Acc, [Name-T], Acc1),
        ui_drive(Mode, Facts, Acc1, Reply)
    ;   Reply = R
    ).

ui_verdict(R, legal)     :- ( R.get(verdict) == "legal" ; R.get(proved) == true ), !.
ui_verdict(R, not_legal) :- ( R.get(verdict) == "not_legal" ; R.get(proved) == false ), !.
ui_verdict(R, error(R)).
