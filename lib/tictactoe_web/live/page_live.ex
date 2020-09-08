defmodule TictactoeWeb.PageLive do
  use TictactoeWeb, :live_view
  alias TicTacToe.GameBoard

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      chosen_character: "",
      game_complete?: GameBoard.complete?,
      board: GameBoard.get_board())}
  end

  # @impl true
  # def handle_event("choose_character", %{"choice" => choice}, socket) do
  #   {:noreply, assign(socket, results: search(query), query: query)}
  # end

  @impl true
  def handle_event("game_move", %{"value" => position}, socket) do
    IO.inspect(position, label: "Move Position")

    if not GameBoard.complete? do
      GameBoard.move("X", position)
    end

    {:noreply, assign(socket,
      board: GameBoard.get_board(),
      game_complete?: GameBoard.complete?
      )}
  end

  @impl true
  def handle_event("clear_game", _value, socket) do
    GameBoard.clear()

    {:noreply, assign(socket,
      board: GameBoard.get_board(),
      game_complete?: false
    )}
  end
end
