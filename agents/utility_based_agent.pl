% =============================================================================
%  UTILITY-BASED AGENT – Smart Traffic Light
%  Group 1 | AI Agents Assignment
%
%  Description:
%    A Utility-Based Agent assigns a NUMERICAL UTILITY SCORE to every possible
%    action and selects the action with the HIGHEST utility.  This allows it to
%    handle trade-offs (e.g. balancing throughput vs fairness) rather than
%    following rigid rules.
%
%  Utility function components (all contribute to overall utility):
%    1. Throughput score  – reward proportional to vehicles waiting in the
%                           direction that would be given green
%    2. Fairness score    – reward for giving green to the direction that has
%                           been waiting longest (starvation prevention)
%    3. Emergency bonus   – large bonus when an emergency vehicle is present
%    4. Pedestrian bonus  – medium bonus for pedestrian crossing safety
%    5. Phase-change cost – small penalty for switching phases too rapidly
%                           (avoids oscillation / yellow-light thrashing)
%
%  State:
%    wait_time/2     – steps each direction has been waiting without green
%    current_green/1 – direction currently green
%    phase_timer/1   – steps elapsed in the current phase
% =============================================================================

:- module(utility_based_agent, [
        init_utility_agent/0,
        utility_step/2,
        demo/0
    ]).

:- dynamic wait_time/2.
:- dynamic current_green/1.
:- dynamic phase_timer/1.

% Utility weights – easy to tune
weight_throughput(3).
weight_fairness(2).
weight_emergency(100).
weight_pedestrian(50).
weight_phase_change(-5).

min_green_steps(8).

% ---------------------------------------------------------------------------
% init_utility_agent/0 – reset state
% ---------------------------------------------------------------------------
init_utility_agent :-
    retractall(wait_time(_, _)),
    retractall(current_green(_)),
    retractall(phase_timer(_)),
    forall(member(D, [north, south, east, west]), assert(wait_time(D, 0))),
    assert(current_green(none)),
    assert(phase_timer(0)).

% ---------------------------------------------------------------------------
% update_state/2 – update wait times given percepts and the chosen green dir
% ---------------------------------------------------------------------------
update_state(Percepts, GreenDir) :-
    forall(
        member(percept(Dir, Count, _, _), Percepts),
        (   retract(wait_time(Dir, Old)),
            (   Dir == GreenDir -> New = 0
            ;   Count > 0      -> New is Old + 1
            ;   New = 0
            ),
            assert(wait_time(Dir, New))
        )
    ),
    retract(phase_timer(T)), T1 is T + 1, assert(phase_timer(T1)).

% ---------------------------------------------------------------------------
% candidate_actions/2 – enumerate all actions worth considering
% ---------------------------------------------------------------------------
candidate_actions(Percepts, Actions) :-
    findall(set_green(D), member(percept(D, C, _, _), Percepts), GreenActs0),
    % Filter out directions with no vehicles (no utility in greening them)
    findall(set_green(D),
            (member(set_green(D), GreenActs0),
             member(percept(D, C, _, _), Percepts), C > 0),
            GreenActs),
    % Always include keep_green if already green
    (current_green(CG), CG \= none ->
        ExtraActs = [keep_green(CG)]
    ;   ExtraActs = []
    ),
    append(GreenActs, ExtraActs, Actions0),
    (Actions0 = [] -> Actions = [all_red] ; Actions = Actions0).

% ---------------------------------------------------------------------------
% compute_utility/3 – score a candidate action given the percepts
% ---------------------------------------------------------------------------
compute_utility(Percepts, set_green(Dir), Utility) :-
    weight_throughput(Wt),
    weight_fairness(Wf),
    weight_emergency(We),
    weight_phase_change(Wpc),
    % Throughput: vehicles waiting in this direction
    (member(percept(Dir, Count, _, _), Percepts) -> Vcount = Count ; Vcount = 0),
    Throughput is Wt * Vcount,
    % Fairness: how long has this direction been waiting?
    (wait_time(Dir, WT) -> true ; WT = 0),
    Fairness is Wf * WT,
    % Emergency bonus
    (member(percept(Dir, _, _, true), Percepts) -> Emg = We ; Emg = 0),
    % Pedestrian bonus (only for dedicated pedestrian action – 0 here)
    Ped = 0,
    % Phase-change cost: penalise if switching before min phase elapsed
    (current_green(Dir) ->
        PhaseCost = 0
    ;   (phase_timer(T), min_green_steps(Min), T < Min ->
            PhaseCost = Wpc
        ;   PhaseCost = 0
        )
    ),
    Utility is Throughput + Fairness + Emg + Ped + PhaseCost.

