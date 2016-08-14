defmodule DigestexTest do
  use ExUnit.Case
  doctest Digestex

  test "get digest" do
    {res, {{_, r_code, _}, _, _}} = Digestex.get('http://test.webdav.org/auth-digest', "user1", "user1")
    assert res == :ok
    assert r_code == 404
  end

  test "post digest" do
    {res, {{_, r_code, _}, _, _}} = Digestex.post('http://test.webdav.org/auth-digest', "user1", "user1", "foo=bar")
    assert res == :ok
    assert r_code == 404
  end

end
