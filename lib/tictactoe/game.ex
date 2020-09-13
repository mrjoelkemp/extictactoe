defmodule Tictactoe.Game do
  @moduledoc """
  The state of a single game of tictactoe
  """
  use Agent
  alias Tictactoe.GameBoard
  alias __MODULE__

  defmodule Player do
    defstruct number: nil, character: ""
  end

  defmodule WinState do
    @moduledoc """
    Represents a collection of data for the winning state of the game
    """
    defstruct player: struct(Player), moves_lookup: %{}
  end

  defstruct id: "",
            player_lookup: %{},
            board: %GameBoard{},
            complete?: false,
            turn: nil,
            win_state: struct(WinState)

  @x "X"
  @o "O"

  def x, do: @x
  def o, do: @o

  def start_link(_) do
    Agent.start_link(
      fn ->
        %Game{
          # TODO: Make this dynamic
          id: "123"
        }
      end,
      # TODO: When we support multiple games, remove this singleton
      name: __MODULE__
    )
  end
end
