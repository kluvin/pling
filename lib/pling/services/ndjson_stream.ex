defmodule Pling.Services.NDJsonStream do
  @moduledoc """
  Handles streaming of newline-delimited JSON (NDJSON) data, processing complete objects
  as they arrive and handling partial chunks internally.
  """
  require Logger

  @doc """
  Creates a streaming function that processes NDJSON data and calls the callback
  for each complete JSON object.

  The function handles:
  - Complete JSON objects
  - Multiple objects in one chunk
  - Partial objects across chunks
  - Invalid JSON gracefully
  - Final buffer processing
  """
  def stream_fn(callback) when is_function(callback, 1) do
    fn
      {:data, data}, buffer ->
        process_chunk(buffer <> data, false, callback)

      {:done, data}, buffer ->
        process_chunk(buffer <> (data || ""), true, callback)

      _, buffer ->
        {:cont, buffer}
    end
  end

  defp process_chunk(data, is_final?, callback) do
    parts = String.split(data, "\n")

    case {parts, is_final?} do
      {[], _} -> {:cont, ""}
      {[single], true} -> process_json(single, callback) && {:cont, ""}
      {parts, true} -> process_all_parts(parts, callback) && {:cont, ""}
      {parts, false} -> process_parts(parts, callback)
    end
  end

  defp process_all_parts(parts, callback) do
    Enum.each(parts, &process_json(&1, callback))
  end

  defp process_parts([partial], _callback), do: {:cont, partial}

  defp process_parts(parts, callback) do
    [last | rest] = Enum.reverse(parts)

    rest
    |> Enum.reverse()
    |> Enum.each(&process_json(&1, callback))

    {:cont, last}
  end

  defp process_json("", _callback), do: :ok

  defp process_json(line, callback) do
    case Jason.decode(line) do
      {:ok, decoded} ->
        callback.(decoded)

      {:error, error} ->
        Logger.warning(
          "Failed to decode JSON line: #{inspect(error)}\nLine content: #{inspect(line)}"
        )
    end
  end
end
