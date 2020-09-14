defmodule Tictactoe.GameBoard do
  @moduledoc """
  A game board that represents the state of a single game
  """
  alias __MODULE__
  require Logger

  defmodule WinState do
    defstruct character: "", moves: []
  end

  defstruct "0_0": "",
            "0_1": "",
            "0_2": "",
            "1_0": "",
            "1_1": "",
            "1_2": "",
            "2_0": "",
            "2_1": "",
            "2_2": ""

  @doc """
  Gives you a valid board position from the given x and y coordinates

  Will raise an ArgumentError if the position is out of bounds from the game board.
  That should only really happen on programmer error, that's why we're throwing
  """
  @spec get_position_from_coordinates(number, number) :: atom
  def get_position_from_coordinates(x, y) do
    key = :"#{x}_#{y}"

    # If it's a valid position
    if Map.has_key?(%GameBoard{}, key) do
      key
    else
      raise ArgumentError, message: "Coordinates do not map to a valid position"
    end

    key
  end

  @spec has_move_here?(%GameBoard{}, number, number) :: boolean
  def has_move_here?(%GameBoard{} = board, x_pos, y_pos) do
    pos = get_position_from_coordinates(x_pos, y_pos)
    # We know the pos has to be a valid board position,
    # but defaulting missing keys to "" this is just in case
    Map.get(board, pos, "") != ""
  end

  @spec get_move(%GameBoard{}, number, number) :: binary
  def get_move(%GameBoard{} = board, x_pos, y_pos) do
    position = get_position_from_coordinates(x_pos, y_pos)
    Map.get(board, position)
  end

  @spec complete?(%GameBoard{}) :: boolean()
  def complete?(board) do
    has_winner?(board)
  end

  def get_winning_state(board) do
    # Need the winning character and list of moves
    winning_moves = get_winning_moves(board)

    if winning_moves == [] do
      %WinState{}
    else
      character = Map.get(board, List.first(winning_moves))

      %WinState{
        character: character,
        moves: winning_moves
      }
    end
  end

  @spec get_winning_moves(%GameBoard{}) :: [atom]
  defp get_winning_moves(board) do
    cond do
      has_winning_row?(board) ->
        get_winning_row_positions(board)

      has_winning_column?(board) ->
        get_winning_column_positions(board)

      has_winning_backslash_diagonal?(board) ->
        get_backslash_diagonal_positions()

      has_winning_forward_slash_diagonal?(board) ->
        get_forward_slash_diagonal_positions()

      true ->
        []
    end
  end

  @spec has_winner?(%GameBoard{}) :: boolean()
  def has_winner?(board) when is_map(board) do
    has_winning_column?(board) or has_winning_row?(board) or has_winning_diagonal?(board)
  end

  @spec has_winning_row?(%GameBoard{}) :: boolean()
  defp has_winning_row?(board) do
    0..2
    |> Enum.map(fn row_index -> is_winning_row?(row_index, board) end)
    |> Enum.any?()
  end

  @spec get_winning_row_positions(%GameBoard{}) :: [atom]
  defp get_winning_row_positions(board) do
    winning_row_index =
      0..2
      |> Enum.find(fn row_index -> is_winning_row?(row_index, board) end)

    if winning_row_index == nil do
      []
    else
      get_positions_for_row_index(winning_row_index)
    end
  end

  @spec is_winning_row?(number, %GameBoard{}) :: boolean
  defp is_winning_row?(row_index, board) do
    get_positions_for_row_index(row_index)
    |> Enum.map(fn position -> Map.get(board, position) end)
    |> all_moves_from_the_same_player?()
  end

  @spec get_positions_for_row_index(number) :: [atom]
  defp get_positions_for_row_index(row_index) do
    0..2
    |> Enum.map(fn col_index -> :"#{row_index}_#{col_index}" end)
  end

  @spec all_moves_from_the_same_player?([binary()]) :: boolean
  defp all_moves_from_the_same_player?(moves) do
    unique_moves = Enum.uniq(moves)

    Enum.count(unique_moves) == 1 and unique_moves != [""]
  end

  @spec has_winning_column?(%GameBoard{}) :: boolean()
  defp has_winning_column?(board) do
    0..2
    |> Enum.map(fn column_index -> is_winning_column?(column_index, board) end)
    |> Enum.any?()
  end

  @spec is_winning_column?(number, map) :: boolean()
  defp is_winning_column?(column_index, board) do
    # Go through the row elements along that column_index
    # So, if column_index = 0, then hit "0_0", "1_0", "2_0"
    get_positions_for_column_index(column_index)
    |> Enum.map(fn key -> Map.get(board, key) end)
    |> all_moves_from_the_same_player?()
  end

  @spec get_winning_column_positions(%GameBoard{}) :: [atom]
  defp get_winning_column_positions(board) do
    winning_column_index =
      0..2
      |> Enum.find(fn column_index -> is_winning_column?(column_index, board) end)

    if winning_column_index == nil do
      []
    else
      get_positions_for_column_index(winning_column_index)
    end
  end

  @spec get_positions_for_column_index(number) :: [atom]
  defp get_positions_for_column_index(column_index) do
    0..2
    |> Enum.map(fn row -> :"#{row}_#{column_index}" end)
  end

  @spec has_winning_diagonal?(%GameBoard{}) :: boolean()
  defp has_winning_diagonal?(board) do
    has_winning_backslash_diagonal?(board) or has_winning_forward_slash_diagonal?(board)
  end

  # This looks at the 0_0, 1_1, and 2_2 positions (looks like a backslash)
  @spec has_winning_backslash_diagonal?(%GameBoard{}) :: boolean
  defp has_winning_backslash_diagonal?(board) do
    get_backslash_diagonal_positions()
    |> Enum.map(fn position -> Map.get(board, position) end)
    |> all_moves_from_the_same_player?()
  end

  @spec get_backslash_diagonal_positions :: [atom]
  defp get_backslash_diagonal_positions() do
    0..2
    |> Enum.map(fn index -> :"#{index}_#{index}" end)
  end

  # This looks at the 0_3, 1_1, and 3_0 positions (looks like a forward slash)
  @spec has_winning_forward_slash_diagonal?(%GameBoard{}) :: boolean
  defp has_winning_forward_slash_diagonal?(board) do
    get_forward_slash_diagonal_positions()
    |> Enum.map(fn position -> Map.get(board, position) end)
    |> all_moves_from_the_same_player?()
  end

  @spec get_forward_slash_diagonal_positions :: [atom]
  defp get_forward_slash_diagonal_positions() do
    [:"0_3", :"1_1", :"3_0"]
  end
end
