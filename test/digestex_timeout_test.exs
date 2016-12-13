defmodule DigestexTimeoutTest do
  use ExUnit.Case, async: true
  doctest Digestex

  test "very slow get" do
    # this will cause a timeout in httpc, which should respond and and forget
    {code, reason}  = Digestex.get('http://httpbin.org/delay/9')
    assert code == :error
    assert reason == :timeout
  end

  test "slow get" do
    {res, {{_, r_code, _}, _, _}} = Digestex.get('http://httpbin.org/delay/2')
    assert res == :ok
    assert r_code == 200
  end

end
