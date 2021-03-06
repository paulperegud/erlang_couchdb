-module(erlang_couchdb_SUITE).
-compile(export_all).

-include_lib("common_test/include/ct.hrl").

-define(CONNECTION, {"localhost", 5984}).
-define(DBNAME, "t_erlang_couchdb_test").

%%--------------------------------------------------------------------
%% Test server callback functions
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: suite() -> DefaultData
%% DefaultData: [tuple()]
%% Description: Require variables and set default values for the suite
%%--------------------------------------------------------------------
suite() -> [{timetrap,{minutes,1}}]
	.

all() ->
	[serverinfo, all_databases, 
	 databaselifecycle, documentlifecycle,
	 createview,
	 viewaccess_nullmap, viewaccess_maponly, viewaccess_mapreduce,
	 parseview
	]     
	.

init_per_suite(Config) ->
	crypto:start(),
	inets:start(),
	case erlang_couchdb:database_info(?CONNECTION, ?DBNAME) of
		{ok, _Res} ->
			erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
			;
		_ -> ok
	end,
	Config
	.

end_per_suite(_Config) ->
	case erlang_couchdb:database_info(?CONNECTION, ?DBNAME) of
		{ok, _Res} ->
			erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
			;
		_ -> ok
	end,
	inets:stop(),
	ok
	.

serverinfo() ->
	[{userdata,[{doc,"Server connection, and information"}]}]
	.

serverinfo(_Config) ->
    {ok, Res} = erlang_couchdb:server_info(?CONNECTION),
    ct:print(test_category, "server info ~p~n", [Res])
	.

all_databases() ->
	[{userdata,[{doc,"all databases information"}]}]
	.

all_databases(_Config) ->
	{ok, Database} = erlang_couchdb:retrieve_all_dbs(?CONNECTION),
    ct:print(test_category, "all databases ~p~n", [Database])
    .

databaselifecycle(_Config) ->
    ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),
    {ok, Res} = erlang_couchdb:database_info(?CONNECTION, ?DBNAME),
    ct:print(test_category, "database info for ~p~n~p~n", [?DBNAME, Res]),
    ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
    .

documentlifecycle() ->
    [{userdata,[{doc,"Document creation, retrieve, and deletion"}]}]
    .

documentlifecycle(_Config) ->
	% setup
    ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),

    {json,{struct,[_, {<<"id">>, Id},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"foo">>, <<"bar">> } ]}),
    ct:print(test_category, "id: ~p", [Id]),
    Doc = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list((Id))),
    ct:print(test_category, "Document: ~p", [Doc]),

	% tear down
    ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
    .


createview() ->
    [{userdata,[{doc,"Documents creation, set view, and deletion"}]}]
    .

createview(_Config) ->
    %   setup
    ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),
    {json,{struct,[_, {<<"id">>, Id},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"D">> } ]}),
    {json,{struct,[_, {<<"id">>, Id2},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"S">> } ]}),
    Doc = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list((Id))),
    ct:print(test_category, "Document: ~p", [Doc]),
    Doc2 = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list(Id2)),
    ct:print(test_category, "Document2: ~p", [Doc2]),
	View1 = "function(doc) { if(doc.type) { emit(doc.type)}}",
    Views = [{"all", View1}],
    Res = erlang_couchdb:create_view(?CONNECTION, ?DBNAME, "testview", <<"javasccript">>, Views, []),
    ct:print("view creation result: ~p~n",[Res]),

	%   tear down
    ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
    .

viewaccess_nullmap() ->
	[{userdata,[{doc,"Documents creation, set null selection view, accessview and deletion"}]}]	.

viewaccess_nullmap(_Config) ->
	%   setup
	ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),

	do_viewaccess_maponly("function(doc) { emit(null, doc)}"),

	% assertion

	%   tear down
	ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
	.

viewaccess_maponly() ->
	[{userdata,[{doc,"Documents creation, set view, accessview and deletion"}]}]	.

