%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2007-2010. All Rights Reserved.
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

-module(percept2_html).
-export([
         overview_page/3,
         concurrency_page/3,
         codelocation_page/3, 
         active_funcs_page/3,
         databases_page/3, 
         load_database_page/3, 
         process_tree_page/3,
         process_info_page/3,
         visualise_process_tree/3,
         func_callgraph_page/3,
         function_info_page/3,
         visualise_callgraph/3,
         summary_report_page/3
        ]).

-export([get_option_value/2]).

-compile(export_all).

-include("../include/percept2.hrl").
-include_lib("kernel/include/file.hrl").

%%% --------------------------- %%%
%%% 	API functions     	%%%
%%% --------------------------- %%%
overview_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        OverviewContent = overview_content(Env, Input),
        deliver_page(SessionID, Menu, OverviewContent)
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.


concurrency_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        Content = concurrency_content(Env, Input),
        deliver_page(SessionID, Menu, Content)
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

codelocation_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        Content = codelocation_content(Env, Input),
        deliver_page(SessionID, Menu, Content)
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

active_funcs_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        Content = active_funcs_content(Env, Input),
        deliver_page(SessionID, Menu, Content)
    catch
        _E1:_E2->
            error_page(SessionID, Env, Input)
    end.

summary_report_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        deliver_page(SessionID, Menu, summary_report_content())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.
    
databases_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        deliver_page(SessionID, Menu, databases_content())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.
    

load_database_page(SessionID, Env, Input) ->
    try
        mod_esi:deliver(SessionID, header()),
        % Very dynamic page, handled differently
        load_database_content(SessionID, Env, Input),
        mod_esi:deliver(SessionID, footer())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

process_tree_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        {Header, Content} = process_page_header_content(Env, Input),
        mod_esi:deliver(SessionID, header(Header)),
        mod_esi:deliver(SessionID, Menu),
        mod_esi:deliver(SessionID, Content),
        mod_esi:deliver(SessionID, footer())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

visualise_process_tree(SessionID, Env, Input) ->
    try
        mod_esi:deliver(SessionID, header()),
        mod_esi:deliver(SessionID, menu(Input)), 
        mod_esi:deliver(SessionID, process_tree_content(Env, Input)),
        mod_esi:deliver(SessionID, footer())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

process_info_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        Content = process_info_content(Env, Input),
        deliver_page(SessionID, Menu, Content)
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

deliver_page(SessionID, Menu, Content) ->
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, Menu),
    mod_esi:deliver(SessionID, Content),
    mod_esi:deliver(SessionID, footer()).


func_callgraph_page(SessionID, Env, Input) ->
    try
        {Header, Content} = func_callgraph_content(SessionID, Env, Input),
        mod_esi:deliver(SessionID, header(Header)),
        mod_esi:deliver(SessionID, menu(Input)),
        mod_esi:deliver(SessionID, Content),
        mod_esi:deliver(SessionID, footer())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

function_info_page(SessionID, Env, Input) ->
    try
        Menu = menu(Input),
        Content = function_info_content(Env, Input),
        deliver_page(SessionID, Menu, Content)
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.

visualise_callgraph(SessionID, Env, Input) ->
    try
        mod_esi:deliver(SessionID, header()),
        mod_esi:deliver(SessionID, menu(Input)), 
        mod_esi:deliver(SessionID, callgraph_time_content(Env, Input)),
        mod_esi:deliver(SessionID, footer())
    catch
        _E1:_E2 ->
            error_page(SessionID, Env, Input)
    end.


%%% --------------------------- %%%
%%% 	loal functions   	%%%
%%% --------------------------- %%%
error_page(SessionID, _Env, _Input) ->
    StackTrace = lists:flatten(
            io_lib:format("~p\n",
                          [erlang:get_stacktrace()])),
    Str="<div>" ++
        "<h3 style=\"text-align:center;\"> Percept Internal Error </h3>" ++
        "<center><h3><p>" ++ StackTrace ++ "</p></h3></center>" ++
        "</div>",
    mod_esi:deliver(SessionID, header()),
    mod_esi:deliver(SessionID, Str),
    mod_esi:deliver(SessionID, footer()).


%%% --------------------------- %%%
%%% 	Content pages     	%%%
%%% --------------------------- %%%

%%% overview content page.
overview_content(Env, Input) ->
    io:format("Input:\n~p\n", [Input]),
    CacheKey = "overview"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env,Input,CacheKey,fun overview_content_1/2).


overview_content_1(_Env, Input) ->
    Query = httpd:parse_query(Input),
    io:format("Query:\n~p\n", [Query]),
    Min = get_option_value("range_min", Query),
    Max = get_option_value("range_max", Query),
    Width  = 1200,
    Height = 600,
    TotalProfileTime = ?seconds((percept2_db:select({system, stop_ts})),
                                (percept2_db:select({system, start_ts}))),
    Procs = percept2_db:select({information, procs_count}),
    Ports = percept2_db:select({information, ports_count}),
    InformationTable = 
	"<table>" ++
	table_line(["Profile time:", TotalProfileTime]) ++
        table_line(["Schedulers:", erlang:system_info(schedulers)]) ++
	table_line(["Processes:", Procs]) ++
        table_line(["Ports:", Ports]) ++
    	table_line(["Min. range:", Min]) ++
    	table_line(["Max. range:", Max]) ++
    	"</table>",
    Header = "
    <div id=\"content\">
    <div>" ++ InformationTable ++ "</div>\n
    <form name=form_area method=POST action=/cgi-bin/percept2_html/overview_page>
    <input name=data_min type=hidden value=" ++ term2html(float(Min)) ++ ">
    <input name=data_max type=hidden value=" ++ term2html(float(Max)) ++ ">\n",
    RangeTable = 
	"<table>"++
	table_line([
	    "Min:", 
	    "<input name=range_min value=" ++ term2html(float(Min)) ++">",
	    "<select name=\"graph_select\" onChange=\"select_image()\">
	      	<option value=\""++ url_graph(Width, Height, Min, Max, []) ++"\">Ports & Processes </option>
                <option value=\""++ url_sched_graph(Width, Height, Min, Max, []) ++"\">Schedulers </option>
                <option value=\""++ url_ports_graph(Width, Height, Min, Max, []) ++"\">Ports </option>
	    	<option value=\""++ url_procs_graph(Width, Height, Min, Max, []) ++"\">Processes </option>
            </select>",
	    "<input type=submit value=Update>"
	    ]) ++
	table_line([
	    "Max:", 
	    "<input name=range_max value=" ++ term2html(float(Max)) ++">",
            "",
	    "<a href=\"/cgi-bin/percept2_html/codelocation_page?range_min=" ++
	    term2html(Min) ++ "&range_max=" ++ term2html(Max) ++"\">Code location</a>"
            ]) ++
    	"</table>",
    MainTable = 
	"<table>" ++
	table_line([div_tag_graph()]) ++
	table_line([RangeTable]) ++
	"</table>",
    Footer = "</div></form>",
    Header ++ MainTable.
    
