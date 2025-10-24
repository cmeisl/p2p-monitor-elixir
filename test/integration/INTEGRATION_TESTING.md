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

## Understanding Test Output

### RLP Source Logging

Integration tests display information about where the RLP transaction data came from:

```
Running ExUnit with seed: 630850, max_cases: 24
Including tags: [:integration]

  ℹ RLP source: etherscan
.  ℹ RLP source: etherscan
.  ℹ RLP source: etherscan
.
Finished in 1.4 seconds (0.00s async, 1.4s sync)
6 tests, 0 failures
```

The `ℹ RLP source:` indicator shows how transaction data was obtained:

- **`etherscan`**: Actual raw RLP-encoded transaction data fetched directly from Etherscan
  - This is the **preferred** source as it validates the decoder against real network data
  - Tests the actual bytes that were broadcast to the Ethereum network
  - Provides the highest confidence that encoding/decoding matches the official spec

- **`json_reconstruction`**: Transaction reconstructed from JSON-RPC response fields
  - Used as a fallback when Etherscan is unavailable (rate limiting, network issues)
  - Reconstructs the RLP encoding from individual transaction fields (nonce, gas, etc.)
  - Still validates round-trip encoding but doesn't test against actual network data
  - Less ideal but ensures tests can run without Etherscan dependency

### What These Sources Mean

**Etherscan (Actual RLP)**:
When tests show `etherscan`, the integration tests are validating your decoder against the exact bytes that were:
1. Signed by the transaction sender
2. Broadcast to the Ethereum network
3. Included in a mined block
4. Stored on the blockchain

This is the gold standard for validation - if your decoder can handle real mainnet transactions, it's production-ready.

**JSON Reconstruction (Fallback)**:
When tests show `json_reconstruction`, the test:
1. Fetches transaction details via JSON-RPC (eth_getTransactionByHash)
2. Uses your encoder to reconstruct the RLP from those fields
3. Tests your decoder against your encoder's output

This validates that encoding and decoding are consistent with each other, but doesn't guarantee they match the actual network format. It's useful for:
- Development when Etherscan is unavailable
- Testing in CI environments with limited external dependencies
- Verifying round-trip encoding consistency

### Interpreting Results

✅ **Best Case**: All tests show `etherscan`
- Your decoder works with real mainnet data
- Maximum confidence in production readiness

⚠️ **Acceptable**: Mix of `etherscan` and `json_reconstruction`
- Some tests validated against real data
- May indicate rate limiting or network issues
- Tests still pass but with reduced confidence

❌ **Concerning**: All tests show `json_reconstruction`
- No validation against real network data
- Suggests Etherscan is blocked or unavailable
- Check network connectivity or rate limits
- Consider using a different network or waiting before retrying

## Using the EthereumClient Helper

### Fetch a Transaction

```elixir
alias P2PMonitor.Test.EthereumClient
alias P2PMonitor.RLP.Decoder

# Fetch raw transaction data
tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
{:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
IO.puts("RLP source: #{source}")

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
{:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash)
IO.puts("RLP source: #{source}")
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
{:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash)
IO.puts("RLP source: #{source}")
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
    assert {:ok, raw_tx, source} = EthereumClient.get_raw_transaction(tx_hash, :mainnet)
    IO.puts("RLP source: #{source}")
    
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
