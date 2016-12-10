defmodule DigestexHttpBinTest do
  use ExUnit.Case
  doctest Digestex

  setup do
    {:ok, digestex} = Digestex.start_link
    {:ok, digestex: digestex}
  end

  test "get digest, httpbin.org" do
    {res, response} = Digestex.get_auth("http://httpbin.org/digest-auth/auth/user1/pass1", "user1", "pass1")
    assert res == :ok

    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

  test "get basic, httpbin.org" do
    {res, response} = Digestex.get_auth("http://httpbin.org/basic-auth/user1/pass1", "user1", "pass1")
    assert res == :ok
    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

  test "get, httpbin.org" do
    {res, response} = Digestex.get("http://httpbin.org/get")
    assert res == :ok
    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

  test "post, httpbin.org, urlencoded" do
    {res, response} = Digestex.post("http://httpbin.org/post", "foo=bar")
    assert res == :ok
    case response do
      {{_, r_code, _}, _, _} -> assert r_code == 200
      _ -> flunk("response look wrong")
    end
  end

end
