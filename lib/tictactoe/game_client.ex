defmodule Tictactoe.GameClient do
  @moduledoc """
  Client methods for interacting with a given game

  This allows us to keep utilities that act on game state separate from pure game state
  """

  require Logger
  alias Tictactoe.Game
  alias Tictactoe.Game.{Player}
  alias Tictactoe.PubSub

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

    case Game.add_player(game, session_id) do
      %Game{} = updated_game ->
        Agent.update(game_pid, fn _ -> updated_game end)
        Game.get_player(updated_game, session_id)

      err ->
        err
    end
  end

  def move(game_pid, player, position) when is_binary(position),
    do: move(game_pid, player, String.to_atom(position))

  @spec move(pid, %Player{}, atom()) :: :ok
  def move(game_pid, player, position) when is_atom(position) do
    Agent.update(game_pid, fn game -> Game.move(game, player, position) end)
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
    updated_game =
      get_game(game_pid)
      |> Game.clear_board()

    Agent.update(game_pid, fn _ -> updated_game end)
    notify_others(game_pid)
  end

  @doc """
  Reset the entire game state, keeping the connected players
  """
  @spec reset(pid) :: :ok
  def reset(game_pid) do
    updated_game =
      get_game(game_pid)
      |> Game.reset()

    Agent.update(game_pid, fn _ -> updated_game end)
    notify_others(game_pid)
  end

  @spec complete?(pid) :: boolean
  def complete?(game_pid) do
    game = get_game(game_pid)
    game.complete?
  end
end
