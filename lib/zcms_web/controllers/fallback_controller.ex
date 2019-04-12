defmodule ZcmsWeb.Forbidden do
  defexception detail: nil, message: "You do not have access to this resource.", plug_status: 403
end

defmodule ZcmsWeb.NotFound do
  defexception detail: nil, message: "Resource not found.", plug_status: 404
end

defmodule ZcmsWeb.MissingHeader do
  defexception detail: nil, message: "Mandatory header missing.", plug_status: 400
end

defmodule ZcmsWeb.InvalidRequest do
  defexception detail: nil, message: "Request invalid", plug_status: 400
end

defmodule ZcmsWeb.BodyTooBig do
  defexception detail: nil,
               message: "Payload too big. Request payload must be smaller 1MB",
               plug_status: 413
end

defmodule ZcmsWeb.BodyReadFail do
  defexception detail: nil, message: "Failed to request parse body", plug_status: 500
end

defmodule ZcmsWeb.BadProxyUrl do
  defexception detail: nil, message: "The proxy url request is not allowed", plug_status: 500
end

defmodule ZcmsWeb.Unauthenticated do
  defexception detail: nil,
               message: "Unauthenticated - access token required.",
               plug_status: 401,
               conn: nil

  def exception(opts) do
    conn = Keyword.fetch!(opts, :conn)

    %ZcmsWeb.Unauthenticated{
      message: Keyword.fetch!(opts, :message),
      detail: Keyword.fetch!(opts, :detail),
      conn: conn
    }
  end
end

defimpl Plug.Exception, for: Plug.Parsers.ParseError do
  def status(_exception), do: 400
end

defmodule ZcmsWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ZcmsWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(ZcmsWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, %{type: :json_schema_error, message: msg}}) do
    conn
    |> put_status(:bad_request)
    |> render(ZcmsWeb.ErrorView, :"400", message: msg)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(ZcmsWeb.ErrorView, :"404")
  end

  def call(conn, {:error, error}) when is_binary(error) do
    conn
    |> put_status(:internal_server_error)
    |> render(ZcmsWeb.ErrorView, :"500", message: error)
  end

  def call(conn, _) do
    conn
    |> put_status(:not_found)
    |> render(ZcmsWeb.ErrorView, :"404")
  end
end
