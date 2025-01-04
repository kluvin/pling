defmodule Pling.Services.Spotify do
  require Logger

  @base_url "https://playlist-fetcher-1031294514094.europe-north1.run.app"
  @api_key "1367a6ef2cb6f3cd2bfb3f73978292fdae3bc9a5e885ca7632d4eb3fc15eb4d4"

  def stream_playlist(playlist_id, callback) when is_function(callback, 1) do
    Logger.info("Starting playlist stream", playlist_id: playlist_id)

    req =
      Req.new(
        base_url: @base_url,
        headers: [{"x-api-key", @api_key}]
      )

    case Req.get(req,
           url: "/playlist/#{playlist_id}",
           params: [stream: true],
           into: fn {:data, data}, {req, resp} ->
             String.split(data, "\n", trim: true)
             |> Enum.each(fn line ->
               case Jason.decode(line) do
                 {:ok, decoded} ->
                   Logger.debug("Processing playlist item",
                     playlist_id: playlist_id,
                     track_id: decoded["id"]
                   )

                   callback.(decoded)

                 {:error, error} ->
                   Logger.error("Failed to decode chunk",
                     playlist_id: playlist_id,
                     error: inspect(error),
                     chunk: line
                   )
               end
             end)

             {:cont, {req, resp}}
           end
         ) do
      {:ok, _response} ->
        Logger.info("Completed playlist stream", playlist_id: playlist_id)
        :ok

      {:error, error} ->
        Logger.error("Failed to stream playlist",
          playlist_id: playlist_id,
          error: inspect(error)
        )

        {:error, error}
    end
  end
end
