defmodule ZcmsWeb.SchemaCache do
  @moduledoc """
  A simple ETS based cache for expensive function calls.
  """

  @doc """
  Retrieve a cached value or apply the given function caching and returning
  the result.
  """
  def get(schema, schemaloader, opts \\ []) do
    case lookup(schema) do
      nil ->
        ttl = Keyword.get(opts, :ttl, 3600)
        cache_apply(schema, schemaloader, ttl)

      result ->
        {:ok, result}
    end
  end

  @doc """
  Clear a cached value
  """
  def clear(schema, opts \\ []) do
    :ets.delete(:schema_cache, schema)
  end

  @doc """
  Lookup a cached result and check the freshness
  """
  defp lookup(schema) do
    case :ets.lookup(:schema_cache, schema) do
      [result | _] -> check_freshness(result)
      [] -> nil
    end
  end

  @doc """
  Compare the result expiration against the current system time.
  """
  defp check_freshness({mfa, result, expiration}) do
    cond do
      expiration > :os.system_time(:seconds) -> result
      :else -> nil
    end
  end

  @doc """
  Apply the function, calculate expiration, and cache the result.
  """
  defp cache_apply(schema, schemaloader, ttl) do
    case schemaloader.(schema) do
      {:ok, result} ->
        cttl =
          cond do
            is_function(ttl) -> ttl.(result)
            :else -> ttl
          end

        expiration = :os.system_time(:seconds) + cttl
        :ets.insert(:schema_cache, {schema, result, expiration})
        {:ok, result}

      {:error, _} = error ->
        error
    end
  end
end
