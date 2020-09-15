defmodule TictactoeWeb.PageLive do
  use TictactoeWeb, :live_view
  alias Tictactoe.{GameBoard, GameClient, Game, Game.Player}
  require Logger

  # TODO: Stop using the csrf token and use another cookie session id
  @impl true
  def mount(_params, session, socket) do
    IO.inspect(socket.assigns, label: "\nSocket assigns")

    IO.puts("My pid: #{inspect(self())}")
    IO.puts("Socket connected? #{inspect(connected?(socket))}")

    # TODO: Eventually, we should just fetch the game by id
    game_pid = Process.whereis(Tictactoe.Game)

    if connected?(socket) do
      %{"_csrf_token" => session_id} = session
      IO.puts("Session id: #{session_id}")
      IO.puts("Game State: #{inspect(GameClient.get_game(game_pid))}")

      IO.puts("Load player state")
      GameClient.subscribe_for_updates(game_pid)
      send(self(), {:load_player_state, session_id})
    end

    {:ok,
     assign(socket,
       game_pid: game_pid,
       game: GameClient.get_game(game_pid),
       player: %Player{}
     )}
  end

  @impl true
  def handle_info({:load_player_state, session_id}, socket) do
    game_pid = socket.assigns.game_pid

    result =
      case GameClient.lookup_player(game_pid, session_id) do
        nil ->
          Logger.debug("Creating a new player")
          GameClient.add_player(game_pid, session_id)

        %Player{} = player ->
          Logger.debug("Player was already in the game")
          player
      end

    case result do
      %Player{} = player ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(player: player)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_info(:game_updated, socket) do
    {:noreply,
     assign(
       socket,
       game: GameClient.get_game(socket.assigns.game_pid)
     )}
  end

  @impl true
  def handle_event("game_move", %{"position" => position}, socket) do
    IO.inspect(position, label: "Move Position")

    player = socket.assigns.player
    game_pid = socket.assigns.game_pid

    # We don't just pull the game and mutate that because that
    # wouldn't persist the actions against the source of truth
    if not GameClient.complete?(game_pid) do
      GameClient.move(game_pid, player, position)
      GameClient.notify_others(game_pid)
    end

    {:noreply,
     assign(socket,
       game: GameClient.get_game(game_pid)
     )}
  end

  @impl true
  def handle_event("clear_board", _value, socket) do
    game_pid = socket.assigns.game_pid
    GameClient.clear_board(game_pid)

    {:noreply,
     assign(socket,
       game: GameClient.get_game(game_pid)
     )}
  end

  @impl true
  def handle_event("reset_game", _value, socket) do
    Logger.debug("Resetting the game")
    game_pid = socket.assigns.game_pid
    GameClient.reset(game_pid)

    {:noreply,
     socket
     |> clear_flash(:error)
     |> assign(game: GameClient.get_game(game_pid))}
  end

  def your_turn?(_socket) do
    # %Player{is_my_turn?: is_my_turn?} = socket.assigns.player
    # is_my_turn?

    # TODO: Replace this when we have the state machine that dictates whose turn it is
    true
  end
end
