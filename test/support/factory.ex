defmodule P2PMonitor.Factory do
  @moduledoc """
  Factory module for generating test data.
  Provides functions to create various Ethereum-related data structures for testing.
  """

  import P2PMonitor.TestHelper

  @doc """
  Creates a test transaction with optional attributes.
  """
  @spec build_transaction(keyword()) :: map()
  def build_transaction(attrs \\ []) do
    defaults = %{
      hash: random_hash(),
      from: random_address(),
      to: random_address(),
      value: Enum.random(0..1_000_000_000_000_000_000),
      gas_limit: 21_000,
      gas_price: 20_000_000_000,
      nonce: Enum.random(0..1000),
      data: <<>>,
      type: :legacy,
      v: 27,
      r: Enum.random(1..1_000_000),
      s: Enum.random(1..1_000_000)
    }

    Map.merge(defaults, Enum.into(attrs, %{}))
  end

  @doc """
  Creates a legacy transaction for testing.
  """
  @spec build_legacy_transaction(keyword()) :: map()
  def build_legacy_transaction(attrs \\ []) do
    attrs
    |> Keyword.put(:type, :legacy)
    |> build_transaction()
  end

  @doc """
  Creates an EIP-1559 transaction for testing.
  """
  @spec build_eip1559_transaction(keyword()) :: map()
  def build_eip1559_transaction(attrs \\ []) do
    base = build_transaction(attrs)
    
    eip1559_fields = %{
      type: :eip1559,
      chain_id: Keyword.get(attrs, :chain_id, 1),
      max_fee_per_gas: Keyword.get(attrs, :max_fee_per_gas, 30_000_000_000),
      max_priority_fee_per_gas: Keyword.get(attrs, :max_priority_fee_per_gas, 2_000_000_000),
      access_list: Keyword.get(attrs, :access_list, [])
    }
    
    base
    |> Map.delete(:gas_price)
    |> Map.merge(eip1559_fields)
  end

  @doc """
  Creates an EIP-2930 transaction for testing.
  """
  @spec build_eip2930_transaction(keyword()) :: map()
  def build_eip2930_transaction(attrs \\ []) do
    base = build_transaction(attrs)
    
    eip2930_fields = %{
      type: :eip2930,
      chain_id: Keyword.get(attrs, :chain_id, 1),
      access_list: Keyword.get(attrs, :access_list, [])
    }
    
    Map.merge(base, eip2930_fields)
  end

  @doc """
  Creates a peer structure for testing.
  """
  @spec build_peer(keyword()) :: map()
  def build_peer(attrs \\ []) do
    defaults = %{
      id: random_binary(64),
      ip: {Enum.random(1..255), Enum.random(1..255), Enum.random(1..255), Enum.random(1..255)},
      tcp_port: Keyword.get(attrs, :tcp_port, 30303),
      udp_port: Keyword.get(attrs, :udp_port, 30303),
      status: :connected,
      last_seen: DateTime.utc_now()
    }

    Map.merge(defaults, Enum.into(attrs, %{}))
  end

  @doc """
  Builds a sequence of transactions with incrementing nonces.
  """
  @spec build_transaction_sequence(non_neg_integer(), keyword()) :: [map()]
  def build_transaction_sequence(count, base_attrs \\ []) do
    from_address = Keyword.get(base_attrs, :from, random_address())
    
    Enum.map(0..(count - 1), fn i ->
      base_attrs
      |> Keyword.put(:from, from_address)
      |> Keyword.put(:nonce, i)
      |> build_transaction()
    end)
  end

  @doc """
  Generates a known valid signature for testing signature recovery.
  
  Returns a tuple of {message_hash, signature, expected_address}.
  """
  @spec build_valid_signature() :: {binary(), map(), binary()}
  def build_valid_signature do
    private_key = generate_valid_private_key()
    public_key = private_key_to_public_key(private_key)
    expected_address = P2PMonitor.Crypto.Keccak.public_key_to_address(public_key)
    
    message_hash = random_hash()
    {:ok, signature} = P2PMonitor.Crypto.Signature.sign(message_hash, private_key)
    
    {message_hash, signature, expected_address}
  end

  @doc """
  Generates known test data for Keccak hashing.
  
  Returns a list of tuples with {input, expected_hash}.
  These are verified Keccak-256 hashes (not SHA3-256).
  """
  @spec known_keccak_test_vectors() :: [{String.t(), binary()}]
  def known_keccak_test_vectors do
    [
      # Empty string
      {"", 
       <<0xC5, 0xD2, 0x46, 0x01, 0x86, 0xF7, 0x23, 0x3C, 
         0x92, 0x7E, 0x7D, 0xB2, 0xDC, 0xC7, 0x03, 0xC0,
         0xE5, 0x00, 0xB6, 0x53, 0xCA, 0x82, 0x27, 0x3B,
         0x7B, 0xFA, 0xD8, 0x04, 0x5D, 0x85, 0xA4, 0x70>>},
      # "hello"
      {"hello",
       <<0x1C, 0x8A, 0xFF, 0x95, 0x06, 0x85, 0xC2, 0xED,
         0x4B, 0xC3, 0x17, 0x4F, 0x34, 0x72, 0x28, 0x7B,
         0x56, 0xD9, 0x51, 0x7B, 0x9C, 0x94, 0x81, 0x27,
         0x31, 0x9A, 0x09, 0xA7, 0xA3, 0x6D, 0xEA, 0xC8>>},
      # "test"
      {"test",
       <<0x9C, 0x22, 0xFF, 0x5F, 0x21, 0xF0, 0xB8, 0x1B,
         0x11, 0x3E, 0x63, 0xF7, 0xDB, 0x6D, 0xA9, 0x4F,
         0xED, 0xEF, 0x11, 0xB2, 0x11, 0x9B, 0x40, 0x88,
         0xB8, 0x96, 0x64, 0xFB, 0x9A, 0x3C, 0xB6, 0x58>>}
    ]
  end

  @doc """
  Generates known RLP encoding test vectors.
  
  Returns a list of tuples with {input, expected_rlp}.
  """
  @spec known_rlp_test_vectors() :: [{any(), binary()}]
  def known_rlp_test_vectors do
    [
      # Empty string
      {"", <<0x80>>},
      # Single byte < 0x80
      {<<0x00>>, <<0x00>>},
      {<<0x7F>>, <<0x7F>>},
      # Short string
      {"dog", <<0x83, 0x64, 0x6F, 0x67>>},
      # Empty list
      {[], <<0xC0>>},
      # List with strings
      {["cat", "dog"], <<0xC8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6F, 0x67>>},
      # Integer 0
      {0, <<0x80>>},
      # Integer 1
      {1, <<0x01>>},
      # Integer 127
      {127, <<0x7F>>},
      # Integer 128
      {128, <<0x81, 0x80>>},
      # Integer 1000
      {1000, <<0x82, 0x03, 0xE8>>}
    ]
  end

  @doc """
  Creates a minimal valid transaction for RLP encoding.
  """
  @spec build_minimal_transaction() :: map()
  def build_minimal_transaction do
    %{
      nonce: 0,
      gas_price: 1,
      gas_limit: 21000,
      to: <<>>,
      value: 0,
      data: <<>>,
      type: :legacy
    }
  end

  @doc """
  Creates network boot node configurations for testing.
  """
  @spec build_boot_node(keyword()) :: String.t()
  def build_boot_node(attrs \\ []) do
    node_id = Keyword.get(attrs, :node_id, Base.encode16(random_binary(64), case: :lower))
    ip = Keyword.get(attrs, :ip, "192.168.1.1")
    port = Keyword.get(attrs, :port, 30303)
    
    "enode://#{node_id}@#{ip}:#{port}"
  end
end
