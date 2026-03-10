% =============================================================================
%  GOAL-BASED AGENT – Smart Traffic Light
%  Group 1 | AI Agents Assignment
%
%  Description:
%    A Goal-Based Agent acts to ACHIEVE a defined goal.  It does not merely
%    react to the current percept; instead it considers which sequence of
%    actions will lead to the desired goal state.
%
%  Goal:
%    "No direction should be waiting for more than MAX_WAIT time steps."
%    (i.e. every direction must get a green phase regularly to prevent
%     starvation / gridlock.)
%
%  Planning approach:
%    The agent builds a plan by iterating over directions that have exceeded
%    their wait threshold.  The plan is stored as a queue of green phases and
%    executed one step at a time.  When no direction is over-threshold, the
%    agent falls back to a round-robin schedule.
%
%  State:
%    waiting_time/2  – how many steps each direction has been waiting
%    plan/1          – ordered list of upcoming green-phase directions
%    current_green/1 – direction currently given green
%    phase_timer/1   – steps elapsed in current green phase
% =============================================================================

:- module(goal_based_agent, [
        init_goal_agent/0,
        goal_step/2,
        goal_satisfied/0,
        demo/0
    ]).

:- dynamic waiting_time/2.
:- dynamic plan/1.
:- dynamic current_green/1.
:- dynamic phase_timer/1.

% Configuration
max_wait(20).          % goal violation threshold (steps)
min_green_steps(8).    % minimum green duration per phase

% ---------------------------------------------------------------------------
% init_goal_agent/0 – initialise all state
% ---------------------------------------------------------------------------
init_goal_agent :-
    retractall(waiting_time(_, _)),
    retractall(plan(_)),
    retractall(current_green(_)),
    retractall(phase_timer(_)),
    Dirs = [north, south, east, west],
    forall(member(D, Dirs), assert(waiting_time(D, 0))),
    assert(plan([])),
    assert(current_green(none)),
    assert(phase_timer(0)).

% ---------------------------------------------------------------------------
% goal_satisfied/0 – true when no direction exceeds the max wait threshold
% ---------------------------------------------------------------------------
goal_satisfied :-
    max_wait(Max),
    \+ (waiting_time(D, W), W > Max,
        format("  [GOAL VIOLATED] ~w has waited ~w steps!~n", [D, W])).

% ---------------------------------------------------------------------------
% update_state/1 – update waiting times from the latest percept
% ---------------------------------------------------------------------------
update_state(Percepts) :-
    current_green(CG),
    forall(
        member(percept(Dir, Count, _, _), Percepts),
        update_dir(Dir, Count, CG)
    ),
    retract(phase_timer(T)), T1 is T + 1, assert(phase_timer(T1)).

update_dir(Dir, Count, CG) :-
    retract(waiting_time(Dir, Old)),
    (   Dir == CG
    ->  New = 0                       % reset when given green
    ;   Count > 0
    ->  New is Old + 1                % increment if vehicles are waiting
    ;   New = 0                       % no vehicles: reset
    ),
    assert(waiting_time(Dir, New)).

% ---------------------------------------------------------------------------
% build_plan/0 – (re)generate the plan to satisfy the goal
%   The plan prioritises directions that are closest to violating the goal.
% ---------------------------------------------------------------------------
build_plan :-
    max_wait(Max),
    % Collect directions that need urgent attention (waiting > half threshold)
    Threshold is Max // 2,
    findall(W-D, (waiting_time(D, W), W > Threshold), Urgent),
    sort(0, @>=, Urgent, Sorted),
    pairs_values(Sorted, UrgentDirs),
    % Fill remaining slots with round-robin of non-urgent directions
    findall(D, (member(D, [north, south, east, west]),
                \+ member(D, UrgentDirs)), OtherDirs),
    append(UrgentDirs, OtherDirs, NewPlan),
    retractall(plan(_)),
    assert(plan(NewPlan)).

% ---------------------------------------------------------------------------
% next_goal_action/1 – consume the next step from the plan
% ---------------------------------------------------------------------------
next_goal_action(set_green(Dir)) :-
    plan([Dir | Rest]),
    phase_timer(T), min_green_steps(Min), T >= Min,
    retractall(plan(_)), assert(plan(Rest)),
    retractall(current_green(_)), assert(current_green(Dir)),
    retractall(phase_timer(_)), assert(phase_timer(0)).

next_goal_action(keep_green(Dir)) :-
    current_green(Dir), Dir \= none,
    phase_timer(T), min_green_steps(Min), T < Min.

next_goal_action(set_green(Dir)) :-
    plan([Dir | _]),
    current_green(none).

next_goal_action(all_red) :-
    plan([]),
    build_plan.

% ---------------------------------------------------------------------------
% goal_step/2 – one agent cycle given a list of current percepts
% ---------------------------------------------------------------------------
goal_step(Percepts, Action) :-
    % Handle emergency override first
    (   member(percept(EDir, _, _, true), Percepts)
    ->  Action = emergency_override(EDir)
    ;   member(percept(_, _, true, false), Percepts)
    ->  Action = pedestrian_signal
    ;   update_state(Percepts),
        % Rebuild plan if empty or goal is at risk
        (plan([]) -> build_plan ; true),
        next_goal_action(Action)
    ).

% ---------------------------------------------------------------------------
% demo/0
% ---------------------------------------------------------------------------
demo :-
    nl, write('=== Goal-Based Agent – Smart Traffic Light Demo ==='), nl, nl,
    init_goal_agent,
    % Each step provides percepts for ALL directions simultaneously
    AllSteps = [
        [percept(north,5,false,false), percept(south,2,false,false),
         percept(east,0,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,2,false,false),
         percept(east,0,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,7,false,false)],
        [percept(north,5,false,false), percept(south,3,false,false),
         percept(east,1,false,false),  percept(west,0,false,false)],
        [percept(north,0,false,false), percept(south,0,false,false),
         percept(east,0,true, false),  percept(west,0,false,false)],
        [percept(north,0,false,false), percept(south,0,false,false),
         percept(east,0,false,false),  percept(west,0,false,true)]
    ],
    run_goal_steps(AllSteps, 1).

run_goal_steps([], _).
run_goal_steps([Percepts | Rest], N) :-
    goal_step(Percepts, Action),
    format("Step ~w | Action: ~w~n", [N, Action]),
    (goal_satisfied ->
        write("  [GOAL OK] All directions within wait threshold.") ; true), nl,
    N1 is N + 1,
    run_goal_steps(Rest, N1).
