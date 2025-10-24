import Config

# Development configuration

config :p2p_monitor,
  # Use testnet for development
  network: :sepolia,
  max_peers: 10,
  target_peers: 5,
  log_level: :debug

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
