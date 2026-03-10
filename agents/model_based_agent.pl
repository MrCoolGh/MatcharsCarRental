% =============================================================================
%  MODEL-BASED REFLEX AGENT – Smart Traffic Light
%  Group 1 | AI Agents Assignment
%
%  Description:
%    A Model-Based Reflex Agent maintains an INTERNAL STATE (model of the
%    world) that persists across time steps.  It combines the current percept
%    with the stored state to choose an action, then updates the state.
%
%  Internal state (dynamic facts):
%    current_green/1        – which direction is currently green
%    phase_timer/1          – how many steps the current phase has been active
%    wait_count/2           – cumulative waiting-vehicle count per direction
%    last_served/1          – direction that was last given a green phase
%
%  Percept term: percept(Direction, VehicleCount, Pedestrian, Emergency)
%  Action term : set_green(Direction) | keep_green(Direction)
%              | pedestrian_signal    | emergency_override(Direction)
%              | cycle_next           | all_red
% =============================================================================

:- module(model_based_agent, [
        init_model/0,
        step/2,
        demo/0
    ]).

% ---------------------------------------------------------------------------
% Dynamic state
% ---------------------------------------------------------------------------
:- dynamic current_green/1.
:- dynamic phase_timer/1.
:- dynamic wait_count/2.
:- dynamic last_served/1.

% Constants
min_green_steps(10).   % minimum steps a phase must stay green
max_green_steps(30).   % maximum steps before forced cycle

% ---------------------------------------------------------------------------
% init_model/0 – reset the internal state to an empty intersection
% ---------------------------------------------------------------------------
init_model :-
    retractall(current_green(_)),
    retractall(phase_timer(_)),
    retractall(wait_count(_, _)),
    retractall(last_served(_)),
    assert(current_green(none)),
    assert(phase_timer(0)),
    assert(last_served(none)),
    Dirs = [north, south, east, west],
    forall(member(D, Dirs), assert(wait_count(D, 0))).

% ---------------------------------------------------------------------------
% update_model/1 – incorporate a new percept into the internal state
% ---------------------------------------------------------------------------
update_model(percept(Dir, Count, _Ped, _Emg)) :-
    % Accumulate waiting counts in the model
    retract(wait_count(Dir, Old)),
    New is Old + Count,
    assert(wait_count(Dir, New)),
    % Advance the phase timer
    retract(phase_timer(T)),
    T1 is T + 1,
    assert(phase_timer(T1)).

% ---------------------------------------------------------------------------
% decide_action/2 – choose an action using current percept + internal state
% ---------------------------------------------------------------------------

% Priority 1 – Emergency override
decide_action(percept(Dir, _, _, true), emergency_override(Dir)) :-
    retractall(current_green(_)), assert(current_green(Dir)),
    retractall(phase_timer(_)),   assert(phase_timer(0)).

% Priority 2 – Pedestrian signal (only when no emergency)
decide_action(percept(_, _, true, false), pedestrian_signal).

% Priority 3 – Keep current green if min phase not yet elapsed
decide_action(percept(_, _, false, false), keep_green(Dir)) :-
    current_green(Dir), Dir \= none,
    phase_timer(T),
    min_green_steps(Min),
    T < Min.

% Priority 4 – Force cycle if max phase exceeded
decide_action(percept(_, _, false, false), cycle_next) :-
    phase_timer(T),
    max_green_steps(Max),
    T >= Max,
    advance_phase.

% Priority 5 – Switch to most congested direction when allowed
decide_action(percept(_, _, false, false), set_green(Best)) :-
    current_green(CG),
    phase_timer(T), min_green_steps(Min), T >= Min,
    most_congested_excluding(CG, Best),
    retractall(last_served(_)), assert(last_served(CG)),
    retractall(current_green(_)), assert(current_green(Best)),
    retractall(phase_timer(_)),   assert(phase_timer(0)).

% Fallback – all red when intersection is empty
decide_action(_, all_red).

% ---------------------------------------------------------------------------
% Helper: find the direction with the highest accumulated wait (excluding CG)
% ---------------------------------------------------------------------------
most_congested_excluding(Exclude, Best) :-
    findall(W-D, (wait_count(D, W), D \= Exclude), Pairs),
    sort(0, @>=, Pairs, [_-Best | _]).

% ---------------------------------------------------------------------------
% advance_phase/0 – round-robin to the next direction
% ---------------------------------------------------------------------------
advance_phase :-
    current_green(CG),
    next_direction(CG, Next),
    retractall(current_green(_)), assert(current_green(Next)),
    retractall(phase_timer(_)),   assert(phase_timer(0)).

next_direction(north, east).
next_direction(east,  south).
next_direction(south, west).
next_direction(west,  north).
next_direction(none,  north).

% ---------------------------------------------------------------------------
% step/2 – one agent cycle: perceive → update model → decide → report
% ---------------------------------------------------------------------------
step(Percept, Action) :-
    update_model(Percept),
    decide_action(Percept, Action).

% ---------------------------------------------------------------------------
% demo/0 – run several steps to show the agent using its internal state
% ---------------------------------------------------------------------------
demo :-
    nl, write('=== Model-Based Reflex Agent – Smart Traffic Light Demo ==='), nl, nl,
    init_model,
    Steps = [
        percept(north, 8,  false, false),
        percept(south, 2,  false, false),
        percept(east,  0,  false, false),
        percept(west,  5,  false, false),
        percept(north, 8,  false, false),   % still serving north (min phase)
        percept(north, 8,  false, false),
        percept(north, 8,  false, false),
        percept(north, 8,  false, false),
        percept(north, 8,  false, false),
        percept(north, 8,  false, false),   % 10 steps elapsed – may switch
        percept(west,  5,  false, false),
        percept(east,  0,  true,  false),   % pedestrian on east
        percept(west,  0,  false, true)     % emergency on west
    ],
    run_steps(Steps, 1).

run_steps([], _).
run_steps([P | Rest], N) :-
    step(P, Action),
    format("Step ~w | Percept: ~w  =>  Action: ~w~n", [N, P, Action]),
    N1 is N + 1,
    run_steps(Rest, N1).
