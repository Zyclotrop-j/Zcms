defmodule ZcmsWeb.PageController do
  use ZcmsWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
