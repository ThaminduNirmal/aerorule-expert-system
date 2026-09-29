/*  AeroRule web interface (server for your own computer)
    ------------------------------------------------------------------------
    Serves ui/index.html and the JSON calls it makes. All the work is done by
    aerorule_api.pl, which loads aerorule.pl unchanged.

    Start it with
        swipl -g ui_start aerorule_ui.pl
    then open  http://localhost:8080/  (the page opens by itself if it can).
    ui_start(Port) starts it on another port without opening the browser.

    Checks:   swipl -q -g ui_selftest -t halt aerorule_ui.pl

    Educational project. Do not use it to plan a real flight.
*/

:- ensure_loaded(aerorule_api).

:- use_module(library(http/http_server)).
:- use_module(library(http/http_json)).
:- use_module(library(www_browser)).

:- dynamic ui_dir/1.
:- prolog_load_context(directory, D), assertz(ui_dir(D)).

:- multifile user:file_search_path/2.
:- dynamic user:file_search_path/2.
:- ui_dir(D), directory_file_path(D, ui, U), asserta(user:file_search_path(aerorule_ui, U)).

:- http_handler(root(.),              ui_page,      []).
:- http_handler(root('api/forward'),  api_forward,  [method(post)]).
:- http_handler(root('api/backward'), api_backward, [method(post)]).
:- http_handler(root('api/rules'),    api_rules,    [method(get)]).
:- http_handler(root('api/tests'),    api_tests,    [method(get)]).


%% ------------------------------------------------------------------------
%%  Starting the server
%% ------------------------------------------------------------------------

% ui_start/0 also opens the page in the default browser; ui_start/1 only
% starts the server on the given port. Only this computer can connect.
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


%% ------------------------------------------------------------------------
%%  The JSON calls
%% ------------------------------------------------------------------------

api_forward(Request)  :- ui_call(forward, Request).
api_backward(Request) :- ui_call(backward, Request).
api_rules(Request)    :- ui_call(rules, Request).
api_tests(Request)    :- ui_call(tests, Request).

ui_call(Kind, Request) :-
    (   memberchk(method(post), Request)
    ->  http_read_json_dict(Request, Body, [value_string_as(string)])
    ;   Body = _{}
    ),
    with_mutex(aerorule_ui, ui_handle(Kind, Body, Reply)),
    reply_json_dict(Reply).