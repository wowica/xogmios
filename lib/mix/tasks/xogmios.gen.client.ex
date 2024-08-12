defmodule Mix.Tasks.Xogmios.Gen.Client do
  @shortdoc "Generates a Xogmios client module"

  @moduledoc """
  Generates a new Xogmios client module.

    $ mix xogmios.gen.client -p chain_sync MyClientModule

  The following CLI flags are required:
  ```md
  -p, --protocol        The Ouroboros mini-protocol for which the client module
                        will be working with. This can be one of: chain_sync,
                        mempool_txs, state_query, tx_submission.
  ```
  """

  use Mix.Task
  alias Mix.Shell.IO

  @impl true
  def run(args) do
    otp_app =
      Mix.Project.config()
      |> Keyword.get(:app)
      |> Atom.to_string()

    case parse_options(args) do
      %{protocol: protocol, client_module_name: client_module_name} ->
        generate_client(otp_app, protocol, client_module_name)

      _ ->
        raise "Missing required arguments. Run mix help xogmios.gen.client for usage instructions"
    end
  end

  defp generate_client(otp_app, protocol, client_module_name) do
    project_root = File.cwd!()
    filename = Macro.underscore(client_module_name)
    path = Path.join([project_root, "lib", otp_app, "#{filename}.ex"])
    dirname = Path.dirname(path)

    unless File.exists?(dirname) do
      raise "Required directory path #{dirname} does not exist. "
    end

    write_file =
      if File.exists?(path) do
        IO.yes?("File already exists at #{path}. Overwrite?")
      else
        true
      end

    if write_file do
      create_client_file(path, otp_app, protocol, client_module_name)
      IO.info("Successfully wrote out #{path}")
    else
      IO.info("Did not write file out to #{path}")
    end
  end

  defp parse_options(args) do
    cli_options = [protocol: :string]
    cli_aliases = [p: :protocol]

    parsed_args = OptionParser.parse(args, aliases: cli_aliases, strict: cli_options)

    case parsed_args do
      {options, [client_module_name], [] = _errors} ->
        options
        |> Map.new()
        |> Map.merge(%{client_module_name: client_module_name})

      {_options, _remaining_args, errors} ->
        raise "Invalid CLI args were provided: #{inspect(errors)}"
    end
  end

  defp create_client_file(path, otp_app, protocol, client_module_name) do
    app_module_name = Macro.camelize(otp_app)

    assigns = [
      app_module_name: app_module_name,
      protocol: protocol,
      client_module_name: client_module_name
    ]

    module_template =
      xogmios_module_template(protocol)
      |> EEx.eval_string(assigns: assigns)

    path
    |> File.write!(module_template)
  end

  defp xogmios_module_template("chain_sync") do
    """
    defmodule <%= @app_module_name %>.<%= @client_module_name %> do
      @moduledoc \"\"\"
      This module syncs with the chain and reads new blocks.

      Be sure to add this module to your app's supervision tree like so:

      def start(_type, _args) do
        children = [
          ...,
          {<%= @app_module_name %>.<%= @client_module_name %>, url: System.fetch_env!("OGMIOS_URL")}
        ]
        ...
      end
      \"\"\"

      use Xogmios, :chain_sync

      def start_link(opts) do
        # Syncs from current tip by default
        initial_state = []
        ### See examples below on how to sync
        ### from different points of the chain:
        # initial_state = [sync_from: :babbage]
        # initial_state = [
        #   sync_from: %{
        #     point: %{
        #       slot: 114_127_654,
        #       id: "b0ff1e2bfc326a7f7378694b1f2693233058032bfb2798be2992a0db8b143099"
        #     }
        #   }
        # ]
        opts = Keyword.merge(opts, initial_state)
        Xogmios.start_chain_sync_link(__MODULE__, opts)
      end

      @impl true
      def handle_block(block, state) do
        IO.puts("handle_block \#{block["height"]}")
        {:ok, :next_block, state}
      end
    end
    """
  end

  defp xogmios_module_template("state_query") do
    """
    defmodule <%= @app_module_name %>.<%= @client_module_name %> do
      @moduledoc \"\"\"
      This module queries against the known tip of the chain.

      Be sure to add this module to your app's supervision tree like so:

      def start(_type, _args) do
        children = [
          ...,
          {<%= @app_module_name %>.<%= @client_module_name %>, url: System.fetch_env!("OGMIOS_URL")}
        ]
        ...
      end

      Then invoke functions:
       * <%= @client_module_name %>.send_query("eraStart")
       * <%= @client_module_name %>.send_query("queryNetwork/blockHeight")
      \"\"\"

      use Xogmios, :state_query
      alias Xogmios.StateQuery

      def start_link(opts) do
        Xogmios.start_state_link(__MODULE__, opts)
      end

      def send_query(pid \\\\\ __MODULE__, query_name) do
        StateQuery.send_query(pid, query_name)
      end
    end
    """
  end

  defp xogmios_module_template("mempool_txs") do
    """
    defmodule <%= @app_module_name %>.<%= @client_module_name %> do
      @moduledoc \"\"\"
      This module prints transactions as they become available in the mempool.

      Be sure to add this module to your app's supervision tree like so:

      def start(_type, _args) do
        children = [
          ...,
          {<%= @app_module_name %>.<%= @client_module_name %>, url: System.fetch_env!("OGMIOS_URL")}
        ]
        ...
      end
      \"\"\"

      use Xogmios, :mempool_txs

      def start_link(opts) do
        # set include_details: false (default) to retrieve
        # only transaction id.
        # set include_details: true to retrieve
        # complete information about the transaction.
        opts = Keyword.merge(opts, include_details: false)
        Xogmios.start_mempool_txs_link(__MODULE__, opts)
      end

      @impl true
      def handle_transaction(transaction, state) do
        IO.puts("transaction \#{\inspect(transaction)}")

        {:ok, :next_transaction, state}
      end
    end
    """
  end
end
