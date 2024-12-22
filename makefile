.PHONY: all dev note


dev:
	@mix phx.server


release: 
	@fly deploy

# https://hexdocs.pm/phoenix_analytics/readme.html#installation
init_analytics:
	@iex -S mix PhoenixAnalytics.Migration.up()

note:	
	@osascript sendMessage.applescript +4794092415 "Ny release https://pling.fly.dev/"

clean:
	@mix clean

prod:
	@MIX_ENV=prod mix phx.server
