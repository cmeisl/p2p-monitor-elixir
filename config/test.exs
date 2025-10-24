import Config

# Test configuration

config :p2p_monitor,
  # Use sepolia for testing
  network: :sepolia,
  max_peers: 5,
  target_peers: 2,
  log_level: :warning,
  outputs: []

# Print only warnings and errors during test
config :logger, level: :warning
