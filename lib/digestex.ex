defmodule Digestex do

  @methods [get: "GET", post: "POST"]
  @httpc_timeout 8000

  def start(_type, _args) do
    {:ok, pid} = :inets.start(:httpc, [{:profile, :dx_profile}])
    :httpc.set_option(:ipfamily, :inet6fb4, :dx_profile)
    {:ok, pid}
  end

  def get_profile do
    :dx_profile
  end

  def get(url, headers \\ []) do
    :httpc.request(:get,{'#{url}',headers},http_options(),[], get_profile())
  end

  def get_auth(url,user,password,headers \\ []) do
    do_auth('#{url}',:get,user,password,"",headers,'')
  end

  def post(url, data, headers \\ [], type \\ 'application/x-www-form-urlencoded') when is_list(headers) do
    :httpc.request(:post,{'#{url}',headers,type,data},http_options(),[], get_profile())
  end

  def post_auth(url,user,password,data,headers \\ [], type \\ 'application/x-www-form-urlencoded') do
    do_auth('#{url}',:post,user,password,data,headers,type)
  end

  defp do_auth(url,method,user,password,data,headers,type) when is_binary(data) do
    uri = URI.parse(to_string(url))

    request = case method do
      :post -> {url,headers,type,'#{data}'}
      _ -> {url,headers}
    end

    nc = 1

    response = :httpc.request(method,request,http_options(),[], get_profile())
    case response do
      {:ok,{{_,401,_},fields,_}} ->
        # Digest?

        case List.keyfind(fields,'www-authenticate',0) do
          {'www-authenticate', www_authenticate} ->
            {aRes, auth_response} = case String.split(to_string(www_authenticate)," ") do
              ["Digest" | _auth_string] -> digest_auth_response( www_authenticate, user, password, uri.path, @methods[method], nc )
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
                authHeader = authHeader ++ cookie ++ headers

                req=case method do
                  :post -> {url,authHeader,type,String.to_charlist(data)}
                  _ -> {url,authHeader}
                end
                second_response = :httpc.request(method,req,http_options(),[], get_profile())
                # TODO: in the digest case, this response could yield another 401 stale=true response
                # to handle this we need to re-encode the Digest header and retry with new new nonce, increment nc

                case second_response do
                  {:ok,{{_,401,_},second_fields,_}} ->
                    # Digest? - stale=true??
                    case List.keyfind(second_fields,'www-authenticate',0) do
                      {'www-authenticate', stale_www_authenticate} ->
                        digest_fields = digest_fields( stale_www_authenticate )
                        if Map.has_key?(digest_fields,"stale") && String.downcase(digest_fields["stale"]) == "true" do
                          nc = nc + 1 
                          case digest_auth_response( stale_www_authenticate, user, password, uri.path, @methods[method], nc ) do
                            {:ok, stale_auth_response} ->
                              stale_authHeader=[{'Authorization', stale_auth_response}]
                              # have to set cookie if there is a set-cookie in the initial response
                              stale_cookie = case List.keyfind(second_fields,'set-cookie',0) do
                                {'set-cookie',stale_cookieval} -> [{'Cookie',stale_cookieval}]
                                _ -> []
                              end
                              stale_authHeader = stale_authHeader ++ stale_cookie ++ headers
              
                              stale_req=case method do
                                :post -> {url,stale_authHeader,type,String.to_charlist(data)}
                                _ -> {url,stale_authHeader}
                              end
                              :httpc.request(method,stale_req,http_options(),[], get_profile())
              
                            _ -> {:error, "Unable to create digest auth response"}  
                          end
                        else
                          second_response
                        end
                      _ -> {:error, "401, but not WWW-Authenticate header found"}
                    end
                  {:ok,_} -> second_response
                  {:error,err} -> {:error, inspect err}
                end
              _ -> {:error, auth_response}
            end
          _ -> {:error, "401, but not WWW-Authenticate header found"}
        end
      {:ok,_} -> response
      {:error,err} -> {:error, inspect err}
    end
  end

  ## PRIVATE PARTS!
  defp basic_auth_response( user, password ) do
    {:ok, String.to_charlist("Basic " <> Base.encode64("#{user}:#{password}"))}
  end

  defp digest_fields(digestline) do
    matched=Regex.compile!(~s/([a-z]+)=("(.*?)"|([^"]+))( ,|, |,|$)/)
      |> Regex.scan(to_string(digestline))
    for e <- matched, into: %{} do
      case e do
        [_,key,_quotedvalue,"",val,_] -> {key,val}
        [_,key,_quotedvalue,val,"",_] -> {key,val}
      end
    end
  end

  @keys ~w(username realm nonce uri opaque qop response nc cnonce)
  defp digest_auth_response( auth_string, user, password, uri_path, method, nc ) do
    ncstr="#{nc}" |> String.pad_leading(8,"0")

    {realm, nonce, cnonce, resp, opaque} = calcResponse(auth_string, user, password, uri_path, method, ncstr)
    p=%{
      "username" => q(user),
      "realm" => q(realm),
      "nonce" => q(nonce),
      "uri" => q(uri_path),
      "qop" => "auth",
      "nc" => ncstr,
      "cnonce" => q(cnonce),
      "response" => q(resp)
     }
     p=if is_bitstring(opaque) do
       Map.put(p,"opaque",q(opaque))
     else
       p
     end
     l=@keys |> Enum.filter(& p[&1]) |> Enum.map(& (&1 <> "=" <> p[&1]))
     {:ok,String.to_charlist("Digest " <> Enum.join(l,", "))}
  end

  def calcResponse(digestline, user, password, uri, method, cnonce \\ nil, ncstr) do
    dp=digest_fields(digestline)
    
    qoplist=String.split(Map.get(dp, "qop", ""), ",")
    dp = cond do
      Map.has_key?(dp, "opaque") ->
        dp
      true ->
        Map.merge(dp, %{"opaque" => ""})
    end

    cnonce = case cnonce do
      nil -> String.slice(md5(to_string(System.system_time)),0..7)
      _ -> cnonce
    end

    ha1 = if Enum.member?(qoplist,"MD5-sess") do
      md5( md5( user <> ":" <> dp["realm"] <> ":" <> password ) <> ":" <> dp["nonce"] <> ":" <> cnonce )
    else
      md5( user <> ":" <> dp["realm"] <> ":" <> password )
    end
    ha2 = md5( method <> ":" <> uri )

    response = if ( Enum.member?(qoplist,"auth") or Enum.member?(qoplist,"auth-int") ) do
      ha1 <> ":" <> dp["nonce"] <> ":" <> ncstr <> ":" <> cnonce <> ":" <> "auth" <>  ":" <> ha2
    else
      ha1 <> ":" <> dp["nonce"] <> ":" <> ha2
    end
    {dp["realm"],dp["nonce"],cnonce,md5(response),dp["opaque"]}
  end

  defp md5(data) do
    Base.encode16(:erlang.md5(data), case: :lower)
  end

  defp q(a) do
    "\"" <> a <> "\""
  end

  def http_options do
    [
      {:timeout, @httpc_timeout},
      {:relaxed, true}
    ]
  end

end
