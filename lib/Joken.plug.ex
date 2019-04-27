if Code.ensure_loaded?(Plug.Conn) do
  defmodule ZcmsWeb.JokenPlug do
    import Joken
    alias Joken.Token
    require Logger

    import Plug.Conn

    @lint {Credo.Check.Design.AliasUsage, false}
    @doc false
    def init(opts) do
      verify = get_verify(opts)
      on_error = Keyword.get(opts, :on_error, &Joken.Plug.default_on_error/2)
      token_function = Keyword.get(opts, :token, &Joken.Plug.default_token_function/1)
      {verify, on_error, token_function}
    end

    @doc false
    def call(conn, {verify, on_error, token_function}) do
      conn =
        if Map.has_key?(conn.private, :joken_verify) do
          conn
        else
          set_joken_verify(conn, verify)
        end

      conn =
        if Map.has_key?(conn.private, :joken_on_error) do
          conn
        else
          put_private(conn, :joken_on_error, on_error)
        end

      conn =
        if Map.has_key?(conn.private, :joken_token_function) do
          conn
        else
          put_private(conn, :joken_token_function, token_function)
        end

      if Map.get(conn.private, :joken_skip, false) do
        conn
      else
        parse_auth(conn, conn.private[:joken_token_function].(conn))
      end
    end

    defp get_verify(options) do
      case Keyword.take(options, [:verify, :on_verifying]) do
        [verify: verify] ->
          verify

        [verify: verify, on_verifying: _] ->
          warn_on_verifying()
          verify

        [on_verifying: verify] ->
          warn_on_verifying()
          verify

        [] ->
          warn_supply_verify_function()
          nil
      end
    end

    defp warn_on_verifying do
      Logger.warn(
        "on_verifying is deprecated for the Joken plug and will be removed in a future version. Please use verify instead."
      )
    end

    defp warn_supply_verify_function do
      Logger.warn("You need to supply a verify function to the Joken token.")
    end

    defp set_joken_verify(conn, verify) do
      case conn.private do
        %{joken_on_verifying: deprecated_verify} ->
          warn_on_verifying()
          put_private(conn, :joken_verify, deprecated_verify)

        _ ->
          put_private(conn, :joken_verify, verify)
      end
    end

    defp parse_auth(conn, nil) do
      # public access -> auth is handled by mongodb query
      conn
    end

    defp parse_auth(conn, ""), do: parse_auth(conn, nil)

    defp parse_auth(conn, incoming_token) do
      payload_fun = Map.get(conn.private, :joken_verify)

      verified_token =
        payload_fun.(conn)
        |> with_compact_token(incoming_token)
        |> verify

      evaluate(conn, verified_token)
    end

    defp evaluate(conn, %Token{error: nil} = token) do
      assign(conn, :joken_claims, get_claims(token))
    end

    defp evaluate(conn, %Token{error: message}) do
      send_401(conn, message)
    end

    defp send_401(conn, message) do
      on_error = conn.private[:joken_on_error]

      {conn, message} =
        case on_error.(conn, message) do
          {conn, map} when is_map(map) ->
            create_json_response(conn, map)

          response ->
            response
        end

      conn
      |> send_resp(401, message)
      |> halt
    end

    defp create_json_response(conn, map) do
      conn = put_resp_content_type(conn, "application/json")
      json = Poison.encode!(map)
      {conn, json}
    end

    @doc false
    def default_on_error(conn, message) do
      {conn, message}
    end

    @doc false
    def default_token_function(conn) do
      get_req_header(conn, "authorization") |> token_from_header
    end

    defp token_from_header(["Bearer " <> incoming_token]), do: incoming_token
    defp token_from_header(_), do: nil
  end
end
