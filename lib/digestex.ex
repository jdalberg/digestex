defmodule Digestex do

  @methods [get: "GET", post: "POST"]

  def digest(url,user,password) do
    do_digest(url,:get,user,password)
  end

  def digest(url,:get,user,password) do
    do_digest(url,:get,user,password,"")
  end

  def digest(_url,:post,_user,_password) do
    {:error, "Method :post needs some data"}
  end

  def digest(_url,_method,_user,_password) do
    {:error, "Method not supported"}
  end

  def digest(url,:post,user,password,data) do
    do_digest(url,:post,user,password,data)
  end

  def digest(url,:get,user,password,_data) do
    do_digest(url,:get,user,password,"")
  end

  def digest(_url,_method, _user, _password, _data) do
    {:error, "Method not supported"}
  end

  defp do_digest(url,:get,user,password) do
    do_digest(url,:get,user,password,"")
  end

  defp do_digest(url,method,user,password,data) when is_binary(data) do
    url = to_char_list(url)
    uri = URI.parse(to_string(url))

    request = case method do
      :post -> {url,[],'application/x-www-form-urlencoded',String.to_char_list(data)}
      _ -> {url,[]}
    end

    response = :httpc.request(method,request,[],[])
    case response do
      {:ok,{{_,401,_},fields,_}} ->
        {realm, nonce, nc, cnonce, resp, opaque} = calcResponse(fields, user, password, uri.path, @methods[method])
        p=%{
          "username" => q(user),
          "realm" => q(realm),
          "nonce" => q(nonce),
          "uri" => q(uri.path),
          "qop" => "auth",
          "nc" => nc,
          "cnonce" => q(cnonce),
          "response" => q(resp)
        }
        p=if is_bitstring(opaque) do
          Map.put(p,"opaque",q(opaque))
        else
          p
        end
        l=for {key,val} <- p, into: [], do: key <> "=" <> val
        authHeader=[{'Authorization', String.to_char_list("Digest " <> Enum.join(l,", "))}]
        # have to set cookie if there is a set-cookie in the initial response
        cookie = case List.keyfind(fields,'set-cookie',0) do
          {'set-cookie',cookieval} -> [{'Cookie',cookieval}]
          _ -> []
        end
        authHeader = authHeader ++ cookie

        req=case method do
          :post -> {url,authHeader,'application/x-www-form-urlencoded',String.to_char_list(data)}
          _ -> {url,authHeader}
        end
        :httpc.request(method,req,[],[])
      {:ok,_} -> response
      {:error,err} -> {:error, inspect err}
    end
  end

  def calcResponse(fields, user, password, uri, method, cnonce \\ nil) do
    digestline=to_string(Enum.into(fields, %{})['www-authenticate'])
    matched=Regex.compile!(~s/([a-z]+)=("(.*?)"|([^"]+))(,|$)/)
    |> Regex.scan(digestline)
    dp=for e <- matched, into: %{} do
      case e do
        [_,key,_quotedvalue,"",val,_] -> {key,val}
        [_,key,_quotedvalue,val,"",_] -> {key,val}
      end
    end

    qoplist=String.split(dp["qop"],",")

    cnonce = case cnonce do
      nil -> String.slice(md5(to_string(System.system_time)),0..7)
      _ -> cnonce
    end

    nc="00000001"
    ha1 = if Enum.member?(qoplist,"MD5-sess") do
      md5( md5( user <> ":" <> dp["realm"] <> ":" <> password ) <> ":" <> dp["nonce"] <> ":" <> cnonce )
    else
      md5( user <> ":" <> dp["realm"] <> ":" <> password )
    end
    ha2 = md5( method <> ":" <> uri )

    response = if ( Enum.member?(qoplist,"auth") or Enum.member?(qoplist,"auth-int") ) do
      ha1 <> ":" <> dp["nonce"] <> ":" <> nc <> ":" <> cnonce <> ":" <> "auth" <>  ":" <> ha2
    else
      ha1 <> ":" <> dp["nonce"] <> ha2
    end
    {dp["realm"],dp["nonce"],nc,cnonce,md5(response),dp["opaque"]}
  end

  defp md5(data) do
    Base.encode16(:erlang.md5(data), case: :lower)
  end

  defp q(a) do
    "\"" <> a <> "\""
  end

end
