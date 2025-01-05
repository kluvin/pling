defmodule Pling.Services.Spotify do
  require Logger
  alias Pling.Services.NDJsonStream

  @base_url "https://playlist-fetcher-1031294514094.europe-north1.run.app"
  @api_key "1367a6ef2cb6f3cd2bfb3f73978292fdae3bc9a5e885ca7632d4eb3fc15eb4d4"

  def stream_playlist(playlist_id, callback) when is_function(callback, 1) do
    Logger.info("Starting playlist stream", playlist_id: playlist_id)

    req =
      Req.new(
        base_url: @base_url,
        headers: [{"x-api-key", @api_key}]
      )

    stream_fn = NDJsonStream.stream_fn(callback)
    buffer = ""

    try do
      Req.get!(req,
        url: "/playlist/#{playlist_id}",
        params: [stream: true],
        into: fn
          {:data, data}, {req, resp} ->
            {_, new_buffer} = stream_fn.({:data, data}, buffer)
            {:cont, {req, resp}}

          {:done, data}, {req, resp} ->
            stream_fn.({:done, data}, buffer)
            {:cont, {req, resp}}

          _, state ->
            {:cont, state}
        end
      )

      Logger.info("Completed playlist stream", playlist_id: playlist_id)
      :ok
    catch
      kind, error ->
        Logger.error("Failed to stream playlist",
          playlist_id: playlist_id,
          error: Exception.format(kind, error, __STACKTRACE__)
        )

        {:error, error}
    end
  end
end
