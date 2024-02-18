defmodule Xogmios.TxSubmission do
  @moduledoc """
  This module interfaces with the Tx Submission protocol.
  """

  alias Xogmios.TxSubmission.Messages
  alias Xogmios.TxSubmission.Response
  alias Xogmios.TxSubmission.Server

  @doc """
  Starts a new Tx Submission process linked to the current process.

  This function should not be called directly, but rather via `Xogmios.start_tx_submission_link/2`
  """
  @spec start_link(module(), start_options :: Keyword.t()) :: GenServer.on_start()
  def start_link(client, opts) do
    GenServer.start_link(client, opts, name: client)
  end

  @doc """
  Submits a transaction to the server and returns a response including the transaction id.

  This function is synchronous and takes two arguments:

  1. (Optional) A process reference. If none given, it defaults to the linked process `__MODULE__`.
  2. The CBOR of a signed transaction.
  """
  @spec submit_tx(pid() | atom(), String.t()) :: {:ok, any()} | {:error, any()}
  def submit_tx(client \\ __MODULE__, cbor) do
    with {:ok, message} <- build_message(cbor),
         {:ok, %Response{} = response} <- call_tx_submission(client, message) do
      {:ok, response.result}
    end
  end

  defp build_message(cbor),
    do: {:ok, Messages.submit_tx(cbor)}

  defp call_tx_submission(client, message) do
    case GenServer.call(client, {:submit_tx, message}) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer

      ## Callbacks

      @impl true
      def init(args) do
        url = Keyword.fetch!(args, :url)

        case :websocket_client.start_link(url, Server, []) do
          {:ok, ws_pid} ->
            {:ok, %{ws_pid: ws_pid, response: nil, caller: nil}}

          {:error, _} = error ->
            error
        end
      end

      @impl true
      def handle_call({:submit_tx, message}, from, state) do
        {:store_caller, _from} = send(state.ws_pid, {:store_caller, from})
        :ok = :websocket_client.send(state.ws_pid, {:text, message})
        {:noreply, state}
      end
    end
  end
end
