defmodule DigestexHttpBinTest do
  use ExUnit.Case
  doctest Digestex

  test "get digest, httpbin.org" do
    {res, response} = Digestex.get("http://httpbin.org/digest-auth/auth/user1/pass1", "user1", "pass1")
    assert res == :ok

    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

  test "get basic, httpbin.org" do
    {res, response} = Digestex.get("http://httpbin.org/basic-auth/user1/pass1", "user1", "pass1")
    assert res == :ok
    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

end
