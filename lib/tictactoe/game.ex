defmodule Tictactoe.Game do
  @moduledoc """
  The state of a single game of tictactoe
  """
  use Agent
  alias Tictactoe.GameBoard
  alias Tictactoe.PubSub
  require Logger
  alias __MODULE__

  defmodule Player do
    defstruct number: nil, character: ""
  end

  defmodule BroadcastedMove do
    defstruct player: struct(Player), position: nil
  end

  # TODO: Make game id dynamic and not a singleton
  defstruct id: "123",
            player_lookup: %{},
            board: %GameBoard{},
            complete?: false,
            turn: nil

  @x "X"
  @o "O"

  def start_link(_) do
    Agent.start_link(fn -> %Game{} end, name: __MODULE__)
  end

  @spec get_game :: %Game{}
  def get_game do
    Agent.get(__MODULE__, & &1)
  end

  @spec id :: binary
  def id do
    Agent.get(__MODULE__, fn %{id: id} -> id end)
  end

  @spec add_player(binary) :: %Player{} | {:error, binary}
  def add_player(session_id) when is_binary(session_id) do
    with(
      {:ok, player_number} <- get_available_player_number(),
      {:ok, character} <- get_available_character()
    ) do
      new_player = %Player{
        number: player_number,
        character: character
      }

      Agent.update(__MODULE__, fn game_state ->
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

  @spec get_available_player_number() :: {:ok, number} | {:error, binary}
  defp get_available_player_number() do
    players = get_player_list()

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

  @spec get_player_list :: [%Player{}]
  defp get_player_list() do
    %Game{player_lookup: player_lookup} = get_game()
    Map.values(player_lookup)
  end

  # TODO: Replace this with the user selecting their own character
  @spec get_available_character() :: {:ok, binary} | {:error, binary}
  defp get_available_character() do
    players = get_player_list()

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

  @spec any_players_have_this_character?([%Player{}], binary) :: boolean
  defp any_players_have_this_character?(players, character) do
    players
    |> Enum.any?(fn player -> player.character == character end)
  end

  @spec any_players_have_this_number?([%Player{}], number) :: boolean
  defp any_players_have_this_number?(players, number) do
    players
    |> Enum.any?(fn player -> player.number == number end)
  end

  def move(player, position) when is_binary(position) do
    move(player, String.to_atom(position))
  end

  @spec move(%Player{}, atom()) :: :ok
  def move(player, position) when is_atom(position) do
    Agent.update(__MODULE__, fn %Game{board: board, complete?: game_complete?} = state ->
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
          %Game{state | board: new_board, complete?: GameBoard.complete?(new_board)}
      end
    end)
  end

  @spec broadcast_move(%Player{}, atom) :: :ok | {:error, term}
  def broadcast_move(player, position) do
    %Game{id: id} = get_game()

    Phoenix.PubSub.broadcast(
      PubSub,
      "game:#{id}",
      {:move, %BroadcastedMove{player: player, position: position}}
    )
  end

  @doc """
  See if there is already a player in the game for the given session
  """
  @spec lookup_player(binary) :: %Player{} | nil
  def lookup_player(session_id) do
    %Game{player_lookup: player_lookup} = get_game()
    Map.get(player_lookup, session_id)
  end

  def subscribe_for_updates() do
    %Game{id: id} = get_game()
    Phoenix.PubSub.subscribe(PubSub, "game:#{id}")
  end

  @doc """
  Erase all moves made in the game board
  """
  def clear_board do
    Agent.update(__MODULE__, fn game -> %Game{game | board: %GameBoard{}, complete?: false} end)
  end

  @doc """
  Reset the entire game state (nuking all players and the board)
  """
  def reset do
    Agent.update(__MODULE__, fn _ -> %Game{} end)
  end

  @doc """
  Check if the game is complete

  TODO: this might not be desirable since we set the completion state
  on the winning move
  """
  def complete? do
    get_board()
    |> GameBoard.complete?()
  end

  @doc """
  Get the game's board
  """
  def get_board do
    Agent.get(__MODULE__, fn %Game{board: board} -> board end)
  end
end
