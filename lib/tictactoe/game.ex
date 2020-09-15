defmodule Tictactoe.Game do
  @moduledoc """
  The state of a single game of tictactoe
  """
  use Agent
  alias Tictactoe.GameBoard
  alias __MODULE__
  require Logger

  @x "X"
  @o "O"

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
            turn: @x,
            win_state: struct(WinState)

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

    x_taken? = any_players_have_this_character?(players, @x)
    o_taken? = any_players_have_this_character?(players, @o)

    cond do
      x_taken? && o_taken? ->
        {:error, "No other available characters"}

      x_taken? ->
        {:ok, @o}

      true ->
        {:ok, @x}
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

  @doc """
  Wait, did I WIN?!
  """
  @spec did_I_win?(%Game{}, %Player{}) :: boolean
  def did_I_win?(%Game{} = game, %Player{} = player) do
    game.win_state.player == player
  end

  @spec is_my_turn?(%Game{}, %Player{}) :: boolean
  def is_my_turn?(%Game{} = game, %Player{} = player) do
    player.character == game.turn
  end

  @spec move(%Game{}, %Player{}, atom) :: %Game{}
  def move(%Game{} = game, %Player{} = player, position) when is_atom(position) do
    cond do
      game.complete? ->
        Logger.debug("Game is already complete")
        game

      GameBoard.has_move_here?(game.board, position) == true ->
        Logger.debug("This position has already been played")
        game

      GameBoard.is_valid_position?(position) == false ->
        Logger.debug("Invalid position location")
        game

      player.character == "" ->
        Logger.info("Player #{inspect(player.number)} does not have a character set")
        game

      true ->
        new_board = Map.put(game.board, position, player.character)
        complete? = GameBoard.complete?(new_board)
        next_turn = if player.character == @x, do: @o, else: @x

        new_game_state = %Game{
          game
          | board: new_board,
            complete?: complete?,
            turn: next_turn
        }

        win_state =
          if complete? do
            get_win_state(new_game_state)
          else
            %WinState{}
          end

        Map.put(new_game_state, :win_state, win_state)
    end
  end
end