div_tag_graph() ->
%background:url('/images/loader.gif') no-repeat center;
    "<div id=\"percept_graph\" 
	onMouseDown=\"select_down(event)\" 
	onMouseMove=\"select_move(event)\" 
	onMouseUp=\"select_up(event)\"

	style=\"
	background-size: 100%;
	background-origin: content;
	width: 100%;
	position:relative; 
	\">
	
	<div id=\"percept_areaselect\"
	style=\"background-color:#ef0909;
	position:relative;
	visibility:hidden;
      	border-left: 1px solid #101010;
	border-right: 1px solid #101010;
	z-index:2;
	width:40px;
	height:40px;\"></div></div>".

-spec url_graph(
	Widht :: non_neg_integer(),
	Height :: non_neg_integer(),
	Min :: float(),
	Max :: float(),
	Pids :: [pid()]) -> string().

url_graph(W, H, Min, Max, []) ->
    "/cgi-bin/percept2_graph/graph?range_min="++ term2html(float(Min)) 
    	++ "&range_max=" ++ term2html(float(Max))
	++ "&width=" ++ term2html(float(W))
	++ "&height=" ++ term2html(float(H)).

url_sched_graph(W, H, Min, Max, []) ->
    "/cgi-bin/percept2_graph/scheduler_graph?range_min=" ++ term2html(float(Min)) 
    	++ "&range_max=" ++ term2html(float(Max))
	++ "&width=" ++ term2html(float(W))
	++ "&height=" ++ term2html(float(H)).

url_ports_graph(W, H, Min, Max, []) ->
    "/cgi-bin/percept2_graph/ports_graph?range_min=" ++ term2html(float(Min)) 
    	++ "&range_max=" ++ term2html(float(Max))
	++ "&width=" ++ term2html(float(W))
	++ "&height=" ++ term2html(float(H)).

url_procs_graph(W, H, Min, Max, []) ->
    "/cgi-bin/percept2_graph/procs_graph?range_min=" ++ term2html(float(Min)) 
    	++ "&range_max=" ++ term2html(float(Max))
	++ "&width=" ++ term2html(float(W))
	++ "&height=" ++ term2html(float(H)).

url_memory_graph(W, H, Min, Max, []) ->
    "/cgi-bin/percept2_graph/memory_graph?range_min=" ++ term2html(float(Min)) 
    	++ "&range_max=" ++ term2html(float(Max))
	++ "&width=" ++ term2html(float(W))
	++ "&height=" ++ term2html(float(H)).


%%% concurrency page content.
concurrency_content(Env, Input) ->
    io:format("concurrrenc content\n"),
    CacheKey = "concurrency_content"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun concurrency_content_1/2).

concurrency_content_1(_Env, Input) ->
    io:format("Concurrency content:\n~p\n", [Input]),
    %% Get query
    Query = httpd:parse_query(Input),
    %% Collect selected pids and generate id tags
    Pids = [str_to_internal_pid(PidValue)
            || {PidValue, Case} <- Query, 
               Case == "on", 
               PidValue /= "select_all",
               PidValue /= "include_unshown_procs"],
    io:format("Pids:\n~p\n", [Pids]),
    IDs=case lists:member({"include_unshown_procs","on"}, Query) of 
            true ->
                lists:append([expand_pid(Pid)|| Pid <- Pids]);
            false ->
                [Pid|| Pid <- Pids,
                              not is_dummy_process_pid(Pid)]
        end,
    io:format("IDs:\n~p\n", [IDs]),
   
    StartTs = percept2_db:select({system, start_ts}),
    {MinTs, MaxTs} = percept2_db:select({activity, {min_max_ts, Pids}}),
    {T0, T1} = {?seconds(MinTs, StartTs), ?seconds(MaxTs, StartTs)}, 
    io:format("T0, T1:\n~p\n", [{T0, T1}]),
    PidValues = [pid2str(Pid) || Pid <- IDs],
    %%Generate activity bar requests
    ActivityBarTable = lists:foldl(
                         fun(Pid, Out) ->
                                 ValueString = pid2str(Pid),
                                 Out ++ 
                                     table_line(
                                       [
                                        pid2html(Pid),
                                        "<img onload=\"size_image(this, '" ++ 
                                            image_string_head("activity", [{"pid", ValueString}, {range_min, T0},{range_max, T1},{height, 10}], []) ++
                                            "')\" src=/images/white.png border=0 />"
                                       ])
                         end, [], IDs),
    
    %% Make pids request string
    PidsRequest = join_strings_with(PidValues, ":"),
    io:format("PidRequest:\n~p\n", [PidsRequest]),
    "<div id=\"content\">
    <table cellspacing=0 cellpadding=0 border=0>" ++
    table_line([
    	"",
	"<img onload=\"size_image(this, '" ++ 
	image_string_head("graph", [{"pids", PidsRequest},{range_min, T0}, {range_max, T1}, {height, 400}], []) ++
	"')\" src=/images/white.png border=0 />"
    ]) ++
    ActivityBarTable ++
    "</table></div>\n".

expand_pid(Pid) ->
    case is_dummy_process_pid(Pid) of
        true ->
            [Info] = percept2_db:select({information, Pid}),
            
            [percept2_utils:pid2value(Pid1)||Pid1 <- Info#information.hidden_pids];
        false ->
            [Pid]
    end.

%%% code location content page.
codelocation_content(Env, Input) ->
    CacheKey = "codelocation_content"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun codelocation_content_1/2).
