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
            state: "",
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
          id: "123",
          state: "waiting_for_players"
        }
      end,
      # TODO: When we support multiple games, remove this singleton
      name: __MODULE__
    )
  end

  @doc """
  Creates a new player with the given id and adds them to the game
  """
  @spec add_player(%Game{}, binary) :: %Game{} | {:error, binary}
  def add_player(%Game{} = game, player_id) do
    with(
      {:ok, player_number} <- get_available_player_number(game),
      {:ok, character} <- get_available_character(game)
    ) do
      new_player = %Player{
        number: player_number,
        character: character
      }

      %Game{
        game
        | player_lookup: Map.put(game.player_lookup, player_id, new_player)
      }
    else
      err ->
        err
    end
  end

  def get_player(%Game{} = game, player_id) do
    Map.get(game.player_lookup, player_id)
  end

  @spec get_available_player_number(%Game{}) :: {:ok, number} | {:error, binary}
  defp get_available_player_number(%Game{} = game) do
    players = get_player_list(game)

    player_1_exists? = any_players_have_this_number?(players, 1)
    player_2_exists? = any_players_have_this_number?(players, 2)

    cond do
      player_1_exists? && player_2_exists? ->
        {:error, "No room for another player"}

      player_1_exists? ->
        {:ok, 2}

      true ->
        {:ok, 1}
    end
  end

  @spec get_available_character(%Game{}) :: {:ok, binary} | {:error, binary}
  defp get_available_character(%Game{} = game) do
    players = get_player_list(game)

    x_taken? = any_players_have_this_character?(players, Game.x())
    o_taken? = any_players_have_this_character?(players, Game.o())

    cond do
      x_taken? && o_taken? ->
        {:error, "No other available characters"}

      x_taken? ->
        {:ok, Game.o()}

      true ->
        {:ok, Game.x()}
    end
  end

  @spec get_player_list(%Game{}) :: [%Player{}]
  defp get_player_list(%Game{} = game) do
    game.player_lookup
    |> Map.values()
  end

  @spec any_players_have_this_number?([%Player{}], number) :: boolean
  defp any_players_have_this_number?(players, number) do
    players
    |> Enum.any?(fn player -> player.number == number end)
  end

  @spec any_players_have_this_character?([%Player{}], binary) :: boolean
  defp any_players_have_this_character?(players, character) do
    players
    |> Enum.any?(fn player -> player.character == character end)
  end

  @doc """
  Whether or not the given coordinates represent a winning move in the game

  This doesn't take in a pid since it's being called from a view that has the data already
  """
  @spec is_winning_move?(%Game{}, number, number) :: boolean
  def is_winning_move?(%Game{} = game, x_pos, y_pos) do
    if game.complete? do
      position = GameBoard.get_position_from_coordinates(x_pos, y_pos)
      Map.get(game.win_state.moves_lookup, position) != nil
    else
      false
    end
  end

  @spec complete?(%Game{}) :: boolean
  def complete?(%Game{} = game) do
    game.board
    |> GameBoard.complete?()
  end

  defp add_players(%Game{} = game, player_ids) when is_list(player_ids) do
    Enum.reduce(player_ids, game, fn player_id, %Game{} = game -> add_player(game, player_id) end)
  end

  @spec reset(%Game{}) :: %Game{}
  def reset(%Game{} = game) do
    player_ids = Map.keys(game.player_lookup)

    %Game{
      # You could alternatively connect the same players to a new game id
      id: game.id
    }
    # Keep the connected players, but clear out the players' states
    |> add_players(player_ids)
  end

  @spec clear_board(%Game{}) :: %Game{}
  def clear_board(%Game{} = game) do
    %Game{
      game
      | board: %GameBoard{},
        complete?: false
    }
  end

  @spec get_win_state(%Game{}) :: %WinState{}
  def get_win_state(%Game{board: board} = game) do
    %GameBoard.WinState{character: character, moves: moves} = GameBoard.get_winning_state(board)

    winning_player =
      get_player_list(game)
      |> Enum.find(fn player -> player.character == character end)

    # Lookup table with the position as the key and true as the value
    # Useful for the rendered buttons to check if the position they represent
    # is a winning state
    moves_lookup =
      moves
      |> Enum.map(&{&1, true})
      |> Enum.into(%{})

    %WinState{
      player: winning_player,
      moves_lookup: moves_lookup
    }
  end
end
