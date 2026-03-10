% =============================================================================
%  SIMPLE REFLEX AGENT – Smart Traffic Light
%  Group 1 | AI Agents Assignment
%
%  Description:
%    A Simple Reflex Agent acts on the CURRENT percept only.
%    It uses a table of condition–action rules (IF–THEN) with NO memory of
%    past states.  Each call to decide_action/2 is completely independent.
%
%  Environment:
%    Four-way intersection: north, south, east, west.
%    Each direction has:
%      - VehicleCount  : integer  (number of vehicles waiting)
%      - Pedestrian    : boolean  (pedestrian button pressed)
%      - Emergency     : boolean  (emergency vehicle detected)
%
%  Percept term: percept(Direction, VehicleCount, Pedestrian, Emergency)
%
%  Actions:  set_green(Direction)
%            set_yellow(Direction)
%            set_red(Direction)
%            pedestrian_signal
%            emergency_override(Direction)
%            all_red
% =============================================================================

:- module(simple_reflex_agent, [decide_action/2]).

% ---------------------------------------------------------------------------
% RULE 1 – Emergency override (highest priority)
%   If any direction has an emergency vehicle, give it an immediate green.
% ---------------------------------------------------------------------------
decide_action(percept(Dir, _Count, _Ped, true), emergency_override(Dir)).

% ---------------------------------------------------------------------------
% RULE 2 – Pedestrian crossing
%   If a pedestrian button is pressed and no emergency exists, allow crossing.
% ---------------------------------------------------------------------------
decide_action(percept(_Dir, _Count, true, false), pedestrian_signal).

% ---------------------------------------------------------------------------
% RULE 3 – Give green to a busy lane
%   If the lane has vehicles waiting and no pedestrian/emergency, set it green.
% ---------------------------------------------------------------------------
decide_action(percept(Dir, Count, false, false), set_green(Dir)) :-
    Count > 0.

% ---------------------------------------------------------------------------
% RULE 4 – Clear lane: set red
%   If no vehicles, no pedestrian, no emergency, the lane stays red.
% ---------------------------------------------------------------------------
decide_action(percept(Dir, 0, false, false), set_red(Dir)).

% ---------------------------------------------------------------------------
% run_agent/1 – demonstrate the agent against a list of percepts
%   Usage: run_agent([percept(north,5,false,false),
%                     percept(south,0,true,false),
%                     percept(east,0,false,true)]).
% ---------------------------------------------------------------------------
run_agent([]).
run_agent([Percept | Rest]) :-
    decide_action(Percept, Action),
    format("Percept: ~w  =>  Action: ~w~n", [Percept, Action]),
    run_agent(Rest).

% ---------------------------------------------------------------------------
% demo/0 – run a canned demonstration
% ---------------------------------------------------------------------------
demo :-
    nl, write('=== Simple Reflex Agent – Smart Traffic Light Demo ==='), nl, nl,
    Percepts = [
        percept(north,  5, false, false),   % busy north lane
        percept(south,  0, false, false),   % empty south lane
        percept(east,   3, true,  false),   % vehicles + pedestrian button
        percept(west,   0, false, true),    % emergency vehicle on west
        percept(north,  0, true,  false),   % only pedestrian button
        percept(south,  7, false, false)    % heavy traffic on south
    ],
    run_agent(Percepts).
