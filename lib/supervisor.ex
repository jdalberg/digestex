defmodule Digestex.Supervisor do
  use Supervisor

  # A simple module attribute that stores the supervisor name
  @name Digestex.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    children = [
      worker(Digestex, [:dx_profile])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
