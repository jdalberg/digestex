defmodule Digestex.Mixfile do
  use Mix.Project

  def project do
    [app: :digestex,
     version: "0.4.2",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: [:inets],
     mod: {Digestex, []} ]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    """
    An elixir module for doing HTTP digest authentication using erlang httpc
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "CHANGELOG*"],
      maintainers: ["Jesper Dalberg"],
      licenses: ["Artistic"],
      links: %{"GitHub" => "https://github.com/jdalberg/digestex"}
    ]
  end
end
