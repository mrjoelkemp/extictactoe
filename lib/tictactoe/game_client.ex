defmodule Tictactoe.GameClient do
  @moduledoc """
  Client methods for interacting with a given game

  This allows us to keep utilities that act on game state separate from pure game state
  """

  require Logger
  alias Tictactoe.Game
  alias Tictactoe.Game.{Player, WinState}
  alias Tictactoe.GameBoard
  alias Tictactoe.PubSub

  @spec get_available_player_number(%Game{}) :: {:ok, number} | {:error, binary}
  def get_available_player_number(%Game{} = game) do
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
  See if there is already a player in the game for the given session
  """
  @spec lookup_player(pid, binary) :: %Player{} | nil
  def lookup_player(game_pid, session_id) do
    %Game{player_lookup: player_lookup} = get_game(game_pid)
    Map.get(player_lookup, session_id)
  end

  @spec add_player(pid, binary) :: %Player{} | {:error, binary}
  def add_player(game_pid, session_id) when is_binary(session_id) do
    game = get_game(game_pid)

    with(
      {:ok, player_number} <- get_available_player_number(game),
      {:ok, character} <- get_available_character(game)
    ) do
      new_player = %Player{
        number: player_number,
        character: character
      }

      Agent.update(game_pid, fn game_state ->
        %Game{
          game_state
          | player_lookup: Map.put(game_state.player_lookup, session_id, new_player)
        }
      end)

      new_player
    else
      err ->
        err
    end
  end

  @spec move(pid, %Player{}, binary) :: :ok
  def move(game_pid, player, position) when is_binary(position) do
    move(game_pid, player, String.to_atom(position))
  end

  @spec move(pid, %Player{}, atom()) :: :ok
  def move(game_pid, player, position) when is_atom(position) do
    Agent.update(game_pid, fn %Game{board: board, complete?: game_complete?} = state ->
      cond do
        game_complete? ->
          Logger.debug("Game is already complete")
          state

        Map.has_key?(board, position) == false ->
          Logger.info("Illegal move position: #{inspect(position)}")
          state

        player.character == "" ->
          Logger.info("Player #{inspect(player.number)} does not have a character set")
          state

        true ->
          new_board = Map.put(board, position, player.character)
          complete? = GameBoard.complete?(new_board)

          new_game_state = %Game{state | board: new_board, complete?: complete?}

          win_state =
            if complete? do
              get_win_state(new_game_state)
            else
              %WinState{}
            end

          Map.put(new_game_state, :win_state, win_state)
      end
    end)
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

  def notify_others(game_pid) do
    %Game{id: id} = get_game(game_pid)

    Phoenix.PubSub.broadcast(
      PubSub,
      "game:#{id}",
      :game_updated
    )
  end

  @doc """
  Subscribes the caller to any game updates that are pushed over pubsub
  """
  @spec subscribe_for_updates(Tictactoe.Game.t()) :: :ok | {:error, {:already_registered, pid}}
  def subscribe_for_updates(game_pid) do
    %Game{id: id} = get_game(game_pid)
    Phoenix.PubSub.subscribe(PubSub, "game:#{id}")
  end

  @doc """
  Get the entire game state
  """
  @spec get_game(pid) :: %Game{}
  def get_game(game_pid) do
    Agent.get(game_pid, & &1)
  end

  @doc """
  Erase all moves made in the game board
  """
  @spec clear_board(pid) :: :ok
  def clear_board(game_pid) do
    Agent.update(game_pid, fn game -> %Game{game | board: %GameBoard{}, complete?: false} end)
    notify_others(game_pid)
    :ok
  end

  @doc """
  Reset the entire game state (nuking all players and the board)
  """
  def reset(game_pid) do
    Agent.update(game_pid, fn _ -> %Game{} end)
    notify_others(game_pid)
    :ok
  end

  @doc """
  Check if the game is complete

  TODO: this might not be desirable since we set the completion state
  on the winning move
  """
  def complete?(game_pid) do
    get_board(game_pid)
    |> GameBoard.complete?()
  end

  @doc """
  Get the game's board
  """
  def get_board(game_pid) do
    Agent.get(game_pid, fn %Game{board: board} -> board end)
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
end
