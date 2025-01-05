defmodule Pling.Services.NDJsonStream do
  @moduledoc """
  Handles streaming of newline-delimited JSON (NDJSON) data, processing complete objects
  as they arrive and handling partial chunks internally.
  """
  require Logger

  @buffer_key :ndjson_buffer

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
    Process.put(@buffer_key, "")

    fn
      {:data, data}, _acc ->
        current_buffer = Process.get(@buffer_key)
        process_chunk(current_buffer <> data, false, callback)

      {:done, data}, _acc ->
        current_buffer = Process.get(@buffer_key)
        result = process_chunk(current_buffer <> (data || ""), true, callback)
        Process.delete(@buffer_key)
        result

      _, _acc ->
        {:cont, Process.get(@buffer_key)}
    end
  end

  defp process_chunk(data, is_final?, callback) do
    parts = String.split(data, "\n")

    case {parts, is_final?} do
      {[], _} ->
        Process.put(@buffer_key, "")
        {:cont, ""}

      {[single], true} ->
        process_json(single, callback)
        Process.put(@buffer_key, "")
        {:cont, ""}

      {parts, true} ->
        process_all_parts(parts, callback)
        Process.put(@buffer_key, "")
        {:cont, ""}

      {parts, false} ->
        result = process_parts(parts, callback)
        Process.put(@buffer_key, elem(result, 1))
        result
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
