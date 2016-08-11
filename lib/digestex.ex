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
    do_digest(url,:get,user,password,data)
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
      :post -> {url,[],"application/x-www-form-urlencoded",data}
      _ -> {url,[]}
    end

    {:ok,{{_,r_code,_},fields,_}}=:httpc.request(method,request,[],[])
    if ( r_code == 401 ) do
      {realm, nonce, nc, cnonce, resp, opaque} = calcResponse(fields, user, password, uri.path, @methods[method], "0000000000000000")

      p=%{
        "Digest username" => q(user),
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
      authHeader=[{'Authorization', String.to_char_list(Enum.join(l,","))}]
      req=case method do
        :post -> {url,authHeader,"application/x-www-form-urlencoded",data}
        _ -> {url,authHeader}
      end
      :httpc.request(method,req,[],[])
      #  :inets.stop()
    else
      {:error, "Response code #{r_code} returned when 401 was expected"}
    end
  end

  def calcResponse(fields, user, password, uri, method, nc) do
    digestline = to_string(:proplists.get_value('www-authenticate', fields))
    dp=Enum.into(String.split(String.slice(digestline,7..-1),","),%{},fn x -> [k,v]=String.split(String.strip(x),"=",parts: 2);{k,String.strip(v,?")} end)
    cnonce = md5(:erlang.integer_to_list(:erlang.trunc(:random.uniform()*10000000000000000)))

    ha1 = case dp["qop"] do
      "MD5-sess" -> md5( md5( user <> ":" <> dp["realm"] <> ":" <> password ) <> ":" <> dp["nonce"] <> ":" <> cnonce )
      _ -> md5( user <> ":" <> dp["realm"] <> ":" <> password )
    end
    ha2 = md5( method <> ":" <> uri )

    response = if ( dp["qop"] == "auth" or dp["qop"] == "auth-int" ) do
      ha1 <> ":" <> dp["nonce"] <> ":" <> nc <> ":" <> cnonce <> ":" <> dp["qop"] <>  ":" <> ha2
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
