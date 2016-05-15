-module(prometheus_gauge).

%%% metric
-export([new/1,
         new/2,
         set/2,
         set/3,
         set/4,
         reset/1,
         reset/2,
         reset/3,
         value/1,
         value/2,
         value/3]).

%%% collector
-export([register/0,
         register/1,
         collect_mf/2,
         collect_metrics/3]).

-include("prometheus.hrl").
-behaviour(prometheus_collector).
-behaviour(prometheus_metric).

-define(GAUGE_POS, 2).

%%====================================================================
%% Metric API
%%====================================================================

new(Spec) ->
  new(Spec, default).

new(Spec, Registry) ->
  {Name, Labels, Help} = prometheus_metric:extract_common_params(Spec),
  %% Value = proplists:get_value(value, Spec),
  register(Registry),
  prometheus_metric:insert_mf(?PROMETHEUS_GAUGE_TABLE, Registry, Name, Labels, Help).

set(Name, Value) ->
  set(default, Name, [], Value).

set(Name, LabelValues, Value) ->
  set(default, Name, LabelValues, Value).

set(Registry, Name, LabelValues, Value) ->
  case ets:update_element(?PROMETHEUS_GAUGE_TABLE, {Registry, Name, LabelValues}, {?GAUGE_POS, Value}) of
    false ->
      insert_metric(Registry, Name, LabelValues, Value, fun set/4);
    true ->
      ok
  end,
  ok.

reset(Name) ->
  reset(default, Name, []).

reset(Name, LabelValues) ->
  reset(default, Name, LabelValues).

reset(Registry, Name, LabelValues) ->
  prometheus_metric:check_mf_exists(?PROMETHEUS_GAUGE_TABLE, Registry, Name, LabelValues),
  ets:update_element(?PROMETHEUS_GAUGE_TABLE, {Registry, Name, LabelValues}, {?GAUGE_POS, 0}).

value(Name) ->
  value(default, Name, []).

value(Name, LabelValues) ->
  value(default, Name, LabelValues).

value(Registry, Name, LabelValues) ->
  [{_Key, Value}] = ets:lookup(?PROMETHEUS_GAUGE_TABLE, {Registry, Name, LabelValues}),
  Value.

%%====================================================================
%% Collector API
%%====================================================================

register() ->
  register(default).

register(Registry) ->
  ok = prometheus_registry:register_collector(Registry, ?MODULE).

collect_mf(Callback, Registry) ->
  [Callback(gauge, Name, Labels, Help, [Registry]) ||
    [Name, Labels, Help, _] <- prometheus_metric:metrics(?PROMETHEUS_GAUGE_TABLE, Registry)].

collect_metrics(Name, Callback, [Registry]) ->
  [Callback(LabelValues, Value) ||
    [LabelValues, Value] <- ets:match(?PROMETHEUS_GAUGE_TABLE, {{Registry, Name, '$1'}, '$2'})].

%%====================================================================
%% Private Parts
%%====================================================================

insert_metric(Registry, Name, LabelValues, Value, ConflictCB) ->
  prometheus_metric:check_mf_exists(?PROMETHEUS_GAUGE_TABLE, Registry, Name, LabelValues),
  case ets:insert_new(?PROMETHEUS_GAUGE_TABLE, {{Registry, Name, LabelValues}, Value}) of
    false -> %% some sneaky process already inserted
      ConflictCB(Registry, Name, LabelValues, Value);
    true ->
      ok
  end.
