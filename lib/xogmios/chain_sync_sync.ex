# defmodule Xogmios.ChainSyncSync do
#   defmodule Server do
#     @behaviour :websocket_client

#     require Logger

#     def handle_message(%{"id" => "start"} = message, state) do
#       %{
#         "method" => "nextBlock",
#         "result" => %{"direction" => "backward", "tip" => _tip}
#       } = message

#       %{sync_point: point} = state
#       message = Xogmios.ChainSync.Messages.find_intersection(point.slot, point.id)
#       IO.puts("handle message backward id start")
#       {:reply, {:text, message}, state}
#     end

#     def handle_message(%{"method" => "findIntersection"}, state) do
#       message = Xogmios.ChainSync.Messages.next_block()
#       {:reply, {:text, message}, state}
#     end

#     def handle_message(
#           %{"method" => "nextBlock", "result" => %{"direction" => "backward"}},
#           state
#         ) do
#       message = Xogmios.ChainSync.Messages.next_block()
#       IO.puts("direction backward #{message}")
#       {:reply, {:text, message}, state}
#     end

#     def handle_message(
#           %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = _result},
#           state
#         ) do
#       message = Xogmios.ChainSync.Messages.next_block()

#       {:reply, {:text, message}, state}
#     end

#     def handle_message({:text, _message}, state) do
#       IO.puts("handle message")
#       {:close, state}
#     end

#     @impl true
#     def init(args) do
#       # websocket_client.init/1 behaviour expects keyword list as argument
#       # but maps are easier to work with downstream.
#       initial_state = args |> Keyword.merge(caller: nil) |> Enum.into(%{})

#       {:once, initial_state}
#     end

#     @impl true
#     def onconnect(_arg0, state) do
#       message = Xogmios.ChainSync.Messages.next_block_start()
#       :websocket_client.cast(self(), {:text, message})
#       {:ok, state}
#     end

#     @impl true
#     def ondisconnect(_reason, state) do
#       {:ok, state}
#     end

#     @impl true
#     def websocket_handle({:text, raw_message}, _conn, state) do
#       case Jason.decode(raw_message) do
#         {:ok, message} ->
#           handle_message(message, state)

#         {:error, reason} ->
#           Logger.warning("Error decoding message #{inspect(reason)}")
#           {:ok, state}
#       end
#     end

#     @impl true
#     def websocket_handle(_message, _conn, state) do
#       {:ok, state}
#     end

#     @impl true
#     def websocket_info({:store_caller, caller}, _req, state) do
#       # Stores caller of the query so that GenServer.reply knows
#       # who to return the response to
#       {:ok, %{state | caller: caller}}
#     end

#     @impl true
#     def websocket_info(_any, _arg1, state) do
#       {:ok, state}
#     end

#     @impl true
#     def websocket_terminate(_arg0, _arg1, _state) do
#       :ok
#     end
#   end

#   @doc """
#   Starts a new Chain Sync process linked to the current process.

#   This function should not be called directly, but rather via `Xogmios.start_chain_sync_link/2`
#   """
#   @spec start_link(module(), start_options :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
#   def start_link(client, opts) do
#     GenServer.start_link(client, opts, name: client)
#   end

#   @doc """
#   Issues a message for finding the next block.

#   This function should be used when manually syncing from a particular point in
#   the history of the chain.

#   The result of calling this method must be handled by the `c:handle_block/2`
#   callback
#   """
#   @spec find_next_block(pid()) :: :ok
#   def find_next_block(pid) do
#     # hacky af but it does the job for now
#     state = :sys.get_state(pid)
#     {_c, %{ws_pid: ws_pid}} = state |> elem(1) |> elem(5)
#     next_block_message = Xogmios.ChainSync.Messages.next_block()
#     :websocket_client.cast(ws_pid, {:text, next_block_message})
#   end

#   defmacro __using__(_opts) do
#     quote do
#       require Logger

#       use GenServer

#       @impl true
#       def handle_call({:send_message, message}, from, state) do
#         {:store_caller, _from} = send(state.ws_pid, {:store_caller, from})
#         :ok = :websocket_client.send(state.ws_pid, {:text, message})
#         {:noreply, state}
#       end

#       @impl true
#       def init(args) do
#         url = Keyword.fetch!(args, :url)

#         babbage_sync_point =
#           %{
#             slot: 72_316_796,
#             id: "c58a24ba8203e7629422a24d9dc68ce2ed495420bf40d9dab124373655161a20"
#           }

#         initial_state = [notify_on_connect: self(), sync_point: babbage_sync_point]

#         case :websocket_client.start_link(url, Xogmios.ChainSyncSync.Server, initial_state) do
#           {:ok, ws_pid} ->
#             # Blocks until the connection with the Ogmios server
#             # is established or until timeout is reached.
#             receive do
#               {:connected, _connection} ->
#                 {:ok, %{ws_pid: ws_pid, response: nil, caller: nil}}
#             after
#               _timeout = 5_000 ->
#                 send(ws_pid, :close)
#                 {:error, :connection_timeout}
#             end

#           {:error, _} = error ->
#             error
#         end
#       end
#     end
#   end
# end
