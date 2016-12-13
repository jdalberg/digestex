defmodule Digestex do

  @methods [get: "GET", post: "POST"]
  @genserver_timeout 10000
  @httpc_timeout 8000

  use Prometheus.Metric
  use GenServer

  def start_link(profile_name \\ :dx_profile) do
    GenServer.start_link(__MODULE__, profile_name , name: :dx_server)
  end

  ## API
  @doc """

  Ordinary get request.

  """
  def get(url, headers \\ []) do
    GenServer.call(:dx_server, {:get, [ensure_charlist(url), headers]}, @genserver_timeout)
  end

  @doc """

  GET request with digest auth

  """
  def get_auth(url, user, password, headers \\ []) do
    GenServer.call(:dx_server, {:get_auth, [ensure_charlist(url), user, password, headers]}, @genserver_timeout)
  end

  @doc """

  do a no-auth POST

  """
  def post(url, data, headers \\ [], type \\ 'application/x-www-form-urlencoded') when is_list(headers) do
    GenServer.call(:dx_server, {:post,[ensure_charlist(url),headers,type,ensure_charlist(data)]}, @genserver_timeout)
  end

  @doc """

  a digest auth POST

  """
  def post_auth(url, user, password, data, headers \\ [], type \\ 'application/x-www-form-urlencoded') do
    GenServer.call(:dx_server, {:post_auth,[ensure_charlist(url),user,password,ensure_charlist(data),headers,type]}, @genserver_timeout)
  end

  @doc """

  an incomming async response, should not be called from the outside

  """
  def async_response(reply_info) do
    GenServer.cast(:dx_server, {:async_response, [reply_info]})
  end

  ## Server

  def init(profile_name) do
    :inets.start(:httpc, [{:profile, profile_name}])
    :httpc.set_options([{:ipfamily, :inet6fb4}], profile_name)
    Process.flag(:trap_exit, true)
    # outstanding_requests is a map with req_id, client_pid
    {:ok, %{profile: profile_name, outstanding_requests: %{}}}
  end

  @doc """

  Ordinary get request, no auth.

  """
  def handle_call({:get, [url, headers]}, from, state) do
    case :httpc.request(:get,{url,headers},http_options,default_options,state.profile) do
      {:ok, req_id} ->
        {:noreply, %{state | outstanding_requests: Map.merge(state.outstanding_requests, %{ req_id => from })}, @genserver_timeout}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end


  def handle_call({:get_auth, [url,user,password,headers]}, from, state) do
    case do_auth(url,:get,user,password,"",headers,'',state.profile) do
      {:ok, req_id} ->
        {:noreply, %{state | outstanding_requests: Map.merge(state.outstanding_requests, %{ req_id => from })}, @genserver_timeout}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:post, [url, data, headers, type]}, from, state) do
    case :httpc.request(:post,{url,headers,type,data},http_options,default_options,state.profile) do
      {:ok, req_id} ->
        {:noreply, %{state | outstanding_requests: Map.merge(state.outstanding_requests, %{ req_id => from })}, @genserver_timeout}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:post_auth, [url, user, password, data, headers, type]}, from, state) do
    case do_auth(url,:post,user,password,data,headers,type,state.profile) do
      {:ok, req_id} ->
        {:noreply, %{state | outstanding_requests: Map.merge(state.outstanding_requests, %{ req_id => from })}, @genserver_timeout}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_cast({:async_response, [reply_info]}, state) do
    case reply_info do
      {req_id, {:error, :timeout}} ->
        # There is no reason to cancel the request in httpc, because this timeout
        # is the normal one generated after @httpc_timeout ms, we should just clear
        # from state, and reply with the timeout.
        GenServer.reply(state.outstanding_requests[req_id], {:error, :timeout})
        {:noreply, %{state | outstanding_requests: Map.drop(state.outstanding_requests,[req_id])}}
      {req_id, result} ->
        cond do
          Map.has_key?(state.outstanding_requests,req_id) ->
            GenServer.reply(state.outstanding_requests[req_id], {:ok, result})
            {:noreply, %{state | outstanding_requests: Map.drop(state.outstanding_requests,[req_id])}}
          true ->
            {:noreply, state}
        end
      weirdness ->
        # Should never happen.
        cancel_all(state.outstanding_requests)
        {:noreply, %{state | outstanding_requests: []}} # panic and remove all
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    # find the pid in the outstanding map, and remove the req_id and cancel it
    cancel_all(state.outstanding_requests)
    {:noreply, %{ state | outstanding_requests: %{}}}
  end

  # an outstanding request encountered the GenServer timeout, this shoudn't really be possible
  # because the timeout from httpc should have allready handled the request.
  # .. but in cases where httpc dies or some similar disaster, then perhaps...
  # .. since it IS a disaster scenario, we can just clear the state.
  def handle_info(:timeout, state) do
    cancel_all(state.outstanding_requests)
    {:noreply, %{ state | outstanding_requests: %{}}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp do_auth(url,method,user,password,data,headers,type,profile) do
    uri = URI.parse(to_string(url))

    request = case method do
      :post -> {url,headers,type,data}
      _ -> {url,headers}
    end

    # do a sync request first, because we expect the 401 header.
    response = :httpc.request(method,request,[],[],profile)
    case response do
      {:ok,{{_,401,_},fields,_}} ->
        # Digest?
        case List.keyfind(fields,'www-authenticate',0) do
          {'www-authenticate', www_authenticate} ->
            {aRes, auth_response} = case String.split(to_string(www_authenticate)," ") do
              ["Digest" | _auth_string] -> digest_auth_response( www_authenticate, user, password, uri.path, @methods[method] )
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
                  :post -> {url,authHeader,type,data}
                  _ -> {url,authHeader}
                end
                # this is the actual request then, so this shoud be async like a normal get
                :httpc.request(method,req,http_options,default_options,profile)
              _ -> {:error, auth_response}
            end
          _ -> {:error, "401, but not WWW-Authenticate header found"}
        end
      {:ok,_} -> {:response, response}
      {:error,err} -> {:error,err}
    end
  end

  ## PRIVATE PARTS!
  defp basic_auth_response( user, password ) do
    {:ok, String.to_charlist("Basic " <> Base.encode64("#{user}:#{password}"))}
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
     {:ok,String.to_charlist("Digest " <> Enum.join(l,", "))}
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

  defp ensure_charlist(s) when is_binary(s) do
    String.to_charlist(s)
  end
  defp ensure_charlist(c) do
    c
  end

  def http_options do
    [
      {:timeout, @httpc_timeout},
      {:relaxed, true}
    ]
  end

  def default_options do
    [
      {:sync, false}, # make requests async
      {:receiver, &async_response/1}
    ]
  end

  defp cancel_all(outstanding_requests) do
    for req_id <- Map.keys(outstanding_requests) do
      :httpc.cancel_request(req_id)
      GenServer.reply(outstanding_requests[req_id],{:error, :cancelled})
    end
  end
end
