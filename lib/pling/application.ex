defmodule Pling.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PlingWeb.Telemetry,
      Pling.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:pling, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:pling, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pling.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pling.Finch},
      # Start a worker by calling: Pling.Worker.start_link(arg)
      # {Pling.Worker, arg},
      # Start to serve requests, typically the last entry
      PlingWeb.Presence,
      PlingWeb.Endpoint,
      {Registry, keys: :unique, name: Pling.PlingServerRegistry},
      {DynamicSupervisor, name: Pling.RoomSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pling.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlingWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
