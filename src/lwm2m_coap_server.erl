%
% The contents of this file are subject to the Mozilla Public License
% Version 1.1 (the "License"); you may not use this file except in
% compliance with the License. You may obtain a copy of the License at
% http://www.mozilla.org/MPL/
%
% Copyright (c) 2015 Petr Gotthard <petr.gotthard@centrum.cz>
%

% CoAP server application
% supervisor for content registry, listening socket and channel supervisor
-module(lwm2m_coap_server).

-include("coap.hrl").

-behaviour(application).
-export([start/0, start/2, stop/1]).

-behaviour(supervisor).
-export([init/1]).

-export([ start_registry/0
        , start_registry/1
        , start_udp/1
        , start_udp/2
        , start_udp/3
        , stop_udp/2
        , start_dtls/2
        , start_dtls/3
        , stop_dtls/2
        ]).

%%--------------------------------------------------------------------
%% Application callbcaks
%%--------------------------------------------------------------------

start() ->
    start(normal, []).

start(normal, _Args) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

stop(_Pid) ->
    ok.

%%--------------------------------------------------------------------
%% Supervisor callbacks
%%--------------------------------------------------------------------

init([]) ->
    {ok, {{one_for_one, 3, 10}, []}}.

%%--------------------------------------------------------------------
%% APIs
%%--------------------------------------------------------------------

-spec(start_registry() -> supervisor:startchild_ret()).
start_registry() ->
    start_registry([]).

-spec(start_registry(list()) -> supervisor:startchild_ret()).
start_registry(ResourceHandlers) when is_list(ResourceHandlers) ->
    supervisor:start_child(?MODULE,
        {lwm2m_coap_server_registry,
            {lwm2m_coap_server_registry, start_link, [ResourceHandlers]},
             permanent, 5000, worker, []}).

-spec(start_udp(atom()) -> {ok, pid()} | {error, term()}).
start_udp(Proto) ->
    start_udp(Proto, ?DEFAULT_COAP_PORT, []).

-spec(start_udp(atom(), esockd:listen_on()) -> {ok, pid()} | {error, term()}).
start_udp(Proto, ListenOn) ->
    start_udp(Proto, ListenOn, []).

-spec(start_udp(atom(), esockd:listen_on(), list()) -> {ok, pid()} | {error, term()}).
start_udp(Proto, ListenOn, Opts) ->
    start_udp_listener(Proto, ListenOn, Opts).

-spec(stop_udp(atom(), esockd:listen_on()) -> ok | {error, term()}).
stop_udp(Proto, ListenOn) ->
    esockd:close(Proto, ListenOn).

-spec(start_dtls(atom(), list()) -> {ok, pid()} | {error, term()}).
start_dtls(Proto, Opts) ->
    start_dtls(Proto, ?DEFAULT_COAPS_PORT, Opts).

-spec(start_dtls(atom(), esockd:listen_on(), list()) -> {ok, pid()} | {error, term()}).
start_dtls(Proto, ListenOn, Opts) ->
    start_dtls_listener(Proto, ListenOn, Opts).

-spec(stop_dtls(atom(), esockd:listen_on()) -> ok | {error, term()}).
stop_dtls(Proto, ListenOn) ->
    esockd:close(Proto, ListenOn).

%%--------------------------------------------------------------------
%% Internal funcs
%%--------------------------------------------------------------------

start_udp_listener(Name, ListenOn, Options) ->
    SockOpts = esockd:parse_opt(Options),
    esockd:open_udp(Name, ListenOn, merge_default(udp_options, SockOpts),
                    {lwm2m_coap_channel, start_link, [Options -- SockOpts]}).

start_dtls_listener(Name, ListenOn, Options) ->
    SockOpts = esockd:parse_opt(Options),
    esockd:open_dtls(Name, ListenOn, merge_default(dtls_options, SockOpts),
                     {lwm2m_coap_channel, start_link, [Options -- SockOpts]}).

merge_default(Name, Options) ->
    case lists:keytake(Name, 1, Options) of
        {value, {Name, UdpOpts}, Options1} ->
            [{Name, merge_opts(?UDP_SOCKOPTS, UdpOpts)} | Options1];
        false ->
            [{Name, ?UDP_SOCKOPTS} | Options]
    end.

merge_opts(Defaults, Options) ->
    lists:foldl(
      fun({Opt, Val}, Acc) ->
          lists:keystore(Opt, 1, Acc, {Opt, Val});
         (Opt, Acc) ->
          lists:usort([Opt | Acc])
      end, Defaults, Options).
