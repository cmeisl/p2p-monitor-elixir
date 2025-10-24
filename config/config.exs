import Config

# P2P Monitor Configuration

config :p2p_monitor,
  # Network configuration
  network: :mainnet,
  max_peers: 50,
  target_peers: 25,

  # Transaction filtering
  min_value_wei: 0,
  filter_contracts: false,

  # Peer tracking
  enable_geoip: false,
  geoip_database_path: "priv/GeoLite2-City.mmdb",
  track_propagation: true,
  max_propagations_per_tx: 50,

  # Output
  outputs: [:console],
  log_level: :info,
  console_show_peer_info: true

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config
import_config "#{config_env()}.exs"