viewaccess_maponly(_Config) ->
	%   setup
	ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),

	ResView = do_viewaccess_maponly("function(doc) { if(doc.type) {emit(null, doc.type)}}"),
	ct:print("view access result: ~p~n",[ResView]),

	% assertion
	{json,
          {struct,
                  [{<<"total_rows">>,2},
                  {<<"offset">>,0},
                  {<<"rows">>,
                       [{struct,
                       [{<<"id">>,
                                     _ID1},
                                    {<<"key">>,null},
                                    % {<<"value">>,<<"D">>}]},
                                    {<<"value">>,_B1}]},
                               {struct,
                                   [{<<"id">>,
									 _ID2},
                                    {<<"key">>,null},
                                    % {<<"value">>,<<"S">>}]}]}]}}
                                    {<<"value">>, _B2}]}]}]}}
		= ResView,

	%   tear down
	ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
	.

do_viewaccess_maponly(Viewsource) ->
	do_viewaccess_maponly(Viewsource, fun(X) -> X end)
	.

do_viewaccess_maponly(Viewsource, Cb) ->
	{json,{struct,[_, {<<"id">>, Id},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"D">> } ]}),
	{json,{struct,[_, {<<"id">>, Id2},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"S">> } ]}),
	Doc = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list((Id))),
	ct:print(test_category, "Document: ~p", [Doc]),
	Doc2 = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list(Id2)),
	ct:print(test_category, "Document2: ~p", [Doc2]),
	Views = [{"all", Viewsource}],
	Res = erlang_couchdb:create_view(?CONNECTION, ?DBNAME, "testview", "javascript", Views, []),
	ct:print("view creation result: ~p~n",[Res]),

	% view access
	Cb(erlang_couchdb:invoke_view(?CONNECTION, ?DBNAME, "testview", "all",[]))
	.

parseview() ->
	[{userdata,[{doc,"Parse View request result"}]}]
	.

parseview(_Config) ->
	%   setup
	ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),

	ct:print("parse_view~n",[]),
	ResView = do_viewaccess_maponly("function(doc) { if(doc.type) {emit(null, doc.type)}}", fun(X) -> erlang_couchdb:parse_view(X) end),
	ct:print("parse view access result: ~p~n",[ResView]),

	% assertion
	{2,0,_Array} = ResView,

	%   tear down
	ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
	.

do_viewaccess_mapreduce(Mapsource, Reducesource) ->
	do_viewaccess_mapreduce(Mapsource, Reducesource, fun(X) -> X end)
	.
	
do_viewaccess_mapreduce(Mapsource, Reducesource, Cb) ->
	{json,{struct,[_, {<<"id">>, Id},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"D">> },{<<"val">>, 1} ]}),
	{json,{struct,[_, {<<"id">>, Id2},_]}} = erlang_couchdb:create_document(?CONNECTION, ?DBNAME, {struct, [{<<"type">>, <<"S">> }, {<<"val">>, 2}]}),
	Doc = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list((Id))),
	ct:print(test_category, "Document A: ~p", [Doc]),
	Doc2 = erlang_couchdb:retrieve_document(?CONNECTION, ?DBNAME, binary_to_list(Id2)),
	ct:print(test_category, "Document B: ~p", [Doc2]),
	Views = [{"all", Mapsource, Reducesource}],
	Res = erlang_couchdb:create_view(?CONNECTION, ?DBNAME, "testview", "javascript", Views, []),
	ct:print("view creation result: ~p~n",[Res]),

	% view access
	Cb(erlang_couchdb:invoke_view(?CONNECTION, ?DBNAME, "testview", "all",[]))
	.

viewaccess_mapreduce() ->
	[{userdata,[{doc,"Execute map reduce View request"}]}]
	.

viewaccess_mapreduce(_Config) ->
	%   setup
	ok = erlang_couchdb:create_database(?CONNECTION, ?DBNAME),

	ct:print("mapreduce~n",[]),
	Mapsource = "function(doc) { if(doc.type) {emit(doc.type, doc.val)}}",
	Reducesource = "function(keys, values) {return sum(values)}",

	ResView = do_viewaccess_mapreduce(Mapsource, Reducesource),
	ct:print("mapreduce view access result: ~p~n",[ResView]),

	% assertion
	ResView = {json,
                               {struct,
                                [{<<"rows">>,
                                  [{struct,
                                    [{<<"key">>,null},{<<"value">>,3}]}]}]}},

	%   tear down
	ok = erlang_couchdb:delete_database(?CONNECTION, ?DBNAME)
	.
