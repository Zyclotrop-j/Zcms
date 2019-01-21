defmodule ZcmsWeb.GQLContext do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  @doc """
  Return the conn and put it's current state in the context
  """
  def build_context(conn) do
    %{:conn => conn}
  end
end
