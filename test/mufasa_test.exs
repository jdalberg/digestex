defmodule DigestexMufasaTest do
  use ExUnit.Case
  doctest Digestex

  test "mufasa" do
    fields = [{'connection', 'Keep-Alive'}, {'date', 'Wed, 13 Jan 2016 08:37:50 GMT'},
             {'server', 'Apache/2.0.54 (Debian GNU/Linux) DAV/2 SVN/1.3.2'},
             {'www-authenticate', 'Digest realm="testrealm@host.com", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", qop="auth,auth-int", opaque="5ccc069c403ebaf9f0171e9517f40e41"'},
             {'content-length', '401'}, {'content-type', 'text/html; charset=iso-8859-1'},
             {'keep-alive', 'timeout=15, max=100'}]

    {realm, nonce, nc, cnonce, resp, opaque} = Digestex.calcResponse(fields, "Mufasa", "Circle Of Life", "/dir/index.html", "GET", "0a4f113b")
    IO.inspect {realm, nonce, nc, cnonce, resp, opaque}
    assert resp == "6629fae49393a05397450978507c4ef1"
  end

end