compute_utility(Percepts, keep_green(Dir), Utility) :-
    weight_throughput(Wt),
    weight_fairness(Wf),
    (member(percept(Dir, Count, _, _), Percepts) -> Vcount = Count ; Vcount = 0),
    Throughput is Wt * Vcount,
    (wait_time(Dir, WT) -> true ; WT = 0),
    Fairness is Wf * WT,
    % Small bonus for stability (no phase-change cost)
    Stability = 2,
    Utility is Throughput + Fairness + Stability.

compute_utility(_, pedestrian_signal, U)    :- weight_pedestrian(U).
compute_utility(_, emergency_override(_), U):- weight_emergency(U).
compute_utility(_, all_red, 0).

% ---------------------------------------------------------------------------
% best_action/2 – select the action with the highest utility
% ---------------------------------------------------------------------------
best_action(Percepts, BestAction) :-
    % Emergency override always wins
    (member(percept(EDir, _, _, true), Percepts) ->
        BestAction = emergency_override(EDir)
    % Pedestrian safety next
    ;   member(percept(_, _, true, false), Percepts) ->
        BestAction = pedestrian_signal
    % Otherwise: compute utilities and pick the max
    ;   candidate_actions(Percepts, Candidates),
        maplist(scored_action(Percepts), Candidates, Scored),
        sort(0, @>=, Scored, [_Score-BestAction | _])
    ).

scored_action(Percepts, Action, Score-Action) :-
    compute_utility(Percepts, Action, Score).

% ---------------------------------------------------------------------------
% utility_step/2 – one cycle
% ---------------------------------------------------------------------------
utility_step(Percepts, Action) :-
    best_action(Percepts, Action),
    % Determine which direction is now green (for state update)
    (Action = set_green(D) -> GDir = D
    ;   Action = keep_green(D) -> GDir = D
    ;   GDir = none
    ),
    update_state(Percepts, GDir),
    % Update current_green if changed
    (   Action = set_green(D2)
    ->  retractall(current_green(_)), assert(current_green(D2)),
        retractall(phase_timer(_)),   assert(phase_timer(0))
    ;   true
    ).

% ---------------------------------------------------------------------------
% demo/0 – demonstration run
% ---------------------------------------------------------------------------
demo :-
    nl, write('=== Utility-Based Agent – Smart Traffic Light Demo ==='), nl, nl,
    init_utility_agent,
    Steps = [
        [percept(north, 5, false, false), percept(south, 2, false, false),
         percept(east,  1, false, false), percept(west,  8, false, false)],
        [percept(north, 5, false, false), percept(south, 2, false, false),
         percept(east,  1, false, false), percept(west,  8, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 4, false, false), percept(south, 3, false, false),
         percept(east,  2, false, false), percept(west,  7, false, false)],
        [percept(north, 3, false, false), percept(south, 4, false, false),
         percept(east,  3, true,  false), percept(west,  6, false, false)],
        [percept(north, 2, false, false), percept(south, 5, false, false),
         percept(east,  0, false, false), percept(west,  0, false, true)],
        [percept(north, 0, false, false), percept(south, 6, false, false),
         percept(east,  4, false, false), percept(west,  0, false, false)]
    ],
    run_utility_steps(Steps, 1).

run_utility_steps([], _).
run_utility_steps([Percepts | Rest], N) :-
    % Show utilities before deciding
    candidate_actions(Percepts, Cands),
    maplist(show_utility(Percepts, N), Cands),
    utility_step(Percepts, Action),
    format("Step ~w | BEST Action: ~w~n~n", [N, Action]),
    N1 is N + 1,
    run_utility_steps(Rest, N1).

show_utility(Percepts, N, Action) :-
    compute_utility(Percepts, Action, U),
    format("  Step ~w | Action: ~w -> Utility: ~w~n", [N, Action, U]).
