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
              Game.get_win_state(new_game_state)
            else
              %WinState{}
            end

          Map.put(new_game_state, :win_state, win_state)
      end
    end)
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
    :ok
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
end
