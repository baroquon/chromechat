%% This is my first attempt at unit testing a server in erlang.
%% Was pointed to this as an example: https://github.com/blt/locker/blob/master/src/lk_proc.erl#L144
-module(chatserver_test).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").
-include("../../src/chatserver_records.hrl").

-define(setup(F), {setup, fun start/0, fun stop/1, F}).
-define(TIMEOUT, 50).

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Test Descriptions %%%
%%%%%%%%%%%%%%%%%%%%%%%%%

join_and_appear_in_nicklist_test_() ->
    {"A client sees itself in the nicklist after joining.",
     ?setup(fun can_connect_and_then_see_self_in_nicklist/1)}.

part_and_disappear_from_nicklist_test_() ->
    {"A client that disconnects no longer shows up in the nicklist.",
     ?setup(fun can_disconnect_and_username_is_removed_from_nicklist/1)}.

connect_and_send_message_test_() ->
    {"A client connects and sends a message, and has that message broadcast to it.",
     ?setup(fun can_connect_and_send_message/1)}.

join_test_() ->
    {"A client can connect to the server, which adds its User to the listeners list. [gen_server protocol]",
     ?setup(fun can_connect/1)}.

nicklist_test_() ->
    {"A client can list the connected users. [gen_server protocol]",
     ?setup(fun can_list_users/1)}.

send_test_() ->
    {"A client can send messages. [gen_server protocol]",
        ?setup(fun can_send_message/1)}. % NOTE: Since I don't know how to flush inbound messages, this test must come after the connect_and_send_message_test_

%%%%%%%%%%%%%%%%%%%%%%%
%%% Setup Functions %%%
%%%%%%%%%%%%%%%%%%%%%%%

start() ->
    self().

stop(_) ->
    "no-op.".

%%%%%%%%%%%%%%%%%%%%%%%%
%%% Helper Functions %%%
%%%%%%%%%%%%%%%%%%%%%%%%

%%% Nothing to see here yet...

%%%%%%%%%%%%%%%%%%%%
%%% Actual Tests %%%
%%%%%%%%%%%%%%%%%%%%
can_connect(SelfPid) ->
    InitialState = #state{listeners=[], messages=[]},
    Knewter = #user{username="knewter", pid=SelfPid},
    StateWithUser = #state{listeners=[Knewter], messages=[]},
    [?_assertMatch({reply, ok, StateWithUser}, chatserver:handle_call({join, "knewter"}, {SelfPid, []}, InitialState))].

can_list_users(SelfPid) ->
    Knewter = #user{username="knewter", pid=SelfPid},
    StateWithUser = #state{listeners=[Knewter], messages=[]},
    [?_assertMatch({reply, ["knewter"], StateWithUser}, chatserver:handle_call(nicklist, {SelfPid, []}, StateWithUser))].

can_send_message(SelfPid) ->
    Knewter = #user{username="knewter", pid=SelfPid},
    StateWithUser = #state{listeners=[Knewter], messages=[]},
    [?_assertMatch({noreply, StateWithUser}, chatserver:handle_cast({send, SelfPid, "some message" }, StateWithUser))].

can_connect_and_then_see_self_in_nicklist(_) ->
    {ok, Pid} = chatserver:start_link(),
    chatserver:join(Pid, "knewter"),
    [?_assertEqual(["knewter"], chatserver:nicklist(Pid))].

can_disconnect_and_username_is_removed_from_nicklist(_) ->
    {ok, Pid} = chatserver:start_link(),
    chatserver:join(Pid, "knewter"),
    chatserver:part(Pid),
    [?_assertEqual([], chatserver:nicklist(Pid))].

can_connect_and_send_message(_) ->
    {ok, Pid} = chatserver:start_link(),
    chatserver:join(Pid, "knewter"),
    chatserver:send(Pid, "this is a message"),
    assert_received(#message{username="knewter", text="this is a message"}).

assert_received(Inbound) ->
    Message = receive
                  Inbound -> Inbound;
                  Other -> Other
              after ?TIMEOUT ->
                  throw("Message expected.")
              end,
    [?_assertEqual(Inbound, Message)].

-endif.
