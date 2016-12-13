defmodule Digestex.App do
  use Application

  def start( _type, _args ) do
    import Supervisor.Spec

    children = [
      worker(Digestex, [:dx_profile])
    ]

    case Supervisor.start_link(children, strategy: :one_for_one) do
      {:ok, sup} ->
         {:ok, sup, []}
      {:error, _} = error ->
         error
    end
  end
end
