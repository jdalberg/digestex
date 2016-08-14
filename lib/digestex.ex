defmodule Digestex do

  @methods [get: "GET", post: "POST"]

  def get(url,user,password) do
    do_auth(url,:get,user,password)
  end

  def post(_url,:post,_user,_password) do
    {:error, "Method :post needs some data"}
  end

  def post(url,user,password,data) do
    do_auth(url,:post,user,password,data)
  end

  defp do_auth(url,:get,user,password) do
    do_auth(url,:get,user,password,"")
  end

  defp do_auth(url,method,user,password,data) when is_binary(data) do
    url = to_char_list(url)
    uri = URI.parse(to_string(url))

    request = case method do
      :post -> {url,[],'application/x-www-form-urlencoded',String.to_char_list(data)}
      _ -> {url,[]}
    end

    response = :httpc.request(method,request,[],[])
    case response do
      {:ok,{{_,401,_},fields,_}} ->
        # Digest?
        case List.keyfind(fields,'www-authenticate',0) do
          {'www-authenticate', www_authenticate} ->
            {aRes, auth_response} = case String.split(to_string(www_authenticate)," ") do
              ["Digest" | auth_string] -> digest_auth_response( www_authenticate, user, password, uri.path, @methods[method] )
              ["Basic" | _auth_string] -> basic_auth_response( user, password )
              _ -> {:error, "Unknown WWW-Authenticate header: #{www_authenticate}"}
            end
            case aRes do
              :ok ->
                authHeader=[{'Authorization', auth_response}]
                # have to set cookie if there is a set-cookie in the initial response
                cookie = case List.keyfind(fields,'set-cookie',0) do
                  {'set-cookie',cookieval} -> [{'Cookie',cookieval}]
                  _ -> []
                end
                authHeader = authHeader ++ cookie

                req=case method do
                  # TODO: type shold be configurable
                  :post -> {url,authHeader,'application/x-www-form-urlencoded',String.to_char_list(data)}
                  _ -> {url,authHeader}
                end
                :httpc.request(method,req,[],[])
              _ -> {:error, auth_response}
            end
          _ -> {:error, "401, but not WWW-Authenticate header found"}
        end
      {:ok,_} -> response
      {:error,err} -> {:error, inspect err}
    end
  end

  defp basic_auth_response( user, password ) do
    {:ok, String.to_char_list("Basic " <> Base.encode64("#{user}:#{password}"))}
  end

  defp digest_auth_response( auth_string, user, password, uri_path, method ) do
    {realm, nonce, nc, cnonce, resp, opaque} = calcResponse(auth_string, user, password, uri_path, method)
    p=%{
      "username" => q(user),
      "realm" => q(realm),
      "nonce" => q(nonce),
      "uri" => q(uri_path),
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
     {:ok,String.to_char_list("Digest " <> Enum.join(l,", "))}
  end

  def calcResponse(digestline, user, password, uri, method, cnonce \\ nil) do
    #digestline=to_string(Enum.into(fields, %{})['www-authenticate'])
    matched=Regex.compile!(~s/([a-z]+)=("(.*?)"|([^"]+))(,|$)/)
    |> Regex.scan(to_string(digestline))
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
