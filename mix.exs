defmodule Digestex.Mixfile do
  use Mix.Project

  def project do
    [app: :digestex,
     version: "0.1.2",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :inets]]
  end

  defp deps do
    []
  end
end
