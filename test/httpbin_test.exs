defmodule DigestexHttpBinTest do
  use ExUnit.Case
  doctest Digestex

  test "get digest, short, httpbin.org" do
    {res, response} = Digestex.digest("http://httpbin.org/digest-auth/auth/user1/pass1", :get, "user1", "pass1")
    assert res == :ok

    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

end
