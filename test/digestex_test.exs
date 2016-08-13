defmodule DigestexTest do
  use ExUnit.Case
  doctest Digestex

  test "bad method" do
    assert {:error, "Method not supported"} == Digestex.digest('http://test.webdav.org/auth-digest', "FOO", "user1", "user1", "test=foo")
  end

  test "get digest" do
    {res, {{_, r_code, _}, _, _}} = Digestex.digest('http://test.webdav.org/auth-digest', :get, "user1", "user1")
    assert res == :ok
    assert r_code == 404
  end

  test "get digest, short" do
    {res, {{_, r_code, _}, _, _}} = Digestex.digest("http://test.webdav.org/auth-digest", "user1", "user1")
    assert res == :ok
    assert r_code == 404
  end

  test "post digest" do
    {res, {{_, r_code, _}, _, _}} = Digestex.digest('http://test.webdav.org/auth-digest', :post, "user1", "user1", "foo=bar")
    assert res == :ok
    assert r_code == 404
  end

end
