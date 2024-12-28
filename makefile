.PHONY: all dev note


dev:
	@mix phx.server


release: 
	@fly deploy

# https://hexdocs.pm/phoenix_analytics/readme.html#installation
init_analytics:
	@iex -S mix PhoenixAnalytics.Migration.up()

clean:
	@mix clean
	@rm analytics.db
	@rm analytics.db.wal

prod:
	@MIX_ENV=prod mix phx.server

seed:
	@mix run priv/repo/seeds.exs

reset_db:
	@mix ecto.reset

# ops commands for prod. should be automated.
# some of this toruble is due to db lock conflicts with duckdb
prod_seed:
	fly ssh console
	/app/bin/pling eval "Application.ensure_all_started(:pling); Code.eval_file(\"/app/lib/pling-0.1.0/priv/repo/seeds.exs\")"

prod_migrate:
	fly ssh console
	/app/bin/pling remote
	Pling.Release.migrate()