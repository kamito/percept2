%% 
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2007-2009. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%

%% @doc Interface for CGI request on graphs used by percept. The module exports two functions that 
%%are implementations for ESI callbacks used by the httpd server. 
%%See http://www.erlang.org//doc/apps/inets/index.html.

-module(percept2_graph).
-export([proc_lifetime/3, graph/3, scheduler_graph/3, 
         ports_graph/3, procs_graph/3,
         activity/3, percentage/3, calltime_percentage/3]).

-export([query_fun_time/3, memory_graph/3]).

-compile(export_all).

-include("../include/percept2.hrl").
-include_lib("kernel/include/file.hrl").

%% API

%% graph
%% @spec graph(SessionID, Env, Input) -> term()
%% @doc An ESI callback implementation used by the httpd server. 
%% 

graph(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(graph(Env, Input))).
 
%% activity
%% @spec activity(SessionID, Env, Input) -> term() 
%% @doc An ESI callback implementation used by the httpd server.

activity(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    StartTs = percept2_db:select({system, start_ts}),
    mod_esi:deliver(SessionID, binary_to_list(activity_bar(Env, Input, StartTs))).

proc_lifetime(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(proc_lifetime(Env, Input))).

query_fun_time(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(query_fun_time(Env, Input))).
   
percentage(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(percentage(Env,Input))).

calltime_percentage(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(calltime_percentage(Env,Input))).

scheduler_graph(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(scheduler_graph(Env, Input))).

ports_graph(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(ports_graph(Env, Input))).

procs_graph(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(procs_graph(nv, Input))).

memory_graph(SessionID, Env, Input) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, binary_to_list(memory_graph(Env, Input))).


graph(_Env, Input) ->
    graph_1(_Env, Input, procs_ports).

procs_graph(_Env, Input) ->
    graph_1(_Env, Input, procs).

ports_graph(_Env, Input) ->
    graph_1(_Env, Input, ports).

graph_1(_Env, Input, Type) ->
    io:format("graph input:\n~p\n", [Input]),
    io:format("Type:\n~p\n", [Type]),
    Query    = httpd:parse_query(Input),
    RangeMin = percept2_html:get_option_value("range_min", Query),
    RangeMax = percept2_html:get_option_value("range_max", Query),
    Pids     = percept2_html:get_option_value("pids", Query),
    Width    = percept2_html:get_option_value("width", Query),
    Height   = percept2_html:get_option_value("height", Query),
    
     % seconds2ts
    StartTs  = percept2_db:select({system, start_ts}),
    TsMin    = percept2_utils:seconds2ts(RangeMin, StartTs),
    TsMax    = percept2_utils:seconds2ts(RangeMax, StartTs),
    
    % Convert Pids to id option list
    IDs      = [ {id, ID} || ID <- Pids],
       
    case IDs/=[] of 
        true -> 
            Options  = [{ts_min, TsMin},{ts_max, TsMax} | IDs],
            Acts     = percept_db:select({activity, Options}),
            Counts=percept_analyzer:activities2count2(Acts, StartTs),
            percept2_image:graph(Width, Height, Counts);
        false ->                
            Options  = [{ts_min, TsMin},{ts_max, TsMax}],
            Counts = case Type of 
                         procs_ports ->
                             [{?seconds(TS, StartTs), Procs, Ports}||
                                     {TS, {Procs, Ports}}
                                         <-percept2_db:select(
                                             {activity,{runnable_counts, Options}})];
                         procs ->
                             [{?seconds(TS, StartTs), Procs, 0}||
                                 {TS, {Procs, _Ports}}
                                     <-percept2_db:select(
                                         {activity,{runnable_counts, Options}})];
                         ports ->
                             [{?seconds(TS, StartTs), 0, Ports}||
                                 {TS, {_Procs, Ports}}
                                     <-percept2_db:select(
                                         {activity,{runnable_counts, Options}})]
                     end,
            percept2_image:graph(Width, Height, Counts)
    end.

scheduler_graph(_Env, Input) ->
    io:format("scheduler graph: ~p\n", [Input]),
    Query    = httpd:parse_query(Input),
    RangeMin = percept2_html:get_option_value("range_min", Query),
    RangeMax = percept2_html:get_option_value("range_max", Query),
    Width    = percept2_html:get_option_value("width", Query),
    Height   = percept2_html:get_option_value("height", Query),
    
    StartTs  = percept2_db:select({system, start_ts}),
    TsMin    = percept2_utils:seconds2ts(RangeMin, StartTs),
    TsMax    = percept2_utils:seconds2ts(RangeMax, StartTs),
    

    Acts     = percept2_db:select({scheduler, [{ts_min, TsMin}, {ts_max,TsMax}]}),
    %% io:format("Acts:\n~p\n", [Acts]),
    Counts   = [{?seconds(Ts, StartTs), Scheds, 0} || #scheduler{timestamp = Ts, active_scheds=Scheds} <- Acts],
    percept2_image:graph(Width, Height, Counts).

memory_graph(Env, Input) ->
    scheduler_graph(Env, Input). %% change this!
 
activity_bar(_Env, Input, StartTs) ->
    Query  = httpd:parse_query(Input),
    Pid    = percept2_html:get_option_value("pid", Query),
    Min    = percept2_html:get_option_value("range_min", Query),
    Max    = percept2_html:get_option_value("range_max", Query),
    Width  = percept2_html:get_option_value("width", Query),
    Height = percept2_html:get_option_value("height", Query),
    
    Data    = percept2_db:select({activity, [{id, Pid}]}),
    Activities = [{?seconds(Ts, StartTs), State} || #activity{timestamp = Ts, state = State} <- Data],
    percept2_image:activities(Width, Height, {Min,Max}, Activities).

proc_lifetime(_Env, Input) ->
    Query = httpd:parse_query(Input),
    ProfileTime = percept2_html:get_option_value("profiletime", Query),
    Start = percept2_html:get_option_value("start", Query),
    End = percept2_html:get_option_value("end", Query),
    Width = percept2_html:get_option_value("width", Query),
    Height = percept2_html:get_option_value("height", Query),
    percept2_image:proc_lifetime(round(Width), round(Height), float(Start), float(End), float(ProfileTime)).


query_fun_time(_Env, Input) ->
    Query = httpd:parse_query(Input),
    QueryStart = percept2_html:get_option_value("query_start", Query),
    FunStart = percept2_html:get_option_value("fun_start", Query),
    QueryEnd = percept2_html:get_option_value("query_end", Query),
    FunEnd = percept2_html:get_option_value("fun_end", Query),
    Width = percept2_html:get_option_value("width", Query),
    Height = percept2_html:get_option_value("height", Query),
    percept2_image:query_fun_time(
        round(Width), round(Height), {float(QueryStart),float(FunStart)},
        {float(QueryEnd), float(FunEnd)}).
    

percentage(_Env, Input) ->
    Query = httpd:parse_query(Input),
    Width = percept2_html:get_option_value("width", Query),
    Height = percept2_html:get_option_value("height", Query),
    Percentage = percept2_html:get_option_value("percentage", Query),
    percept2_image:percentage(round(Width), round(Height), float(Percentage)).


calltime_percentage(_Env, Input) ->
    Query = httpd:parse_query(Input),
    Width = percept2_html:get_option_value("width", Query),
    Height = percept2_html:get_option_value("height", Query),
    CallTime = percept2_html:get_option_value("calltime", Query),
    Percentage = percept2_html:get_option_value("percentage", Query),
    percept2_image:calltime_percentage(round(Width), round(Height), float(CallTime), float(Percentage)).

header() ->
    "Content-Type: image/png\r\n\r\n".