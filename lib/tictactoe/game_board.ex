defmodule TicTacToe.GameBoard do
  @moduledoc """
  A game board that holds the state of a single game
  """
  use Agent

  @board %{
      "0_0" => "",
      "0_1" => "",
      "0_2" => "",
      "1_0" => "",
      "1_1" => "",
      "1_2" => "",
      "2_0" => "",
      "2_1" => "",
      "2_2" => ""
    }
  def start_link(_initial_value) do
    Agent.start_link(fn -> @board end, name: __MODULE__)
  end

  def get_board do
    Agent.get(__MODULE__, & &1)
  end

  @spec move(binary(), binary()) :: :ok
  def move(player, position) do
      Agent.update(__MODULE__, fn board ->
        if Map.has_key?(board, position) do
          Map.put(board, position, player)
        end
      end)
  end

  def clear() do
    Agent.update(__MODULE__, fn _ -> @board end)
  end
end
