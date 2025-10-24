defmodule P2PMonitor.Integration.EthereumDataTest do
  @moduledoc """
  Integration tests using real transaction data from Ethereum networks.
  
  These tests are tagged with :integration and can be run separately:
  
      mix test --only integration
  
  To skip integration tests during normal test runs:
  
      mix test --exclude integration
  
  ## Requirements
  
  - Internet connection
  - Optional: ETHERSCAN_API_KEY environment variable for higher rate limits
  
  ## Test Data Sources
  
  These tests use known, verified transactions from Ethereum mainnet and testnets:
  - Legacy transactions (Type 0)
  - EIP-2930 transactions (Type 1)
  - EIP-1559 transactions (Type 2)
  - EIP-4844 blob transactions (Type 3)
  """
  
  use ExUnit.Case, async: false
  
  alias P2PMonitor.RLP.{Encoder, Decoder}
  
  @moduletag :integration
  
  describe "Legacy transactions (Type 0)" do
    @tag timeout: 30_000
    test "decodes real legacy transaction from mainnet" do
      alias P2PMonitor.Test.EthereumClient
      
      # Real legacy transaction from mainnet
      # https://etherscan.io/tx/0x78215a54ee1713c1232247b55dccb86c7e64fdba7d5875668a8237e4c28efb0c
      tx_hash = "0x78215a54ee1713c1232247b55dccb86c7e64fdba7d5875668a8237e4c28efb0c"
      
      # Fetch raw transaction data
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      assert is_binary(raw_tx)
      assert byte_size(raw_tx) > 0
      
      # Decode the transaction
      assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
      
      # Verify it's a legacy transaction
      assert decoded.type == :legacy
      
      # Legacy transaction fields
      assert is_integer(decoded.nonce)
      assert is_integer(decoded.gas_price)
      assert decoded.gas_price > 0
      assert is_integer(decoded.gas_limit)
      assert decoded.gas_limit > 0
      assert is_binary(decoded.to)
      assert is_integer(decoded.value)
      assert is_binary(decoded.data)
      
      # Should have signature
      assert is_integer(decoded.v)
      assert is_integer(decoded.r)
      assert is_integer(decoded.s)
      
      # Test round-trip encoding
      encoded = Encoder.encode_transaction(decoded)
      assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
      assert decoded == decoded_again
    end
  end
  
  describe "EIP-1559 transactions (Type 2)" do
    @tag timeout: 30_000
    test "decodes real EIP-1559 transaction from mainnet" do
      alias P2PMonitor.Test.EthereumClient
      
      # Real EIP-1559 transaction from mainnet
      # https://etherscan.io/tx/0x04d6b9ff55c9e7d373332bc595b83ce4be7fbe76eb1cd6ef8c8d0056de2f2117
      tx_hash = "0x04d6b9ff55c9e7d373332bc595b83ce4be7fbe76eb1cd6ef8c8d0056de2f2117"
      
      # Fetch raw transaction data
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      assert is_binary(raw_tx)
      assert byte_size(raw_tx) > 0
      
      # Decode the transaction
      assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
      
      # Verify it's an EIP-1559 transaction
      assert decoded.type == :eip1559
      
      # EIP-1559 specific fields
      assert is_integer(decoded.max_fee_per_gas)
      assert decoded.max_fee_per_gas > 0
      assert is_integer(decoded.max_priority_fee_per_gas)
      assert decoded.max_priority_fee_per_gas > 0
      
      # Common transaction fields
      assert is_integer(decoded.nonce)
      assert is_integer(decoded.gas_limit)
      assert decoded.gas_limit > 0
      assert is_binary(decoded.to)
      assert is_integer(decoded.value)
      assert is_binary(decoded.data)
      assert is_list(decoded.access_list)
      
      # Should have signature
      assert is_integer(decoded.v)
      assert is_integer(decoded.r)
      assert is_integer(decoded.s)
      
      # Test round-trip encoding
      encoded = Encoder.encode_transaction(decoded)
      assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
      assert decoded == decoded_again
    end
  end
  
  describe "EIP-2930 transactions (Type 1)" do
    @tag timeout: 30_000
    test "decodes real EIP-2930 transaction with access list" do
      alias P2PMonitor.Test.EthereumClient
      
      # Real EIP-2930 transaction from mainnet
      # https://etherscan.io/tx/0x16590f666db4774546818fe71c2b6566042088eba5ac0979de184e5ee8999f4b
      tx_hash = "0x16590f666db4774546818fe71c2b6566042088eba5ac0979de184e5ee8999f4b"
      
      # Fetch raw transaction data
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      assert is_binary(raw_tx)
      assert byte_size(raw_tx) > 0
      
      # Decode the transaction
      assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
      
      # Verify it's an EIP-2930 transaction
      assert decoded.type == :eip2930
      
      # EIP-2930 specific fields
      assert is_integer(decoded.chain_id)
      assert is_integer(decoded.gas_price)
      assert decoded.gas_price > 0
      assert is_list(decoded.access_list)
      
      # Common transaction fields
      assert is_integer(decoded.nonce)
      assert is_integer(decoded.gas_limit)
      assert decoded.gas_limit > 0
      assert is_binary(decoded.to)
      assert is_integer(decoded.value)
      assert is_binary(decoded.data)
      
      # Should have signature
      assert is_integer(decoded.v)
      assert is_integer(decoded.r)
      assert is_integer(decoded.s)
      
      # Test round-trip encoding
      encoded = Encoder.encode_transaction(decoded)
      assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
      assert decoded == decoded_again
    end
  end
  
  describe "EIP-4844 blob transactions (Type 3)" do
    @tag timeout: 30_000
    test "decodes real EIP-4844 blob transaction" do
      alias P2PMonitor.Test.EthereumClient
      
      # Real EIP-4844 blob transaction from mainnet
      # https://etherscan.io/tx/0xf71e343019f2371cdbe58fceff6beb6ce7c69b4be17ebc0be61ac68c2ff2f85a
      # EIP-4844 was activated in Dencun upgrade (March 2024)
      tx_hash = "0xf71e343019f2371cdbe58fceff6beb6ce7c69b4be17ebc0be61ac68c2ff2f85a"
      
      # Fetch raw transaction data
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      assert is_binary(raw_tx)
      assert byte_size(raw_tx) > 0
      
      # Decode the transaction
      assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
      
      # Verify it's an EIP-4844 transaction
      assert decoded.type == :eip4844
      
      # EIP-4844 specific fields
      assert is_integer(decoded.max_fee_per_gas)
      assert decoded.max_fee_per_gas > 0
      assert is_integer(decoded.max_priority_fee_per_gas)
      assert decoded.max_priority_fee_per_gas > 0
      assert is_integer(decoded.max_fee_per_blob_gas)
      assert decoded.max_fee_per_blob_gas > 0
      assert is_list(decoded.blob_versioned_hashes)
      assert length(decoded.blob_versioned_hashes) > 0
      
      # Common transaction fields
      assert is_integer(decoded.nonce)
      assert is_integer(decoded.gas_limit)
      assert decoded.gas_limit > 0
      assert is_binary(decoded.to)
      assert is_integer(decoded.value)
      assert is_binary(decoded.data)
      assert is_list(decoded.access_list)
      
      # Should have signature
      assert is_integer(decoded.v)
      assert is_integer(decoded.r)
      assert is_integer(decoded.s)
      
      # Test round-trip encoding
      encoded = Encoder.encode_transaction(decoded)
      assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
      assert decoded == decoded_again
    end
  end
  
  describe "EIP-7702 set code transactions (Type 4)" do
    @tag timeout: 30_000
    test "decodes real EIP-7702 set code transaction from mainnet" do
      alias P2PMonitor.Test.EthereumClient
      
      # Real EIP-7702 transaction from mainnet
      # https://etherscan.io/tx/0x0ad658fb90233553a9100b58a0e3f73b80dac504e2246f8ba5c569de499eb9ec
      # EIP-7702 was activated in Pectra upgrade (May 2025)
      tx_hash = "0x0ad658fb90233553a9100b58a0e3f73b80dac504e2246f8ba5c569de499eb9ec"
      
      # Fetch raw transaction data
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      assert is_binary(raw_tx)
      assert byte_size(raw_tx) > 0
      
      # Decode the transaction
      assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
      
      # Verify it's an EIP-7702 transaction
      assert decoded.type == :eip7702
      
      # EIP-7702 specific fields
      assert is_integer(decoded.max_fee_per_gas)
      assert decoded.max_fee_per_gas > 0
      assert is_integer(decoded.max_priority_fee_per_gas)
      assert decoded.max_priority_fee_per_gas > 0
      assert is_list(decoded.authorization_list)
      assert length(decoded.authorization_list) > 0
      
      # Check authorization structure
      [auth | _] = decoded.authorization_list
      assert is_integer(auth.chain_id)
      assert is_binary(auth.address)
      assert is_list(auth.nonce)
      assert is_integer(auth.y_parity)
      assert is_integer(auth.r)
      assert is_integer(auth.s)
      
      # Common transaction fields
      assert is_integer(decoded.nonce)
      assert is_integer(decoded.gas_limit)
      assert decoded.gas_limit > 0
      assert is_binary(decoded.to)
      assert is_integer(decoded.value)
      assert is_binary(decoded.data)
      assert is_list(decoded.access_list)
      
      # Should have signature (using y_parity instead of v)
      assert is_integer(decoded.signature_y_parity)
      assert is_integer(decoded.signature_r)
      assert is_integer(decoded.signature_s)
      
      # Test round-trip encoding
      encoded = Encoder.encode_transaction(decoded)
      assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
      assert decoded == decoded_again
    end
  end
  
  describe "Round-trip encoding/decoding" do
    @tag timeout: 30_000
    test "encodes and decodes maintain data integrity" do
      alias P2PMonitor.Test.EthereumClient
      
      # This test verifies that we can:
      # 1. Fetch a real transaction
      # 2. Decode it
      # 3. Re-encode it
      # 4. Decode it again
      # 5. Verify both decoded versions match
      
      # Use the same EIP-1559 transaction from earlier
      # https://etherscan.io/tx/0x04d6b9ff55c9e7d373332bc595b83ce4be7fbe76eb1cd6ef8c8d0056de2f2117
      tx_hash = "0x04d6b9ff55c9e7d373332bc595b83ce4be7fbe76eb1cd6ef8c8d0056de2f2117"
      
      # Fetch raw transaction from network
      assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
      IO.puts("  ℹ RLP source: #{source}")
      
      # First decode
      assert {:ok, decoded1} = Decoder.decode_transaction(raw_tx)
      
      # Re-encode
      encoded = Encoder.encode_transaction(decoded1)
      
      # Second decode
      assert {:ok, decoded2} = Decoder.decode_transaction(encoded)
      
      # Both decoded versions should match exactly
      assert decoded1 == decoded2
      
      # Verify the encoded version can also round-trip
      encoded_again = Encoder.encode_transaction(decoded2)
      assert encoded == encoded_again
    end
  end
end
