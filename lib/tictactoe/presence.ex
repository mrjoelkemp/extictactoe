defmodule Tictactoe.Presence do
  use Phoenix.Presence,
    otp_app: :tictactoe,
    pubsub_server: Tictactoe.PubSub
end
