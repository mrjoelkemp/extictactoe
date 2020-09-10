defmodule TictactoeWeb.PageLive do
  use TictactoeWeb, :live_view
  alias Tictactoe.{Game, Game.Player, Game.BroadcastedMove}
  require Logger

  # TODO: Stop using the csrf token and use another cookie session id
  @impl true
  def mount(_params, %{"_csrf_token" => session_id}, socket) do
    IO.inspect(socket.assigns, label: "\nSocket assigns")

    IO.puts("My pid: #{inspect(self())}")
    IO.puts("Session id: #{session_id}")
    IO.puts("Game State: #{inspect(Game.get_game())}")
    IO.puts("Socket connected? #{inspect(connected?(socket))}")

    if connected?(socket) do
      IO.puts("Load player state")
      Game.subscribe_for_updates()
      send(self(), {:load_player_state, session_id})
    end

    {:ok,
     assign(socket,
       chosen_character: "",
       game: Game.get_game(),
       player: %Player{}
     )}
  end

  @impl true
  def handle_info({:load_player_state, session_id}, socket) do
    result =
      case Game.lookup_player(session_id) do
        nil ->
          Logger.debug("Creating a new player")
          Game.add_player(session_id)

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

  def handle_info({:move, %BroadcastedMove{player: player, position: position}}, socket) do
    Game.move(player, position)

    {:noreply,
     assign(
       socket,
       game: Game.get_game()
     )}
  end

  @impl true
  def handle_event("choose_character", %{"choice" => choice}, socket) do
    IO.puts("Chosen character: #{choice}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("game_move", %{"value" => position}, socket) do
    IO.inspect(position, label: "Move Position")

    player = socket.assigns.player

    if not Game.complete?() do
      Game.move(player, position)
      Game.broadcast_move(player, position)
    end

    {:noreply,
     assign(socket,
       game: Game.get_game()
     )}
  end

  @impl true
  def handle_event("clear_board", _value, socket) do
    Game.clear_board()

    {:noreply,
     assign(socket,
       game: Game.get_game()
     )}
  end

  @impl true
  def handle_event("reset_game", _value, socket) do
    Logger.debug("Resetting the game")
    Game.reset()

    {:noreply,
     socket
     |> clear_flash(:error)
     |> assign(game: Game.get_game())}
  end
end
