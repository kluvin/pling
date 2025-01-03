defmodule Pling.Services.Spotify do
  @moduledoc """
  Service module for interacting with the Spotify Web API.
  Handles authentication and playlist data retrieval.
  """

  use Tesla

  @spotify_api_base "https://api.spotify.com/v1"

  # Change from module attribute to function
  defp base_middleware do
    [
      {Tesla.Middleware.BaseUrl, @spotify_api_base},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"content-type", "application/json"}]},
      {Tesla.Middleware.Retry,
       delay: 500,
       max_retries: 3,
       max_delay: 4_000,
       should_retry: fn
         {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end}
    ]
  end

  @doc """
  Creates a Tesla client with authentication token and base middleware.

  ## Parameters
    * `token` - Spotify access token for API authentication
  """
  def client(token) do
    IO.inspect(token, label: "Token being used")

    middleware = [
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token}"}]}
      | base_middleware()
    ]

    Tesla.client(middleware)
  end

  @doc """
  Creates an OAuth2 client configured for Spotify authentication.
  Uses client credentials from environment variables.
  """
  def oauth_client do
    IO.puts("hello: #{System.fetch_env!("SPOTIFY_CLIENT_ID")}")

    OAuth2.Client.new(
      strategy: OAuth2.Strategy.ClientCredentials,
      client_id: System.fetch_env!("SPOTIFY_CLIENT_ID"),
      client_secret: System.fetch_env!("SPOTIFY_CLIENT_SECRET"),
      site: "https://accounts.spotify.com",
      token_url: "https://accounts.spotify.com/api/token"
    )
  end

  @doc """
  Retrieves an access token from Spotify using client credentials flow.

  ## Returns
    * `{:ok, token}` - Successfully retrieved access token
    * `{:error, reason}` - Failed to retrieve token
  """
  def get_token do
    oauth_client()
    |> OAuth2.Client.get_token()
    |> extract_token()
  end

  defp extract_token({:ok, client}) do
    client.token.access_token
    |> Jason.decode()
    |> case do
      {:ok, %{"access_token" => access_token}} -> {:ok, access_token}
      _ -> {:error, "Invalid token format"}
    end
  end

  defp extract_token({:error, error}), do: {:error, error}

  @doc """
  Retrieves tracks from a Spotify playlist using the playlist ID.
  Handles authentication automatically.

  ## Parameters
    * `playlist_id` - Spotify playlist ID to fetch tracks from

  ## Returns
    * `{:ok, tracks}` - List of track data including name, artists, album, URI and popularity
    * `{:error, reason}` - Error details if request fails
  """
  def get_playlist_tracks(playlist_id) do
    with {:ok, token} <- get_token() do
      get_playlist_tracks(token, playlist_id)
    end
  end

  @doc """
  Retrieves tracks from a Spotify playlist using an existing access token.

  ## Parameters
    * `access_token` - Valid Spotify access token
    * `playlist_id` - Spotify playlist ID to fetch tracks from

  ## Returns
    * `{:ok, tracks}` - List of track data including name, artists, album, URI and popularity
    * `{:error, reason}` - Error details if request fails
  """
  def get_playlist_tracks(access_token, playlist_id) do
    fields = "items(track(name,uri,popularity,album(name),artists(name))),next"
    query = [fields: fields]

    client(access_token)
    |> get("/playlists/#{playlist_id}/tracks", query: query)
    |> case do
      {:ok, %{status: 200, body: body}} ->
        process_playlist_response(body, access_token)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, error: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_playlist_response(%{"items" => items, "next" => nil}, _access_token) do
    {:ok, extract_tracks(items)}
  end

  defp process_playlist_response(%{"items" => items, "next" => next_url}, access_token)
       when is_binary(next_url) do
    case fetch_next_page(next_url, access_token) do
      {:ok, more_tracks} -> {:ok, extract_tracks(items) ++ more_tracks}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_next_page(next_url, access_token) do
    client(access_token)
    |> get(next_url)
    |> case do
      {:ok, %{status: 200, body: body}} ->
        process_playlist_response(body, access_token)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, error: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_tracks(items) do
    items
    |> Enum.map(fn
      # Can happen depending on track availability.
      %{"track" => nil} ->
        require Logger
        Logger.warning("Found nil track in Spotify playlist response")
        nil

      %{"track" => track} ->
        %{
          name: track["name"],
          artists: Enum.map(track["artists"], & &1["name"]),
          album_name: track["album"]["name"],
          uri: track["uri"],
          popularity: track["popularity"]
        }
    end)
    # Don't continue processing with bad entries.
    |> Enum.reject(&is_nil/1)
  end
end
