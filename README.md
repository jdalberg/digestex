# Digestex
[![Build Status](https://travis-ci.org/jdalberg/digestex.svg?branch=master)](https://travis-ci.org/jdalberg/digestex)
[![Hex.pm Version](http://img.shields.io/hexpm/v/digestex.svg?style=flat)](https://hex.pm/packages/digestex)

An Elixir module that does Digest Auth on top of erlangs httpc

## Synopsis

```
  {:ok, response} = Digestex.get("http://www.example.com/")

  {:ok, response} = Digestex.get_auth("http://www.example.com/", "user", "pass")

```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

    ```elixir
    def deps do
      [{:digestex, "~> 0.4.2"}]
    end
    ```

And then :digestex should be added to you list of applications in mix.exs

## Examples

You can see usage examples in the test files (located in the
[`test/`](test)) directory.
