%% Copyright (c) 2012, Spawngrid, Inc.
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included
%% in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
%% OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.
%%
%% @doc dead - disposable erlang application deployment.
-module(dead).
-export([deploy/2, deploy/3,redeploy/2,redeploy/3]).


%% @doc Inject the App application into the node Node.
%%
%% The <em>App</em> application must be started on the current node.
deploy(Node, App) ->
    deploy(Node, App, []).

%% @doc Inject the App application into the node Node.
deploy(Node, App, PreloadModules) ->
    case net_adm:ping(Node) of
        pang -> {error, node_unreachable};
        pong ->
            case lists:member(App, applications()) of
                false -> {error, application_not_running};
                true -> inject_app(Node, App, PreloadModules)
            end
    end.

redeploy(Node, App) ->
    redeploy(Node, App, []).

redeploy(Node, App, PreloadModules) ->
    case net_adm:ping(Node) of
        pang -> {error, node_unreachable};
        pong ->
            rpc:call(Node, application, stop, App),
            rpc:call(Node, application, unload, App),
            deploy(Node, App, PreloadModules)
    end.

inject_app(Node, App, PreloadModules) ->
    {application, App, Props} = AppFile = appfile(App),
    case lists:keyfind(applications, 1, Props) of
        {applications, AppList} ->
            inject_apps(Node, AppList);
        false -> ok
    end,
    RemoteApps =  lists:map(fun({M,_,_}) -> M end,
                            rpc:call(Node, application, which_applications, [])),
    case lists:member(App, RemoteApps) of
        false ->
            [ ensure_module_loaded(Node, M) || M <- PreloadModules ],
            Ebin = filename:join([code:lib_dir(App), "ebin"]),
            {ok, BeamFiles} = file:list_dir(Ebin),
            lists:map(fun(FileName) ->
                case lists:suffix(".beam", FileName) of
                    true ->
                        Mod = list_to_atom(lists:sublist(FileName,
                                                         length(FileName)-5)),
                        ensure_module_loaded(Node, Mod);
                    false ->
                        ok
                end
            end, BeamFiles),
            rpc:call(Node, application, load, [AppFile]),
            rpc:call(Node, application, start, [App]);
        true -> ok
    end.

ensure_module_loaded(Node, Mod) ->
    code:ensure_loaded(Mod),
    {M,B,F} = code:get_object_code(Mod),
    {module, Mod} = rpc:call(Node, code, load_binary, [M,F,B]).
inject_apps(_, []) ->
    ok;
inject_apps(Node, [App|AppList]) ->
    inject_app(Node, App, []),
    inject_apps(Node, AppList).


appfile(App) ->
    AppFilePath = filename:join([code:lib_dir(App), "ebin",
                                 atom_to_list(App)++".app"]),
    {ok, [AppFile]} = file:consult(AppFilePath),
    AppFile.

applications() ->
    [ App || {App,_,_} <- application:which_applications() ].

