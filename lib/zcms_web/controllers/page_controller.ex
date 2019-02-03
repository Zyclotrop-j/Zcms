defmodule ZcmsWeb.PageController do
  use ZcmsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def login(conn, _params) do
    render(conn, "login.html")
  end

  def swaggerui(conn, _params) do
    render(conn, "swaggerui.html")
  end
end
