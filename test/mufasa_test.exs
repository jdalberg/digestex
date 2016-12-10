defmodule DigestexMufasaTest do
  use ExUnit.Case
  doctest Digestex

  setup do
    {:ok, digestex} = Digestex.start_link
    {:ok, digestex: digestex}
  end

  test "mufasa" do
    www_authenticate = 'Digest realm="testrealm@host.com", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", qop="auth,auth-int", opaque="5ccc069c403ebaf9f0171e9517f40e41"'

    {realm, nonce, nc, cnonce, resp, opaque} = Digestex.calcResponse(www_authenticate, "Mufasa", "Circle Of Life", "/dir/index.html", "GET", "0a4f113b")
    assert resp == "6629fae49393a05397450978507c4ef1"
    assert opaque == "5ccc069c403ebaf9f0171e9517f40e41"
    assert realm == "testrealm@host.com"
    assert nc == "00000001"
    assert cnonce == "0a4f113b"
    assert nonce == "dcd98b7102dd2f0e8b11d0f600bfb0c093"
  end

end
