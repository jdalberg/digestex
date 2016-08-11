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

  test "mufasa" do
    fields = [{'connection', 'Keep-Alive'}, {'date', 'Wed, 13 Jan 2016 08:37:50 GMT'},
             {'server', 'Apache/2.0.54 (Debian GNU/Linux) DAV/2 SVN/1.3.2'},
             {'www-authenticate', 'Digest realm="testrealm@host.com", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", algorithm=MD5, domain="/auth-digest/", qop="auth"'},
             {'content-length', '401'}, {'content-type', 'text/html; charset=iso-8859-1'},
             {'keep-alive', 'timeout=15, max=100'}]

    {_, _, _, _, res, _} = Digestex.calcResponse(fields, "Mufasa", "Circle Of Life", "/dir/index.html", "GET", "0000000000000000")
    assert res == "75602f584af205e06c65dd6b1ce72c3e"
  end
 
end
