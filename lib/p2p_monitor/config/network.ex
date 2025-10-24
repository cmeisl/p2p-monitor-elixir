defmodule P2PMonitor.Config.Network do
  @moduledoc """
  Network configuration for Ethereum P2P networks (mainnet, testnet, etc.).

  This module provides configuration for different Ethereum networks including
  genesis hashes, chain IDs, and boot nodes.
  """

  @type network :: :mainnet | :sepolia | :holesky | :goerli

  @type network_config :: %{
    chain_id: non_neg_integer(),
    genesis_hash: binary(),
    boot_nodes: [String.t()],
    network_id: non_neg_integer()
  }

  @doc """
  Returns the configuration for a specific network.

  ## Parameters
    * `network` - The network name (:mainnet, :sepolia, :holesky)

  ## Returns
    * Map with network configuration

  ## Examples

      iex> config = P2PMonitor.Config.Network.get(:mainnet)
      iex> config.chain_id
      1

      iex> config = P2PMonitor.Config.Network.get(:sepolia)
      iex> config.chain_id
      11155111
  """
  @spec get(network()) :: network_config()
  def get(:mainnet) do
    %{
      chain_id: 1,
      network_id: 1,
      genesis_hash: decode_hex("0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3"),
      boot_nodes: [
        # Ethereum Foundation boot nodes
        "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303",
        "enode://22a8232c3abc76a16ae9d6c3b164f98775fe226f0917b0ca871128a74a8e9630b458460865bab457221f1d448dd9791d24c4e5d88786180ac185df813a68d4de@3.209.45.79:30303",
        "enode://2b252ab6a1d0f971d9722cb839a42cb81db019ba44c08754628ab4a823487071b5695317c8ccd085219c3a03af063495b2f1da8d18218da2d6a82981b45e6ffc@65.108.70.101:30303",
        "enode://4aeb4ab6c14b23e2c4cfdce879c04b0748a20d8e9b59e25ded2a08143e265c6c25936e74cbc8e641e3312ca288673d91f2f93f8e277de3cfa444ecdaaf982052@157.90.35.166:30303"
      ]
    }
  end

  def get(:sepolia) do
    %{
      chain_id: 11155111,
      network_id: 11155111,
      genesis_hash: decode_hex("0x25a5cc106eea7138acab33231d7160d69cb777ee0c2c553fcddf5138993e6dd9"),
      boot_nodes: [
        "enode://4e5e92199ee224a01932a377160aa432f31d0b351f84ab413a8e0a42f4f36476f8fb1cbe914af0d9aef0d51665c214cf653c651c4bbd9d5550a934f241f1682b@138.197.51.181:30303",
        "enode://143e11fb766781d22d92a2e33f8f104cddae4411a122295ed1fdb6638de96a6ce65f5b7c964ba3763bba27961738fef7d3ecc739268f3e5e771fb4c87b6234ba@146.190.1.103:30303",
        "enode://8b61dc2d06c3f96fddcbebb0efb29d60d3598650275dc469c22229d3e5620369b0d3dedafd929835fe7f489618f19f456fe7c0df572bf2d914a9f4e006f783a9@170.64.250.88:30303"
      ]
    }
  end

  def get(:holesky) do
    %{
      chain_id: 17000,
      network_id: 17000,
      genesis_hash: decode_hex("0xb5f7f912443c940f21fd611f12828d75b534364ed9e95ca4e307729a4661bde4"),
      boot_nodes: [
        "enode://ac906289e4b7f12df423d654c5a962b6ebe5b3a74cc9e06292a85221f9a64a6f1cfdd6b714ed6dacef51578f92b34c60ee91e9ede9c7f8fadc4d347326d95e2b@146.190.13.128:30303",
        "enode://a3435a0155a3e837c02f5e7f5662a2f1fbc25b48e4dc232016e1c51b544cb5b4510ef633ea3278c0e970fa8ad8141e2d4d0f9f95456c537ff05fdf9b31c15072@178.128.136.233:30303"
      ]
    }
  end

  def get(:goerli) do
    %{
      chain_id: 5,
      network_id: 5,
      genesis_hash: decode_hex("0xbf7e331f7f7c1dd2e05159666b3bf8bc7a8a3a9eb1d518969eab529dd9b88c1a"),
      boot_nodes: [
        "enode://011f758e6552d105183b1761c5e2dea0111bc20fd5f6422bc7f91e0fabbec9a6595caf6239b37feb773dddd3f87240d99d859431891e4a642cf2a0a9e6cbb98a@51.141.78.53:30303",
        "enode://176b9417f511d05b6b2cf3e34b756cf0a7096b3094572a8f6ef4cdcb9d1f9d00683bf0f83347eebdf3b81c3521c2332086d9592802230bf528eaf606a1d9677b@13.93.54.137:30303"
      ]
    }
  end

  @doc """
  Returns the currently configured network from application config.

  Defaults to :mainnet if not configured.

  ## Examples

      iex> network = P2PMonitor.Config.Network.current()
      iex> P2PMonitor.Config.Network.valid_network?(network)
      true
  """
  @spec current() :: network()
  def current do
    Application.get_env(:p2p_monitor, :network, :mainnet)
  end

  @doc """
  Returns the configuration for the currently configured network.

  ## Examples

      iex> config = P2PMonitor.Config.Network.current_config()
      iex> is_map(config)
      true
  """
  @spec current_config() :: network_config()
  def current_config do
    get(current())
  end

  @doc """
  Returns the chain ID for a specific network.

  ## Examples

      iex> P2PMonitor.Config.Network.chain_id(:mainnet)
      1

      iex> P2PMonitor.Config.Network.chain_id(:sepolia)
      11155111
  """
  @spec chain_id(network()) :: non_neg_integer()
  def chain_id(network) do
    get(network).chain_id
  end

  @doc """
  Returns the boot nodes for a specific network.

  ## Examples

      iex> nodes = P2PMonitor.Config.Network.boot_nodes(:mainnet)
      iex> is_list(nodes)
      true
      iex> length(nodes) > 0
      true
  """
  @spec boot_nodes(network()) :: [String.t()]
  def boot_nodes(network) do
    get(network).boot_nodes
  end

  @doc """
  Validates a network name.

  ## Examples

      iex> P2PMonitor.Config.Network.valid_network?(:mainnet)
      true

      iex> P2PMonitor.Config.Network.valid_network?(:invalid)
      false
  """
  @spec valid_network?(atom()) :: boolean()
  def valid_network?(network) do
    network in [:mainnet, :sepolia, :holesky, :goerli]
  end

  # Private functions

  defp decode_hex("0x" <> hex), do: decode_hex(hex)
  defp decode_hex(hex) do
    Base.decode16!(hex, case: :mixed)
  end
end
