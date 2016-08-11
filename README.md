# Digestex

An Elixir module that does Digest Auth on top of erlangs httpc

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `digestex` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:digestex, "~> 0.0.1"}]
    end
    ```

  2. Ensure `digestex` is started before your application:

    ```elixir
    def application do
      [applications: [:digestex]]
    end
    ```

## Examples ## 

You can see usage examples in the test files (located in the
[`test/`](test)) directory.
