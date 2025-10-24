defmodule P2PMonitor.Config.NetworkTest do
  use ExUnit.Case, async: true
  
  alias P2PMonitor.Config.Network

  doctest P2PMonitor.Config.Network

  describe "get/1" do
    test "returns mainnet configuration" do
      config = Network.get(:mainnet)
      
      assert config.chain_id == 1
      assert config.network_id == 1
      assert byte_size(config.genesis_hash) == 32
      assert is_list(config.boot_nodes)
      assert length(config.boot_nodes) > 0
    end

    test "returns sepolia configuration" do
      config = Network.get(:sepolia)
      
      assert config.chain_id == 11155111
      assert config.network_id == 11155111
      assert byte_size(config.genesis_hash) == 32
      assert is_list(config.boot_nodes)
      assert length(config.boot_nodes) > 0
    end

    test "returns holesky configuration" do
      config = Network.get(:holesky)
      
      assert config.chain_id == 17000
      assert config.network_id == 17000
      assert byte_size(config.genesis_hash) == 32
      assert is_list(config.boot_nodes)
      assert length(config.boot_nodes) > 0
    end

    test "returns goerli configuration" do
      config = Network.get(:goerli)
      
      assert config.chain_id == 5
      assert config.network_id == 5
      assert byte_size(config.genesis_hash) == 32
      assert is_list(config.boot_nodes)
      assert length(config.boot_nodes) > 0
    end

    test "all configurations have required fields" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        config = Network.get(network)
        
        assert Map.has_key?(config, :chain_id)
        assert Map.has_key?(config, :network_id)
        assert Map.has_key?(config, :genesis_hash)
        assert Map.has_key?(config, :boot_nodes)
        
        assert is_integer(config.chain_id)
        assert is_integer(config.network_id)
        assert is_binary(config.genesis_hash)
        assert is_list(config.boot_nodes)
      end)
    end

    test "genesis hashes are 32 bytes" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        config = Network.get(network)
        assert byte_size(config.genesis_hash) == 32
      end)
    end

    test "mainnet has correct genesis hash" do
      config = Network.get(:mainnet)
      
      # Known mainnet genesis hash
      expected = Base.decode16!(
        "d4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
        case: :lower
      )
      
      assert config.genesis_hash == expected
    end

    test "chain_id matches network_id for all networks" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        config = Network.get(network)
        assert config.chain_id == config.network_id
      end)
    end
  end

  describe "boot_nodes/1" do
    test "returns list of boot nodes for mainnet" do
      nodes = Network.boot_nodes(:mainnet)
      
      assert is_list(nodes)
      assert length(nodes) > 0
      
      # All boot nodes should be enode URLs
      Enum.each(nodes, fn node ->
        assert String.starts_with?(node, "enode://")
        assert String.contains?(node, "@")
        assert String.contains?(node, ":")
      end)
    end

    test "returns list of boot nodes for sepolia" do
      nodes = Network.boot_nodes(:sepolia)
      
      assert is_list(nodes)
      assert length(nodes) > 0
      
      Enum.each(nodes, fn node ->
        assert String.starts_with?(node, "enode://")
      end)
    end

    test "boot nodes have valid format" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        nodes = Network.boot_nodes(network)
        
        Enum.each(nodes, fn node ->
          # enode://[node_id]@[ip]:[port]
          assert String.starts_with?(node, "enode://")
          
          # Extract parts
          [_protocol, rest] = String.split(node, "://", parts: 2)
          assert String.contains?(rest, "@")
          
          [node_id, address] = String.split(rest, "@", parts: 2)
          
          # Node ID should be 128 hex characters (64 bytes)
          assert String.length(node_id) == 128
          assert String.match?(node_id, ~r/^[0-9a-f]+$/i)
          
          # Address should have IP and port
          assert String.contains?(address, ":")
        end)
      end)
    end

    test "mainnet has multiple boot nodes" do
      nodes = Network.boot_nodes(:mainnet)
      
      # Should have at least 2 boot nodes for redundancy
      assert length(nodes) >= 2
    end

    test "each network has unique boot nodes" do
      mainnet_nodes = Network.boot_nodes(:mainnet)
      sepolia_nodes = Network.boot_nodes(:sepolia)
      holesky_nodes = Network.boot_nodes(:holesky)
      
      # Networks should not share boot nodes
      refute Enum.any?(mainnet_nodes, fn node -> node in sepolia_nodes end)
      refute Enum.any?(mainnet_nodes, fn node -> node in holesky_nodes end)
      refute Enum.any?(sepolia_nodes, fn node -> node in holesky_nodes end)
    end
  end

  describe "chain_id/1" do
    test "returns correct chain ID for mainnet" do
      assert Network.chain_id(:mainnet) == 1
    end

    test "returns correct chain ID for sepolia" do
      assert Network.chain_id(:sepolia) == 11155111
    end

    test "returns correct chain ID for holesky" do
      assert Network.chain_id(:holesky) == 17000
    end

    test "returns correct chain ID for goerli" do
      assert Network.chain_id(:goerli) == 5
    end

    test "each network has unique chain ID" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      chain_ids = Enum.map(networks, &Network.chain_id/1)
      
      assert length(Enum.uniq(chain_ids)) == length(chain_ids)
    end

    test "chain IDs are positive integers" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        chain_id = Network.chain_id(network)
        assert is_integer(chain_id)
        assert chain_id > 0
      end)
    end
  end

  describe "valid_network?/1" do
    test "validates mainnet" do
      assert Network.valid_network?(:mainnet)
    end

    test "validates sepolia" do
      assert Network.valid_network?(:sepolia)
    end

    test "validates holesky" do
      assert Network.valid_network?(:holesky)
    end

    test "validates goerli" do
      assert Network.valid_network?(:goerli)
    end

    test "rejects invalid network names" do
      invalid_networks = [:invalid, :testnet, :ropsten, :kovan, :rinkeby, :unknown]
      
      Enum.each(invalid_networks, fn network ->
        refute Network.valid_network?(network)
      end)
    end

    test "rejects non-atom inputs" do
      refute Network.valid_network?("mainnet")
      refute Network.valid_network?(1)
      refute Network.valid_network?(nil)
    end

    test "all supported networks are valid" do
      supported_networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(supported_networks, fn network ->
        assert Network.valid_network?(network)
      end)
    end
  end

  describe "current/0" do
    test "returns configured network or defaults to mainnet" do
      network = Network.current()
      
      assert is_atom(network)
      assert Network.valid_network?(network)
    end

    test "returned network is valid" do
      network = Network.current()
      assert Network.valid_network?(network)
    end
  end

  describe "current_config/0" do
    test "returns configuration for current network" do
      config = Network.current_config()
      
      assert is_map(config)
      assert Map.has_key?(config, :chain_id)
      assert Map.has_key?(config, :network_id)
      assert Map.has_key?(config, :genesis_hash)
      assert Map.has_key?(config, :boot_nodes)
    end

    test "current_config matches get(current())" do
      current_network = Network.current()
      
      config1 = Network.current_config()
      config2 = Network.get(current_network)
      
      assert config1 == config2
    end
  end

  describe "configuration consistency" do
    test "all networks have non-empty boot node lists" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        config = Network.get(network)
        assert length(config.boot_nodes) > 0
      end)
    end

    test "all genesis hashes are unique" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      genesis_hashes = Enum.map(networks, fn network ->
        Network.get(network).genesis_hash
      end)
      
      assert length(Enum.uniq(genesis_hashes)) == length(genesis_hashes)
    end

    test "configuration maps have same structure" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      configs = Enum.map(networks, &Network.get/1)
      keys_lists = Enum.map(configs, &Map.keys/1)
      
      # All configs should have the same keys
      first_keys = hd(keys_lists)
      Enum.each(keys_lists, fn keys ->
        assert Enum.sort(keys) == Enum.sort(first_keys)
      end)
    end

    test "boot nodes contain valid IP addresses or hostnames" do
      networks = [:mainnet, :sepolia, :holesky, :goerli]
      
      Enum.each(networks, fn network ->
        nodes = Network.boot_nodes(network)
        
        Enum.each(nodes, fn node ->
          # Extract IP/hostname from enode URL
          [_protocol, rest] = String.split(node, "://", parts: 2)
          [_node_id, address] = String.split(rest, "@", parts: 2)
          [ip_or_host, port_str] = String.split(address, ":", parts: 2)
          
          # Port should be a valid integer
          {port, ""} = Integer.parse(port_str)
          assert port > 0 and port <= 65535
          
          # Should have some valid format (either IP or hostname)
          assert byte_size(ip_or_host) > 0
        end)
      end)
    end
  end

  describe "network identification" do
    test "mainnet is identified by chain ID 1" do
      assert Network.get(:mainnet).chain_id == 1
    end

    test "can identify network by chain ID" do
      # Map of chain IDs to networks
      chain_id_map = %{
        1 => :mainnet,
        5 => :goerli,
        17000 => :holesky,
        11155111 => :sepolia
      }
      
      Enum.each(chain_id_map, fn {chain_id, network} ->
        config = Network.get(network)
        assert config.chain_id == chain_id
      end)
    end

    test "testnets have different chain IDs from mainnet" do
      mainnet_chain_id = Network.chain_id(:mainnet)
      testnet_chain_ids = [
        Network.chain_id(:sepolia),
        Network.chain_id(:holesky),
        Network.chain_id(:goerli)
      ]
      
      Enum.each(testnet_chain_ids, fn chain_id ->
        assert chain_id != mainnet_chain_id
      end)
    end
  end
end
