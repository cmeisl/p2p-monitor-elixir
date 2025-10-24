# Integration Testing with Real Ethereum Data

This guide explains how to test your P2P Monitor implementation with real transaction data from Ethereum networks.

## Quick Start

### 1. Install Dependencies

```bash
mix deps.get
```

### 2. Run Integration Tests

```bash
# Run only integration tests
mix test --only integration

# Run all tests except integration
mix test --exclude integration
```

### 3. Configure RPC Endpoints (Optional)

For better reliability and rate limits, set your own RPC endpoints:

```bash
# Mainnet
export ETHEREUM_RPC_URL="https://eth.llamarpc.com"

# Or use Infura/Alchemy
export ETHEREUM_RPC_URL="https://mainnet.infura.io/v3/YOUR_PROJECT_ID"

# Sepolia testnet
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_PROJECT_ID"
```

## Using the EthereumClient Helper

### Fetch a Transaction

```elixir
alias P2PMonitor.Test.EthereumClient
alias P2PMonitor.RLP.Decoder

# Fetch raw transaction data
tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
{:ok, raw_tx} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)

# Decode it
{:ok, decoded} = Decoder.decode_transaction(raw_tx)

IO.inspect(decoded)
```

### Find Transactions by Type

```elixir
# Get recent block
{:ok, block_num} = EthereumClient.get_latest_block(:mainnet)

# Get transactions from that block
{:ok, transactions} = EthereumClient.get_block_transactions(block_num, :mainnet)

# Filter by type (type field indicates transaction type)
eip1559_txs = Enum.filter(transactions, fn tx -> tx["type"] == "0x2" end)
blob_txs = Enum.filter(transactions, fn tx -> tx["type"] == "0x3" end)
```

## Example Test Cases

### Testing with Known Transaction Hashes

Here are some real transaction hashes you can use for testing:

#### Legacy Transaction (Type 0)
```elixir
# Early Ethereum transaction
tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
{:ok, raw_tx} = EthereumClient.get_raw_transaction(tx_hash)
{:ok, decoded} = Decoder.decode_transaction(raw_tx)
assert decoded.type == :legacy
```

#### EIP-1559 Transaction (Type 2)
```elixir
# Post-London fork transaction (block > 12,965,000)
# You'll need to find a recent transaction hash from Etherscan
```

#### EIP-4844 Blob Transaction (Type 3)
```elixir
# Post-Dencun upgrade (block > 19,426,587 on mainnet)
# Check recent blocks for blob transactions on Etherscan
```

## Interactive Testing with IEx

You can test interactively in the Elixir shell:

```bash
iex -S mix
```

Then in the IEx session:

```elixir
# Compile and load the test helpers
Code.require_file("test/support/ethereum_client.ex")

alias P2PMonitor.Test.EthereumClient
alias P2PMonitor.RLP.{Encoder, Decoder}

# Fetch latest block
{:ok, block} = EthereumClient.get_latest_block(:mainnet)
IO.puts("Latest block: #{block}")

# Get a transaction
tx_hash = "0x..." # Use a real transaction hash
{:ok, tx_data} = EthereumClient.get_transaction(tx_hash)
IO.inspect(tx_data, label: "Transaction")

# Get raw transaction and decode
{:ok, raw_tx} = EthereumClient.get_raw_transaction(tx_hash)
{:ok, decoded} = Decoder.decode_transaction(raw_tx)
IO.inspect(decoded, label: "Decoded")

# Test round-trip encoding
encoded = Encoder.encode_transaction(decoded)
{:ok, decoded_again} = Decoder.decode_transaction(encoded)
IO.puts("Round-trip match: #{decoded == decoded_again}")
```

## Finding Specific Transaction Types

### Using Etherscan

1. Go to https://etherscan.io or https://sepolia.etherscan.io
2. Navigate to a recent block
3. Look at the "Txn Type" column to find specific types:
   - Type 0: Legacy
   - Type 1: EIP-2930 (rare)
   - Type 2: EIP-1559 (most common)
   - Type 3: EIP-4844 (blob transactions)

### Using the Helper Script

Create a script to scan blocks:

```elixir
# scripts/find_transaction_types.exs
Code.require_file("test/support/ethereum_client.ex")

alias P2PMonitor.Test.EthereumClient

{:ok, latest} = EthereumClient.get_latest_block(:mainnet)

# Scan recent blocks
Enum.each((latest - 10)..latest, fn block_num ->
  {:ok, txs} = EthereumClient.get_block_transactions(block_num, :mainnet)
  
  type_counts = 
    txs
    |> Enum.map(fn tx -> tx["type"] end)
    |> Enum.frequencies()
  
  IO.puts("Block #{block_num}: #{inspect(type_counts)}")
end)
```

Run it with:

```bash
mix run scripts/find_transaction_types.exs
```

## Troubleshooting

### Rate Limiting

If you hit rate limits on public endpoints:

1. Sign up for a free RPC provider:
   - Infura: https://infura.io
   - Alchemy: https://alchemy.com
   - QuickNode: https://quicknode.com

2. Set your endpoint:
   ```bash
   export ETHEREUM_RPC_URL="https://mainnet.infura.io/v3/YOUR_KEY"
   ```

### Transaction Not Found

If a transaction is very old or on a different network:

1. Verify the network (mainnet vs testnet)
2. Check the transaction exists on Etherscan
3. Ensure you're using the correct RPC endpoint

### Decoding Failures

If decoding fails:

1. Verify the raw transaction data is valid
2. Check the transaction type matches expected format
3. Compare with Etherscan's decoded data

## Best Practices

1. **Cache Results**: Store fetched transactions to avoid repeated API calls
2. **Test Multiple Types**: Test all 4 transaction types (0, 1, 2, 3)
3. **Verify Round-trips**: Always test encode -> decode -> encode
4. **Use Testnets**: Use Sepolia for testing without mainnet concerns
5. **Check Edge Cases**: Test contract creations, large data fields, etc.

## Example Integration Test

Here's a complete example:

```elixir
defmodule P2PMonitor.Integration.RealDataTest do
  use ExUnit.Case, async: false
  
  alias P2PMonitor.Test.EthereumClient
  alias P2PMonitor.RLP.{Encoder, Decoder}
  
  @moduletag :integration
  
  @tag timeout: 30_000
  test "round-trip with real mainnet transaction" do
    # Use a known transaction hash
    tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
    
    # Fetch raw transaction
    assert {:ok, raw_tx} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
    
    # Decode it
    assert {:ok, decoded} = Decoder.decode_transaction(raw_tx)
    assert decoded.type == :legacy
    
    # Re-encode it
    encoded = Encoder.encode_transaction(decoded)
    
    # Decode again
    assert {:ok, decoded_again} = Decoder.decode_transaction(encoded)
    
    # Should match
    assert decoded == decoded_again
  end
end
```

## Additional Resources

- [Ethereum JSON-RPC API](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [Etherscan API Documentation](https://docs.etherscan.io/)
- [Transaction Types](https://ethereum.org/en/developers/docs/transactions/#typed-transaction-envelope)
