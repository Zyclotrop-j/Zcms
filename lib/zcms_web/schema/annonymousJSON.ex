defmodule ZcmsWeb.Schema.Types.Custom.JSON do
  @moduledoc """
  The Json scalar type allows arbitrary JSON values to be passed in and out.
  Requires `{ :jason, "~> 1.1" }` package: https://github.com/michalmuskala/jason
  """
  use Absinthe.Schema.Notation

  scalar :json, name: "Json" do
    description("""
    The `Json` scalar type represents arbitrary json string data, represented as UTF-8
    character sequences. The Json type is most often used to represent a free-form
    human-readable json string.
    """)

    serialize(&encode/1)
    parse(&decode/1)
  end

  @spec decode(Absinthe.Blueprint.Input.String.t()) :: {:ok, term()}
  @spec decode(Absinthe.Blueprint.Input.Object.t()) :: {:ok, term()}
  @spec decode(Absinthe.Blueprint.Input.Integer.t()) :: {:ok, term()}
  @spec decode(Absinthe.Blueprint.Input.Float.t()) :: {:ok, term()}
  @spec decode(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  defp decode(val) do
    value = extract(val)
    IO.puts("Inside custom scalar")
    {:ok, value}
  end

  defp encode(value) do
    IO.puts("encode")
    value
  end

  defp extract(%Absinthe.Blueprint.Input.String{value: value}), do: value
  defp extract(%Absinthe.Blueprint.Input.Integer{value: value}), do: value
  defp extract(%Absinthe.Blueprint.Input.Float{value: value}), do: value
  defp extract(%Absinthe.Blueprint.Input.Null{}), do: nil

  defp extract(%Absinthe.Blueprint.Input.Object{fields: fields}) do
    fields
    |> Enum.map(fn %Absinthe.Blueprint.Input.Field{name: name, input_value: input_value} ->
      {name, extract(input_value.normalized)}
    end)
    |> Enum.into(%{})
  end

  defp extract(%Absinthe.Blueprint.Input.List{items: items}) do
    items
    |> Enum.map(fn %Absinthe.Blueprint.Input.Value{normalized: normalized} ->
      extract(normalized)
    end)
  end
end
