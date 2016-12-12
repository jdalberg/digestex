defmodule Digestex.Mixfile do
  use Mix.Project

  def project do
    [app: :digestex,
     version: "0.2.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
   [applications: [:logger, :inets],
    mod: {Digestex.App, []}
   ]
  end

  defp deps do
    [
      {:prometheus_ex, "~> 1.1.0"}
    ]
  end
end
