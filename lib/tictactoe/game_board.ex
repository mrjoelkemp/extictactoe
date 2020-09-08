defmodule TicTacToe.GameBoard do
  @moduledoc """
  A game board that holds the state of a single game
  """
  use Agent

  @board %{
      "0_0" => "",
      "0_1" => "",
      "0_2" => "",
      "1_0" => "",
      "1_1" => "",
      "1_2" => "",
      "2_0" => "",
      "2_1" => "",
      "2_2" => ""
    }
  def start_link(_initial_value) do
    Agent.start_link(fn -> @board end, name: __MODULE__)
  end

  @spec get_board :: map
  def get_board do
    Agent.get(__MODULE__, & &1)
  end

  def complete? do
    get_board()
    |> has_winner?()
  end

  @spec has_winner?(map) :: boolean()
  def has_winner?(board) when is_map(board) do
    has_winning_column?(board) or has_winning_row?(board) or has_winning_diagonal?(board)
  end

  @spec has_winning_row?(map) :: boolean()
  defp has_winning_row?(board) do
      0..2
      |> Enum.map(fn row_index -> is_winning_row?(row_index, board) end)
      |> Enum.any?()
  end

  defp is_winning_row?(row_index, board) do
    0..2
    |> Enum.map(fn col_index -> "#{row_index}_#{col_index}" end)
    |> Enum.map(fn key -> board[key] end)
    |> all_moves_from_the_same_player?()
  end

  @spec all_moves_from_the_same_player?([binary()]) :: boolean
  defp all_moves_from_the_same_player?(moves) do
    unique_moves = Enum.uniq(moves)

    Enum.count(unique_moves) == 1 and unique_moves != [""]
  end

  @spec has_winning_column?(map) :: boolean()
  defp has_winning_column?(board) do
    0..2
    |> Enum.map(fn column_index -> is_winning_column?(column_index, board) end)
    |> Enum.any?
  end

  defp is_winning_column?(column_index, board) do
    # Go through the row elements along that column_index
    # So, if column_index = 0, then hit "0_0", "1_0", "2_0"
    0..2
    |> Enum.map(fn row -> "#{row}_#{column_index}" end)
    |> Enum.map(fn key -> board[key] end)
    |> all_moves_from_the_same_player?()
  end

  @spec has_winning_diagonal?(map) :: boolean()
  defp has_winning_diagonal?(board) do
    false
  end

  @spec move(binary(), binary()) :: :ok
  def move(player, position) do
      Agent.update(__MODULE__, fn board ->
        if Map.has_key?(board, position) do
          Map.put(board, position, player)
        end
      end)
  end

  def clear do
    Agent.update(__MODULE__, fn _ -> @board end)
  end
end
