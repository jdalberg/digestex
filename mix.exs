defmodule Digestex.Mixfile do
  use Mix.Project

  def project do
    [app: :digestex,
     version: "0.4.2",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:inets],
     mod: {Digestex, []} ]
  end

  defp deps do
    []
  end
end