codelocation_content_1(_Env, Input) ->
    Query   = httpd:parse_query(Input),
    Min     = get_option_value("range_min", Query),
    Max     = get_option_value("range_max", Query),
    StartTs = percept2_db:select({system, start_ts}),
    TsMin   = percept2_utils:seconds2ts(Min, StartTs),
    TsMax   = percept2_utils:seconds2ts(Max, StartTs),
    Acts    = percept2_db:select({activity, [{ts_min, TsMin}, {ts_max, TsMax}]}),
    Secs  = [timer:now_diff(A#activity.timestamp,StartTs)/1000 || A <- Acts],
    Delta = cl_deltas(Secs),
    Zip   = lists:zip(Acts, Delta),
    Table = html_table([
	[{th, "delta [ms]"},
	 {th, "time [ms]"},
	 {th, " pid "},
	 {th, "activity"},
	 {th, "module:function/arity"},
	 {th, "#runnables"}]] ++ [[{td, term2html(D)},
	                           {td, term2html(timer:now_diff(A#activity.timestamp,StartTs) / 1000)},
	                           {td, pid2html(A#activity.id)},
	                           {td, term2html(A#activity.state)},
	                           {td, mfa2html(A#activity.where)},
	                           {td, term2html(A#activity.runnable_count)}] || {A, D} <- Zip]),
    "<div id=\"content\">" ++
    Table ++ 
    "</div>".

cl_deltas([])   -> [];
cl_deltas(List) -> cl_deltas(List, [0.0]).
cl_deltas([_], Out)       -> lists:reverse(Out);
cl_deltas([A,B|Ls], Out) -> cl_deltas([B|Ls], [B - A | Out]).

%%% active functions content page.
active_funcs_content(Env, Input) ->
    CacheKey = "active_funcs_content"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun active_funcs_content_1/2).
active_funcs_content_1(_Env, Input) ->
    Query   = httpd:parse_query(Input),
    Min     = get_option_value("range_min", Query),
    Max     = get_option_value("range_max", Query),
    StartTs = percept2_db:select({system, start_ts}),
    TsMin   = percept2_utils:seconds2ts(Min, StartTs),
    TsMax   = percept2_utils:seconds2ts(Max, StartTs),
    ActiveFuns  = percept2_db:select({code,[{ts_min, TsMin}, {ts_max, TsMax}]}),
    case ActiveFuns of 
        [] ->
            "<div style=\"text-align:center;\">" ++
                "<blink><center><h3><p>No function activities recorded " ++
                "for the time interval selected.</p></h3></center><blink>" ++
                "</div>";
        _ ->
            Table = html_table(
                      [[{th, " pid "},
                        {th, "module:function/arity"},
                        {th, "activity"},
                        {th, "function start/end secs"},
                        {th, "monitor start/end secs"}]] ++
                          [[{td, pid2html(element(1, F#funcall_info.id))},
                            {td, term2html(F#funcall_info.func)},
                            {td, make_image_string(F, {Min, Max})},
                            {td, term2html({?seconds((element(2, F#funcall_info.id)), StartTs),
                                            ?seconds((F#funcall_info.end_ts), StartTs)})},
                            {td, term2html({Min, Max})}]
                           || F <- ActiveFuns, ?seconds((F#funcall_info.end_ts), (element(2, F#funcall_info.id))) > 0.01]),
            "<div id=\"content\">" ++ 
                Table ++ 
                "</div>"
    end.

make_image_string(F, {QueryStart, QueryEnd})->
    SystemStartTS = percept2_db:select({system, start_ts}),
    FunStart = ?seconds((element(2, F#funcall_info.id)), SystemStartTS),
    FunEnd = ?seconds((F#funcall_info.end_ts),SystemStartTS),
    image_string(query_fun_time,
                 [{query_start, QueryStart},
                  {fun_start, FunStart},
                  {query_end, QueryEnd},
                  {fun_end, FunEnd},
                  {width, 100},
                  {height, 10}]).

   
summary_report_content() ->
    "<div style=\"text-align:center;\">" ++
        "<blink><center><h3><p>Sorry, this functionality is not supported yet. " ++
        "</div>".
%%% databases content page.
databases_content() ->
    "<div id=\"content\">
	<form name=load_percept_file method=post action=/cgi-bin/percept2_html/load_database_page>
	<center>
	<table>
	    <tr><td>Enter file to analyse:</td><td><input type=hidden name=path /></td></tr>
	    <tr><td><input type=file name=file size=40 /></td><td><input type=submit value=Load onClick=\"path.value = file.value;\" /></td></tr>
	</table>
	</center>
	</form>
	</div>". 

%%% databases content page.
load_database_content(SessionId, _Env, Input) ->
    Query = httpd:parse_query(Input),
    {_,{_,Path}} = lists:keysearch("file", 1, Query),
    {_,{_,File}} = lists:keysearch("path", 1, Query),
    Filename = filename:join(Path, File),
    % Check path/file/filename
    
    mod_esi:deliver(SessionId, "<div id=\"content\">"), 
    case file:read_file_info(Filename) of
	{ok, _} ->
    	    Content = "<center>
    	    Parsing: " ++ Filename ++ "<br>
    	    </center>",
	    mod_esi:deliver(SessionId, Content),
	        case percept2:analyze(Filename) of
		    {error, Reason} ->
	                    mod_esi:deliver(SessionId, error_msg("Analyze" ++ term2html(Reason)));
		    _ ->
		        Complete = "<center><a href=\"/cgi-bin/percept2_html/overview_page\">View</a></center>",
	                mod_esi:deliver(SessionId, Complete)
	        end;
	{error, Reason} ->
	    mod_esi:deliver(SessionId, error_msg("File" ++ term2html(Reason)))
    end,
    mod_esi:deliver(SessionId, "</div>"). 

%%% process tree  page content.
process_page_header_content(Env, Input) ->
    io:format("Process page input:\n~p\n", [Input]),
    CacheKey = "process_tree_page"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun process_page_header_content_1/2).
  
process_page_header_content_1(_Env, Input) ->
    Query   = httpd:parse_query(Input),
    Min     = get_option_value("range_min", Query),
    Max     = get_option_value("range_max", Query),
    StartTs = percept2_db:select({system, start_ts}),
    TsMin   = percept2_utils:seconds2ts(Min, StartTs),
    TsMax   = percept2_utils:seconds2ts(Max, StartTs),
    ProcessTree = percept2_db:gen_compressed_process_tree(),
    ProcessTreeHeader = mk_display_style(ProcessTree),
    Content = processes_content(ProcessTree, {TsMin, TsMax}),
    {ProcessTreeHeader, Content}.

processes_content(ProcessTree, {_TsMin, _TsMax}) ->
    Ports = percept2_db:select({information, ports}),
    SystemStartTS = percept2_db:select({system, start_ts}),
    SystemStopTS = percept2_db:select({system, stop_ts}),
    ProfileTime = ?seconds(SystemStopTS, SystemStartTS),
    io:format("ProfileTime:\n~p\n", [ProfileTime]),
    %% Acts = percept2_db:select({activity, [{ts_min, TsMin}, {ts_max, TsMax}]}),
    %% ActivePids = sets:to_list(sets:from_list([A#activity.id||A<-Acts])),
    %% ActiveProcsInfo=lists:append([percept2_db:select({information, Pid})||Pid <- ActivePids]),
    %% too expensive to calculate active pids in this way.
    ProcsHtml = mk_procs_html(ProcessTree, ProfileTime, []), %%ActiveProcsInfo),
    PortsHtml = lists:foldl(
    	fun (I, Out) -> 
            StartTime = procstarttime(I#information.start),
	    EndTime   = procstoptime(I#information.stop),
	    Prepare = 
	    	table_line([
		    "",
		    pid2html(I#information.id),
		    image_string(proc_lifetime, [
			{profiletime, ProfileTime},
			{start, StartTime},
			{"end", term2html(float(EndTime))},
			{width, 100},
			{height, 10}]),
		    mfa2html(I#information.entry),
		    term2html(I#information.name),
		    pid2html(I#information.parent),
                    integer_to_list(max(0,length(I#information.rq_history)-1)),
                    term2html(info_msg_received(I)),
                    term2html(info_msg_sent(I))
       		]),
		[Prepare|Out]
	end, [], Ports),
    Selector = "<table cellspacing=10>" ++
        "<tr> <td>" ++ "<input onClick='selectall()' type=checkbox name=select_all>Select all" ++ "</td>"
        ++"<td><input type=checkbox name=include_unshown_procs>Include unshown procs"++"</td></tr>" ++
        "<tr> <td> <input type=submit value=Compare> </td>" ++
        "<td align=right width=200> <a href=\"/cgi-bin/percept2_html/visualise_process_tree\">"++
        "<b>Visualise Process Tree</b>"++"</a></td></tr>",
    
    if 
	length(ProcsHtml) > 0 ->
	    ProcsHtmlResult = 
	    "<tr><td><b>Processes</b></td></tr>
	    <tr><td>
 	   <table align=center width=1000 cellspacing=10 border=0>
		<tr>
		<td align=middle width=40><b>Select</b></td>
                <td align=middle width=40> <b>[+/-]</b></td>
		<td align=middle width=80><b>Pid</b></td>
		<td align=middle width=80><b>Lifetime</b></td>
	        <td align=middle width=80><b>Name</b></td>
		<td align=middle width=80><b>Parent</b></td>
                <td align=middle width=80><b>#RQ_chgs</b></td>
                <td align=middle width=80><b>#msgs_received</b></td>
                <td align=middle width=80><b>#msgs_sent</b></td>
                <td align=middle width=100><b>Entrypoint</b></td>
                <td align=middle width=140><b> Callgraph </b></td>    
		</tr>" ++
		lists:flatten(ProcsHtml) ++ 
	    "</table>
	    </td></tr>";
	true ->
	    ProcsHtmlResult = ""
    end,
    if 
	length(PortsHtml) > 0 ->
    	    PortsHtmlResult = " 
	    <tr><td><b>Ports</b></td></tr>
            <table width=900  border=1 cellspacing=10 cellpadding=2>
		<tr>
		<td align=middle width=40><b>Select</b></td>
                <td align=middle width=40> <b>[+/-]</b></td>
		<td align=middle width=80><b>Pid</b></td>
		<td align=middle width=80><b>Lifetime</b></td>
	        <td align=middle width=80><b>Name</b></td>
		<td align=middle width=80><b>Parent</b></td>
                <td align=middle width=80><b>#RQ_chgs</b></td>
                <td align=middle width=80><b>#msgs_received</b></td>
                <td align=middle width=80><b>#msgs_sent</b></td>
                <td align=middle width=100><b>Entrypoint</b></td>
		</tr>" ++
	      lists:flatten(PortsHtml) ++
		"</table>
	    </td></tr>";
	true ->
	    PortsHtmlResult = ""
    end,
    
    Right = "<div>"
        ++ Selector ++ 
        "</div>\n",
    Middle = "<div id=\"content\">
    <table>" ++
        ProcsHtmlResult ++
        %%  PortsHtmlResult ++ 
        "</table>" ++
        Right ++ 
        "</div>\n",
    "<form name=process_select method=POST action=/cgi-bin/percept2_html/concurrency_page>" ++
        Middle ++ 
        "</form>".
       
mk_procs_html(ProcessTree, ProfileTime, ActiveProcsInfo) ->
    lists:foldl(
      fun ({I, Children},Out) ->
              Id=I#information.id,
              StartTime = procstarttime(I#information.start),
              EndTime   = procstoptime(I#information.stop),
              Prepare =
                  table_line([
                              "<input type=checkbox name=" ++ pid2str(I#information.id) ++ ">",
                              expand_or_collapse(Children, Id),
                              case lists:member(I, ActiveProcsInfo) orelse  is_parent(Id, ActiveProcsInfo) of 
                                  true ->pid2html_with_color(I#information.id);
                                  false ->
                                      pid2html(I#information.id)
                              end,
                              image_string(proc_lifetime, [
                                                           {profiletime, ProfileTime},
                                                           {start, StartTime},
                                                           {"end", term2html(float(EndTime))},
                                                           {width, 100},
                                                           {height, 10}]),
                             term2html(I#information.name),
                              pid2html(I#information.parent),
                              integer_to_list(max(0,length(I#information.rq_history)-1)),
                              msg2html(info_msg_received(I)),
                              msg2html(info_msg_sent(I)),
                              mfa2html(I#information.entry),
                              visual_link({I#information.id, undefined, undefined})]),
              SubTable = sub_table(Id, Children, ProfileTime, ActiveProcsInfo),
              [Prepare, SubTable|Out]
      end, [], ProcessTree).



info_msg_received(I) ->
    {No, Size} = I#information.msgs_received,
    AvgSize = case No of 
                  0 -> 0;
                  _ -> Size div No
              end,
    {No, AvgSize}.


%% info_msg_sent(I) ->
%%     {No, SameRq, OtherRqs, Size} = I#information.msgs_sent,
%%     AvgSize = case No of 
%%                   0 -> 0;
%%                   _ -> Size div No
%%               end,
%%     {No, SameRq, OtherRqs, AvgSize}.

info_msg_sent(I) ->
    {No, Size} = I#information.msgs_sent,
    AvgSize = case No of 
                  0 -> 0;
                  _ -> Size div No
              end,
    {No, AvgSize}.


expand_or_collapse(Children, Id) ->
    case Children of 
        [] ->
            "<input type=\"button\", value=\"-\">";
        _ ->
            "<input type=\"button\" id=\"lnk" ++ pid2str(Id) ++
                  "\" onclick = \"return toggle('lnk" ++ pid2str(Id) ++ "', '"
                  ++ mk_table_id(Id) ++ "')\", value=\"+\">"
    end.

mk_table_id(Pid) ->
    "t" ++ [C||C <- pid2str(Pid), not lists:member(C, [46, 60, 62])].

sub_table(_Id, [], _ProfileTime, _) ->
    "";
sub_table(Id, Children, ProfileTime, ActivePids) ->
    SubHtml=mk_procs_html(Children, ProfileTime, ActivePids),
    "<tr><td colspan=\"10\"> <table width=950 cellspacing=10  cellpadding=2 border=1 "
        "id=\""++mk_table_id(Id)++"\", style=\"margin-left:60px;\">" ++
        SubHtml ++ "</table></td></tr>".

mk_display_style(ProcessTrees) ->
    Str = parent_pids(ProcessTrees),
    "\n<style type=\"text/css\">\n" ++
      Str ++ " {display:none;}\n" ++
     "</style>\n".


parent_pids(ProcessTrees) ->
    parent_pids(ProcessTrees, []).
parent_pids([], Out) -> Out;
parent_pids([T|Ts], Out) ->
    case T of 
        {_I,[]} ->
            parent_pids(Ts, Out);
        {I, Children} ->
            if Out==[] ->
                    parent_pids(Children++Ts, Out++"#"
                                ++mk_table_id(I#information.id));
               true ->
                    parent_pids(Children++Ts, Out++",#"
                                ++mk_table_id(I#information.id))
            end
    end.

is_parent(I, ActiveProcsInfo) ->  
    lists:any(fun(P) ->
                      lists:member(I, P#information.ancestors)
              end, ActiveProcsInfo).
  
procstarttime(TS) ->
    case TS of
    	undefined -> 0.0;
	    TS -> ?seconds(TS,(percept2_db:select({system, start_ts})))
    end.

procstoptime(TS) ->
    case TS of
            undefined -> ?seconds((percept2_db:select({system, stop_ts})),
                              (percept2_db:select({system, start_ts})));
	    TS -> ?seconds(TS, (percept2_db:select({system, start_ts})))
    end.




%%% process_info_content
process_info_content(Env, Input) ->
    io:format("Process info Input:\n~p\n", [Input]),
    CacheKey = "process_info"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun process_info_content_1/2).

process_info_content_1(_Env, Input) ->
    Query = httpd:parse_query(Input),
    io:format("Query:\n~p\n", [Query]),
    Pid = get_option_value("pid", Query),
    io:format("Pid:\n~p\n", [Pid]),
    [I] = percept2_db:select({information, Pid}),
    ArgumentString = case I#information.entry of
                         {_, _, Arguments} when is_list(Arguments)-> 
                             lists:flatten(io_lib:write(Arguments, 10));
                             %% lists:flatten([term2html(Arg) ++ "<br>" ||
                             %%                   Arg <- Arguments]);
                         _                 ->
                             ""
                     end,
    TimeTable = html_table([
	[{th, ""}, 
	 {th, "Timestamp"}, 
	 {th, "Profile Time"}],
	[{td, "Start"},
	 term2html(I#information.start),
	 term2html(procstarttime(I#information.start))],
	[{td, "Stop"},
	 term2html(I#information.stop),
	 term2html(procstoptime(I#information.stop))]
	]),   

    InfoTable = html_table
                  ([
                    [{th, "Pid"},        term2html(I#information.id)],
                    [{th, "Name"},       term2html(case is_dummy_process_pid(Pid) of
                                                       true -> dummy_process;
                                                       _ ->I#information.name
                                                   end)],
                    [{th, "Entrypoint"}, mfa2html(I#information.entry)],
                            [{th, "Arguments"},  ArgumentString],
                    [{th, "Timetable"},  TimeTable],
                    [{th, "Parent"},     pid2html(I#information.parent)],
                    [{th, "Children"},   lists:flatten(lists:map(fun(Child) -> pid2html(Child) ++ " " end,
                                                                 I#information.children))],
                    [{th, "RQ_history"}, term2html(lists:reverse(I#information.rq_history))],
                    [{th, "{#msg_received, <br>  avg_msg_size}"},
                     term2html(info_msg_received(I))],
                    [{th, "{#msg_sent, <br> #msg_sent_to_same_RQ, <br> #msg_sent_to_another_RQ,<br> avg_msg_size}"}, 
                     term2html(info_msg_sent(I))]
                   ] ++ case is_dummy_process_pid(Pid) of 
                            true ->
                                [[{th, "Compressed Processes"}, lists:flatten(
                                                                 lists:map(fun(Id) -> pid2html(Id) ++ " " end,
                                                                           I#information.hidden_pids))]];
                            false -> []
                        end),
    PidActivities = percept2_db:select({activity, [{id, Pid}]}),
    WaitingMfas   = percept2_analyzer:waiting_activities(PidActivities),
    TotalWaitTime = lists:sum( [T || {T, _, _} <- WaitingMfas] ),
    MfaTable = html_table([
        [{th, "percentage"},
         {th, "total"},         
         {th, "mean"},
         {th, "stddev"},
         {th, "#recv"},
         {th, "module:function/arity"}]] 
                          ++ [[{td, image_string(percentage, [{width, 100}, {height, 10}, 
                                                              {percentage, Time / TotalWaitTime}])},
                               {td, term2html(Time)},
                               {td, term2html(Mean)},
                               {td, term2html(StdDev)},
                               {td, term2html(N)},
                               {td, mfa2html(MFA)}] || 
                                 {Time, MFA, {Mean, StdDev, N}} <- WaitingMfas]),
    
    "<div id=\"content\">" ++
        InfoTable ++ "<br>" ++
        MfaTable ++
        "</div>".


%%% process tree content.
process_tree_content(_Env, _Input) ->
    ImgFileName="processtree"++".svg",
    ImgFullFilePath = filename:join(
                        [code:priv_dir(percept2), "server_root",
                         "images", ImgFileName]),
    Content = "<div style=\"text-align:center; align:center\">" ++
        "<h3 style=\"text-align:center;\">Process Tree</h3>"++ 
        "<iframe src=\"/images/"++ImgFileName++"\" type=\"image/svg+xml\""++
        "frameborder=\"0\" scrolling=\"auto\" marginheight=\"0\" width=\"80\%\" height=\"75\%\""++
        "></iframe>"++
        "</div>",
    case filelib:is_regular(ImgFullFilePath) of 
        true -> 
            %% file already generated, so reuse.
            Content;  
        false -> 
            case percept2_dot:gen_process_tree_img() of
                ok ->
                    Content;
                no_image ->
                    "<div style=\"text-align:center;\">" ++
                        "<blink><center><h3><p>No process tree generated </p></h3></center><blink>" ++
                        "</div>"
            end
    end.
 
%%% function callgraph content
func_callgraph_content(_SessionID, Env, Input) ->
    CacheKey = "func_callpath"++integer_to_list(erlang:crc32(Input)),
    case ets:info(hisotry_html) of
        undefined ->
            apply(fun func_callgraph_content_1/2, [Env, Input]);
        _ ->
            case ets:lookup(history_html, CacheKey) of 
                [{history_html, CacheKey, HeaderStyleAndContent}] ->
                    HeaderStyleAndContent;
                [] ->
                    HeaderStyleAndContent= apply(fun func_callgraph_content_1/2, [Env, Input]),
                    ets:insert(history_html, 
                               #history_html{id=CacheKey,
                                         content=HeaderStyleAndContent}),
                    HeaderStyleAndContent
            end
    end.

func_callgraph_content_1(_Env, _Input) ->
    %% should Input be used?
    CallTree = ets:tab2list(fun_calltree),
    HeaderStyle = mk_fun_display_style(CallTree),
    Content = functions_content(CallTree),
    {HeaderStyle,Content}. 

functions_content(FunCallTree) ->
    FunsHtml=mk_funs_html(FunCallTree, false),
    Table=if length(FunsHtml) >0 ->
                  "<table border=1 cellspacing=10 cellpadding=2 bgcolor=\"#FFFFFF\">
                  <tr>
	          <td align=left width=80><b> Pid </b></td>
                  <td align=left width=80><b> [+/-] </b></td>
		  <td align=right width=160><b> module:function/arity </b></td>
	          <td align=right width=80><b> call count </b></td>   
                  <td align=right width=120><b> graph visualisation </b></td>    
	          </tr>" ++
                      lists:flatten(FunsHtml) ++ 
                      "</table>" ;
             true ->
                  ""
          end,
    "<div id=\"content\">" ++ 
        Table ++ 
        "</div>".

mk_funs_html(FunCallTree, IsChildren) ->
    lists:foldl(
      fun(F, Out) ->
              Id={Pid, _MFA, _Caller} = F#fun_calltree.id,
              FChildren = lists:reverse(F#fun_calltree.called),
              CNT = F#fun_calltree.cnt,
              Prepare = 
                  if IsChildren ->
                          table_line([pid2str(Pid),
                                      fun_expand_or_collapse(FChildren, Id),
                                      mfa2html_with_link(Id),
                                      term2html(CNT)]);
                     true ->
                          table_line([pid2str(Pid),
                                      fun_expand_or_collapse(FChildren, Id),
                                      mfa2html_with_link(Id),
                                      term2html(CNT),
                                      visual_link(Id)])
                  end,
              SubTable = fun_sub_table(Id, FChildren, true),
              [Prepare, SubTable|Out]
      end, [], lists:reverse(FunCallTree)).

fun_sub_table(_Id, [], _IsChildren) ->
    "";
fun_sub_table(Id={_Pid, _Fun, _Caller},Children, IsChildren) ->
    SubHtml = mk_funs_html(Children, IsChildren),
    "<tr><td colspan=\"10\"> <table cellspacing=10  cellpadding=2 border=1 "
        "id=\""++mk_fun_table_id(Id)++"\" style=\"margin-left:60px;\">" ++
        SubHtml ++ "</table></td></tr>".
     %% "<tr><td colspan=\"10\"> <table width=450 cellspacing=10 "
     
fun_expand_or_collapse(Children, Id) ->
    case Children of 
        [] ->
            "<input type=\"button\", value=\"-\">";
        _ ->
            "<input type=\"button\" id=\"lnk"++id_to_list(Id)++
                "\" onclick = \"return toggle('lnk"++id_to_list(Id)++"', '"
                ++mk_fun_table_id(Id)++"')\", value=\"+\">"
    end.


mk_fun_display_style(FunCallTree) ->
    Str = parent_funs(FunCallTree),
    "\n<style type=\"text/css\">\n" ++
        Str ++ " {display:none;}\n" ++
        "</style>\n".

parent_funs(FunCallTree) ->
    parent_funs(FunCallTree, []).
parent_funs([], Out) ->
    Out;
parent_funs([F|Fs], Out) ->
    Id=F#fun_calltree.id,
    case F#fun_calltree.called of 
        [] -> parent_funs(Fs, Out);
        Children ->
            if Out==[] ->
                    parent_funs(Children++Fs, Out++"#"++mk_fun_table_id(Id));
               true ->
                    parent_funs(Children++Fs, Out++",#"++mk_fun_table_id(Id))
            end
    end.

mk_fun_table_id(Id) ->
    "t"++[C||C<-id_to_list(Id), 
             not lists:member(C,[14,36, 45, 46,47, 60, 62,94])].

id_to_list({Pid, Func, Caller}) -> pid2str(Pid) ++ mfa_to_list(Func) ++ mfa_to_list(Caller).

mfa_to_list({M, F, A}) when is_atom(M) andalso is_atom(F)->
    atom_to_list(M)++atom_to_list(F)++integer_to_list(A);
mfa_to_list(_) -> "undefined".

    
%%%function information
function_info_content(Env, Input) ->
    CacheKey = "function_info"++integer_to_list(erlang:crc32(Input)),
    gen_content(Env, Input, CacheKey, fun function_info_content_1/2).
function_info_content_1(_Env, Input) ->
    Query = httpd:parse_query(Input),
    Pid = get_option_value("pid", Query),
    MFA = get_option_value("mfa", Query),
    [I] = percept2_db:select({information, Pid}),
    [F] = percept2_db:select({funs, {Pid, MFA}}),
    CallersTable = html_table([[{th, " module:function/arity "}, {th, " call count "}]]++
                                  [[{td, mfa2html_with_link({Pid,C})}, {td, term2html(Count)}]||
                                      {C, Count}<-F#fun_info.callers]), 
    CalledTable= html_table([[{th, " module:function/arity "}, {th, " call count "}]]++
                                [[{td, mfa2html_with_link({Pid,C})}, {td, term2html(Count)}]||
                                    {C, Count}<-F#fun_info.called]),
    InfoTable = html_table([
                            [{th, "Pid"},         pid2html(Pid)],
                            [{th, "Entrypoint"},  mfa2html(I#information.entry)],
                            [{th, "M:F/A"},       mfa2html_with_link({Pid, MFA})],
                            [{th, "Call count"}, term2html(F#fun_info.call_count)],
                            [{th, "Accumulated time"}, term2html(F#fun_info.acc_time)],
                            [{th, "Callers"},     CallersTable], 
                            [{th, "Called"},      CalledTable]
                           ]),
    "<div id=\"content\">" ++
     InfoTable ++ "<br>" ++
         "</div>".

callgraph_time_content(Env, Input) ->
    io:format("callgraph input:\n~p\n", [Input]),
    Query = httpd:parse_query(Input),
    Pid = get_option_value("pid", Query),
    io:format("Pid:\n~p\n",[Pid]),
    ImgFileName="callgraph" ++ pid2str(Pid) ++ ".svg",
    ImgFullFilePath = filename:join(
                    [code:priv_dir(percept2), "server_root",
                     "images", ImgFileName]),
    Table = calltime_content(Env,Pid),
    Content = "<div style=\"text-align:center; align:center\">" ++
        "<h3 style=\"text-align:center;\">" ++ pid2html(Pid)++"</h3>"++ 
        "<iframe src=\"/images/"++ImgFileName++"\" type=\"image/svg+xml\""++
        "frameborder=\"0\" scrolling=\"auto\" marginheight=\"0\" width=\"80\%\" height=\"75\%\""++
        "></iframe>"++
        "<h3 style=\"text-align:center;\">" ++ "Accumulated Calltime"++"</h3>"++
        Table++
        "<br></br><br></br>"++
        "</div>",
    case filelib:is_regular(ImgFullFilePath) of 
        true -> Content;  %% file already generated.
        false -> 
            case percept2_dot:gen_callgraph_img(Pid) of
                ok ->
                    Content;
                no_image ->
                    "<div style=\"text-align:center;\">" ++
                        "<h3 style=\"text-align:center;\">" ++ pid2html(Pid)++"</h3>"++ 
                        "<blink><center><h3><p>No data generated </p></h3></center><blink>" ++
                        "</div>"
            end
    end.
        
calltime_content(Env, Pid)->
    CacheKey = "calltime" ++ integer_to_list(erlang:crc32(pid2str(Pid))),
    gen_content(Env, Pid, CacheKey, fun calltime_content_1/2).

calltime_content_1(_Env, Pid) ->
    Elems0 = percept2_db:select({calltime, Pid}),
    Elems = lists:reverse(lists:keysort(1, Elems0)),
    SystemStartTS = percept2_db:select({system, start_ts}),
    SystemStopTS = percept2_db:select({system, stop_ts}),
    ProfileTime = ?seconds(SystemStopTS, SystemStartTS),
    Props = " align=center",
    html_table(
      [[{th, "module:function/arity"},
        {th, "callcount"},
        {th, "accumulated time"}]|
       [[{td, term2html(Func)},
         {td, term2html(CallCount)},
         {td, image_string(calltime_percentage, 
                           [{width,200}, {height, 10}, {calltime, CallTime}, {percentage, CallTime/ProfileTime}])}]
        ||{{_Pid, CallTime}, Func, CallCount}<-Elems]], Props).
   

gen_content(Env,Input,CacheKey,Fun) ->
    case ets:info(history_html) of
        undefined -> 
            apply(Fun, [Env, Input]);
        _ -> 
            case ets:lookup(history_html, CacheKey) of 
                [{history_html, CacheKey, Content}] ->
                    Content;
                [] ->
                    Content= apply(Fun, [Env, Input]),
                    ets:insert(history_html, 
                               #history_html{id=CacheKey,
                                             content=Content}),
                    Content
            end
    end.


%%% --------------------------- %%%
%%% 	Utility functions	%%%
%%% --------------------------- %%%

%% Should be in string stdlib?

join_strings(Strings) ->
    lists:flatten(Strings).

-spec join_strings_with(Strings :: [string()], Separator :: string()) -> string().

join_strings_with([S1, S2 | R], S) ->
    join_strings_with([join_strings_with(S1,S2,S) | R], S);
join_strings_with([S], _) ->
    S.
join_strings_with(S1, S2, S) ->
    join_strings([S1,S,S2]).

%%% Generic erlang2html

-spec html_table(Rows :: [[string() | {'td' | 'th', string()}]]) -> string().
html_table(Rows) ->
    html_table(Rows, "").

html_table(Rows, Props) -> "<table" ++ Props++">" ++ html_table_row(Rows) ++ "</table>".

html_table_row(Rows) -> html_table_row(Rows, odd).
html_table_row([], _) -> "";
html_table_row([Row|Rows], odd ) -> "<tr class=\"odd\">" ++ html_table_data(Row) ++ "</tr>" ++ html_table_row(Rows, even);
html_table_row([Row|Rows], even) -> "<tr class=\"even\">" ++ html_table_data(Row) ++ "</tr>" ++ html_table_row(Rows, odd ).

html_table_data([]) -> "";
html_table_data([{td, Data}|Row]) -> "<td>" ++ Data ++ "</td>" ++ html_table_data(Row);
html_table_data([{th, Data}|Row]) -> "<th>" ++ Data ++ "</th>" ++ html_table_data(Row);
html_table_data([Data|Row])       -> "<td>" ++ Data ++ "</td>" ++ html_table_data(Row).

-spec table_line(Table :: [any()]) -> string().

table_line(List) -> table_line(List, ["<tr>"]).
table_line([], Out) -> lists:flatten(lists:reverse(["</tr>\n"|Out]));
table_line([Element | Elements], Out) when is_list(Element) ->
    table_line(Elements, ["<td>" ++ Element ++ "</td>" |Out]);
table_line([Element | Elements], Out) ->
    table_line(Elements, ["<td>" ++ term2html(Element) ++ "</td>"|Out]).

-spec term2html(any()) -> string().

term2html(Term) when is_float(Term) -> lists:flatten(io_lib:format("~.4f", [Term]));
term2html(Pid={pid, {P1, P2, P3}}) -> "<" ++ pid2str(Pid) ++ ">";
term2html(Term) -> lists:flatten(io_lib:format("~p", [Term])).

-spec mfa2html(MFA :: {atom(), atom(), list() | integer()}) -> string().

mfa2html({Module, Function, Arguments}) when is_list(Arguments) ->
    lists:flatten(io_lib:format("~p:~p/~p", [Module, Function, length(Arguments)]));
mfa2html({Module, Function, Arity}) when is_atom(Module), is_integer(Arity) ->
    lists:flatten(io_lib:format("~p:~p/~p", [Module, Function, Arity]));
mfa2html(_) ->
    "undefined".


%% -spec mfa2html_with_link({Pid::pid(),MFA :: {atom(), atom(), list() | integer()}}) -> string().

mfa2html_with_link({Pid, MFA, _Caller}) ->
    mfa2html_with_link({Pid, MFA});
mfa2html_with_link({Pid, {Module, Function, Arguments}}) when is_list(Arguments) ->
    MFAString=lists:flatten(io_lib:format("~p:~p/~p", [Module, Function, length(Arguments)])),
    MFAValue=lists:flatten(io_lib:format("{~p,~p,~p}", [Module, Function, length(Arguments)])),
    "<a href=\"/cgi-bin/percept2_html/function_info_page?pid=" ++ pid2str(Pid) ++ "&mfa=" ++ MFAValue ++ "\">" ++ MFAString ++ "</a>";
mfa2html_with_link({Pid, {Module, Function, Arity}}) when is_atom(Module), is_integer(Arity) ->
    MFAString=lists:flatten(io_lib:format("~p:~p/~p", [Module, Function, Arity])),
    MFAValue=lists:flatten(io_lib:format("{~p,~p,~p}", [Module, Function, Arity])),
    "<a href=\"/cgi-bin/percept2_html/function_info_page?pid=" ++ pid2str(Pid) ++ "&mfa=" ++ MFAValue ++ "\">" ++ MFAString ++ "</a>";
mfa2html_with_link(_) ->
    "undefined".

mfas2html_with_link(Pid, MFAs) ->
    lists:append(["{"++mfa2html_with_link({Pid,MFA})++", "++term2html(C)++"}"||{MFA, C}<-MFAs]).


visual_link({Pid,{M,F,A}, _})->
    MFAValue=lists:flatten(io_lib:format("{~p,~p,~p}", [M, F, A])), 
    "<a href=\"/cgi-bin/percept2_html/visualise_callgraph?pid=" ++ pid2str(Pid) ++ "&mfa=" ++ MFAValue ++ "\">" ++ "show call graph/time" ++ "</a>";
visual_link({Pid,undefined, _})->
    "<a href=\"/cgi-bin/percept2_html/visualise_callgraph?pid=" ++ pid2str(Pid) ++ "&mfa=" ++ "undefined" ++ "\">" ++ "show callgraph/time" ++ "</a>".

calltime_link(Pid)->
    "<a href=\"/cgi-bin/percept2_html/visualise_callgraph?pid=" ++ pid2str(Pid) ++ "\">" ++ "show ACT" ++ "</a>".

%%% --------------------------- %%%
%%% 	to html          	%%%
%%% --------------------------- %%%
-spec pid2html(Pid :: pid()|pid_value()| port()) -> string().
pid2html(Pid) when is_pid(Pid) ->
    PidString = term2html(Pid),
    PidValue = pid2str(Pid),
    "<a href=\"/cgi-bin/percept2_html/process_info_page?pid="++
        PidValue++"\">"++PidString++"</a>";
pid2html(Pid={pid, _}) ->
    PidString = term2html(Pid),
    PidValue = pid2str(Pid),
    "<a href=\"/cgi-bin/percept2_html/process_info_page?pid="++
        PidValue++"\">"++PidString++"</a>";
pid2html(Pid) when is_port(Pid) ->
    term2html(Pid);
pid2html(_) ->
    "undefined".

pid2html_with_color(Pid) when is_pid(Pid) ->
    PidString = term2html(Pid),
    PidValue = pid2str(Pid),
    "<a href=\"/cgi-bin/percept2_html/process_info_page?pid="++PidValue++"\">"
                  ++"<font color=\"#FF0000\">"++PidString++"</font></a>";
pid2html_with_color(Pid) when is_port(Pid) ->
    term2html(Pid);
pid2html_with_color(_) ->
    "undefined".

msg2html(Msg) ->
    AvgMsgSize = lists:last(tuple_to_list(Msg)),
    %% TODO: generalise this function!
    case AvgMsgSize < 1000 of   
        true ->
            term2html(Msg);
        false ->
            " <font color=\"#FF0000\">"++term2html(Msg)++"</font></a>"
    end.

%%% --------------------------- %%%
%%% 	percept conversions    	%%%
%%% --------------------------- %%%
-spec image_string(Request :: string()) -> string().
image_string(Request) ->
    "<img border=0 src=\"/cgi-bin/percept2_graph/" ++
    Request ++ 
    " \">".
-spec image_string(atom() | string(), list()) -> string().
image_string(Request, Options) when is_atom(Request), is_list(Options) ->
     image_string(image_string_head(erlang:atom_to_list(Request), Options, []));
image_string(Request, Options) when is_list(Options) ->
     image_string(image_string_head(Request, Options, [])).

image_string_head(Request, [{Type, Value} | Opts], Out) when is_atom(Type), is_number(Value) ->
    Opt = join_strings(["?",term2html(Type),"=",term2html(Value)]),
    image_string_tail(Request, Opts, [Opt|Out]);
image_string_head(Request, [{Type, Value} | Opts], Out) ->
    Opt = join_strings(["?",Type,"=",Value]),
    image_string_tail(Request, Opts, [Opt|Out]).

image_string_tail(Request, [], Out) ->
    join_strings([Request | lists:reverse(Out)]);
image_string_tail(Request, [{Type, Value} | Opts], Out) when is_atom(Type), is_number(Value) ->
    Opt = join_strings(["&",term2html(Type),"=",term2html(Value)]),
    image_string_tail(Request, Opts, [Opt|Out]);
image_string_tail(Request, [{Type, Value} | Opts], Out) ->
    Opt = join_strings(["&",Type,"=",Value]),
    image_string_tail(Request, Opts, [Opt|Out]).
        
%%% --------------------------- %%%
%%% 	percept conversions    	%%%
%%% --------------------------- %%%
-spec pid2str(Pid :: pid()) ->  string().
pid2str(Pid) when is_pid(Pid) ->
    String = lists:flatten(io_lib:format("~p", [Pid])),
    lists:sublist(String, 2, erlang:length(String)-2);
pid2str({pid, {P1, P2, P3}}) ->
    integer_to_list(P1)++"."++integer_to_list(P2)++"."++integer_to_list(P3).

    
-spec str_to_internal_pid(Str :: string()) ->  pid_value().
str_to_internal_pid(PidStr) ->
    [P1,P2,P3] = string:tokens(PidStr,"."),
    {pid, {list_to_integer(P1), 
           list_to_integer(P2),
           list_to_integer(P3)}}.

string2mfa(String) ->
    Str=lists:sublist(String, 2, erlang:length(String)-2),
    [M, F, A] = string:tokens(Str, ","),
    F1=case hd(F) of 
           39 ->lists:sublist(F,2,erlang:length(F)-2);
           _ -> F
       end,
    {list_to_atom(M), list_to_atom(F1), list_to_integer(A)}.
    

%%% --------------------------- %%%
%%% 	get value       	%%%
%%% --------------------------- %%%
-type pid_value()::{pid, {pos_integer(), pos_integer(), pos_integer()}}.
-spec get_option_value(Option :: string(), Options :: [{string(),any()}]) ->
	{'error', any()} | boolean() | pid_value() | [pid_value()] | number().
get_option_value(Option, Options) ->
    case lists:keysearch(Option, 1, Options) of
        false -> get_default_option_value(Option);
        {value, {Option, _Value}} when Option == "fillcolor" -> true;
        {value, {Option, Value}} when Option == "pid" ->
            str_to_internal_pid(Value);
        {value, {Option, Value}} when Option == "pids" -> 
             [str_to_internal_pid(PidValue)|| PidValue <- string:tokens(Value,":")];
        {value, {Option, Value}} when Option =="mfa" ->
            string2mfa(Value);
        {value, {Option, Value}} -> get_number_value(Value);
        _ -> {error, undefined}
    end.

get_default_option_value(Option) ->
    case Option of 
    	"fillcolor" -> false;
	"range_min" -> float(0.0);
	"pids" -> [];
	"range_max" ->
            ?seconds((percept2_db:select({system, stop_ts})),
                     (percept2_db:select({system, start_ts})));
        "width" -> 800;
        "height" -> 400;
        _ -> {error, {undefined_default_option, Option}}
    end.
-spec get_number_value(string()) -> number() | {'error', 'illegal_number'}.
get_number_value(Value) ->
    % Try float
    case string:to_float(Value) of
    	{error, no_float} ->
	    % Try integer
	    case string:to_integer(Value) of
		{error, _} -> {error, illegal_number};
		{Integer, _} -> Integer
	    end;
	{error, _} -> {error, illegal_number};
	{Float, _} -> Float
    end.

%%% --------------------------- %%%
%%% 	html prime functions	%%%
%%% --------------------------- %%%
-spec header()->string().
header() -> header([]).

-spec header(HeaderData::string()) -> string().
header(HeaderData) ->
    "Content-Type: text/html\r\n\r\n" ++
    "<html>
    <head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">
    <title>percept2</title>
    <link href=\"/css/percept2.css\" rel=\"stylesheet\" type=\"text/css\">
    <script type=\"text/javascript\" src=\"/javascript/percept_error_handler.js\"></script>
    <script type=\"text/javascript\" src=\"/javascript/percept_select_all.js\"></script>
    <script type=\"text/javascript\" src=\"/javascript/percept_area_select.js\"></script>
    <script type=\"text/javascript\">
           function toggle(lnkid, tbid)
           {
           if(document.all)
		     {document.getElementById(tbid).style.display = document.getElementById(tbid).style.display == \"block\" ? \"none\" : \"block\";}
           else
		    {document.getElementById(tbid).style.display = document.getElementById(tbid).style.display == \"table\" ? \"none\" : \"table\";}
           document.getElementById(lnkid).value = document.getElementById(lnkid).value == \"[-]\" ? \"[+]\" : \"[-]\";
          }
     </script>
    " ++ HeaderData ++"
    </head>
    <body onLoad=\"load_image()\">
   <div id=\"header\"><a href=/index.html>percept2</a></div>\n".

-spec footer() -> string().
footer() ->
    "</body>
     </html>\n". 

-spec menu(Input::string()) -> string().
menu(Input) ->
    Query = httpd:parse_query(Input),
    Min = get_option_value("range_min", Query),
    Max = get_option_value("range_max", Query),
    "<div id=\"menu\" class=\"menu_tabs\">
	<ul>
     	<li><a href=/cgi-bin/percept2_html/databases_page>databases</a></li>
        <li><a href=/cgi-bin/percept2_html/summary_report_page>summary report</a></li>
        <li><a href=/cgi-bin/percept2_html/inter_node_messaging?range_min=" ++
        term2html(Min) ++ "&range_max=" ++ term2html(Max) ++ ">inter-node messaging</a></li>
        <li><a href=/cgi-bin/percept2_html/active_funcs_page?range_min=" ++
        term2html(Min) ++ "&range_max=" ++ term2html(Max) ++ ">function activities</a></li>
        <li><a href=/cgi-bin/percept2_html/process_tree_page?range_min=" ++
        term2html(Min) ++ "&range_max=" ++ term2html(Max) ++ ">processes</a></li>
      	<li><a href=/cgi-bin/percept2_html/overview_page>overview</a></li>
     </ul></div>\n".
    
        
-spec error_msg(Error::string()) -> string().
error_msg(Error) ->
    "<table width=300>
	<tr height=5><td></td> <td></td></tr>
	<tr><td width=150 align=right><b>Error: </b></td> <td align=left>"++ Error ++ "</td></tr>
	<tr height=5><td></td> <td></td></tr>
     </table>\n".


is_dummy_process_pid({pid, {0, 0, _}}) -> true;
is_dummy_process_pid(_) -> false.

%% graph input:
%% "pids=0.23.0:0.36.0&range_min=0.0000&range_max=0.9214&height=400&width=1227"