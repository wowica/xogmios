defmodule Xogmios.ChainSync.Messages do
  @moduledoc """
  This module returns messages for the Chain Synchronization protocol
  """

  alias Jason.DecodeError

  def next_block_start() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock",
      "id": "start"
    }
    """

    validate_json!(json)
    json
  end

  def next_block() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock"
    }
    """

    validate_json!(json)
    json
  end

  def find_intersection(slot, id) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "findIntersection",
      "params": {
          "points": [
            {
              "slot": #{slot},
              "id": "#{id}"
            }
        ]
      }
    }
    """

    validate_json!(json)
    json
  end

  def find_origin do
    # For finding origin, any value can be passed as a point as long as "origin"
    # is the first value.
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "findIntersection",
      "params": {
          "points": [
            "origin",
            {
              "slot": 4492799,
              "id": "f8084c61b6a238acec985b59310b6ecec49c0ab8352249afd7268da5cff2a457"
            }
          ]
      }
    }
    """

    validate_json!(json)
    json
  end

  # The following are the last points (absolute slot and block id) of
  # the previous era of each entry. The sync is done against the last
  # point, so that the next block received is the first of the following era.
  @era_bounds %{
    shelley: {4_492_799, "f8084c61b6a238acec985b59310b6ecec49c0ab8352249afd7268da5cff2a457"},
    allegra: {16_588_737, "4e9bbbb67e3ae262133d94c3da5bffce7b1127fc436e7433b87668dba34c354a"},
    mary: {23_068_793, "4e9bbbb67e3ae262133d94c3da5bffce7b1127fc436e7433b87668dba34c354a"},
    alonzo: {39_916_796, "e72579ff89dc9ed325b723a33624b596c08141c7bd573ecfff56a1f7229e4d09"},
    babbage: {72_316_796, "c58a24ba8203e7629422a24d9dc68ce2ed495420bf40d9dab124373655161a20"}
  }

  def last_block_from(era_name) when is_atom(era_name) do
    case @era_bounds[era_name] do
      {last_slot, last_block_id} -> find_intersection(last_slot, last_block_id)
      nil -> {:error, :unknown_block}
    end
  end

  defp validate_json!(json) do
    case Jason.decode(json) do
      {:ok, _decoded} -> :ok
      {:error, %DecodeError{} = error} -> raise "Invalid JSON: #{inspect(error)}"
    end
  end
end
