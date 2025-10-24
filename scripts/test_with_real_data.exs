#!/usr/bin/env elixir

# Quick script to test RLP encoding/decoding with real Ethereum data
# Usage: mix run scripts/test_with_real_data.exs

Code.require_file("test/support/ethereum_client.ex")

alias P2PMonitor.Test.EthereumClient
alias P2PMonitor.RLP.{Encoder, Decoder}

IO.puts("\n=== Testing P2P Monitor with Real Ethereum Data ===\n")

# Example transaction hashes for different types
examples = [
  %{
    name: "Legacy Transaction (Type 0)",
    hash: "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
    network: :mainnet,
    expected_type: :legacy
  }
  # Add more examples as you find them
]

Enum.each(examples, fn example ->
  IO.puts("Testing: #{example.name}")
  IO.puts("Hash: #{example.hash}")
  IO.puts("Network: #{example.network}")
  
  case EthereumClient.get_raw_transaction(example.hash, example.network) do
    {:ok, raw_tx} ->
      IO.puts("✓ Fetched raw transaction (#{byte_size(raw_tx)} bytes)")
      
      case Decoder.decode_transaction(raw_tx) do
        {:ok, decoded} ->
          IO.puts("✓ Decoded successfully")
          IO.puts("  Type: #{decoded.type}")
          IO.puts("  Nonce: #{decoded.nonce}")
          
          if decoded.type == example.expected_type do
            IO.puts("✓ Type matches expected: #{example.expected_type}")
          else
            IO.puts("✗ Type mismatch! Expected #{example.expected_type}, got #{decoded.type}")
          end
          
          # Test round-trip
          encoded = Encoder.encode_transaction(decoded)
          case Decoder.decode_transaction(encoded) do
            {:ok, decoded_again} ->
              if decoded == decoded_again do
                IO.puts("✓ Round-trip encoding/decoding successful")
              else
                IO.puts("✗ Round-trip failed - data mismatch")
              end
            {:error, reason} ->
              IO.puts("✗ Round-trip decoding failed: #{inspect(reason)}")
          end
          
        {:error, reason} ->
          IO.puts("✗ Decoding failed: #{inspect(reason)}")
      end
      
    {:error, reason} ->
      IO.puts("✗ Failed to fetch transaction: #{inspect(reason)}")
  end
  
  IO.puts("")
end)

IO.puts("\n=== Checking Latest Block ===\n")

case EthereumClient.get_latest_block(:mainnet) do
  {:ok, block_num} ->
    IO.puts("Latest mainnet block: #{block_num}")
    
    IO.puts("\nFetching transactions from this block...")
    case EthereumClient.get_block_transactions(block_num, :mainnet) do
      {:ok, txs} ->
        IO.puts("Found #{length(txs)} transactions")
        
        # Count transaction types
        type_counts = 
          txs
          |> Enum.map(fn tx -> tx["type"] end)
          |> Enum.frequencies()
          |> Enum.map(fn {type, count} -> 
            type_label = case type do
              "0x0" -> "Legacy (Type 0)"
              "0x1" -> "EIP-2930 (Type 1)"
              "0x2" -> "EIP-1559 (Type 2)"
              "0x3" -> "EIP-4844 (Type 3)"
              _ -> "Unknown"
            end
            "  #{type_label}: #{count}"
          end)
        
        IO.puts("\nTransaction type distribution:")
        Enum.each(type_counts, &IO.puts/1)
        
      {:error, reason} ->
        IO.puts("Failed to fetch block transactions: #{inspect(reason)}")
    end
    
  {:error, reason} ->
    IO.puts("Failed to get latest block: #{inspect(reason)}")
end

IO.puts("\n=== Done ===\n")
IO.puts("To find specific transaction types:")
IO.puts("1. Visit https://etherscan.io")
IO.puts("2. Look for transactions with specific types")
IO.puts("3. Copy the transaction hash")
IO.puts("4. Add it to this script or use it in integration tests")
IO.puts("")
