defmodule Xogmios.Database do
  use Agent

  @agent_name __MODULE__

  def start_link(initial_opts \\ []) do
    name = Keyword.get(initial_opts, :name, @agent_name)
    Agent.start_link(fn -> [] end, name: name)
  end

  def roll_forward(pid \\ @agent_name, block) do
    Agent.update(pid, fn blocks ->
      [block | blocks]
    end)
  end

  def roll_backward(pid \\ @agent_name, point) do
    Agent.update(pid, fn blocks ->
      Enum.filter(blocks, &(&1.slot <= point.slot))
    end)
  end

  def get_blocks(pid \\ @agent_name) do
    Agent.get(pid, fn blocks -> blocks end)
  end
end
