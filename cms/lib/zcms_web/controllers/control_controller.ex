defmodule ZcmsWeb.ControlController do
  use ZcmsWeb, :controller

  def index(conn, _params) do
    :ok =
      Zcms.Application.Transformer.transformSchema(fn a, b ->
        Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
      end)

    send_resp(conn, :no_content, "")
  end
end
