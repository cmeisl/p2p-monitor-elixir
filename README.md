# P2P Monitor

An Elixir application that connects to the Ethereum peer-to-peer network using the DevP2P and ETH wire protocols to monitor and list transactions in real-time as they propagate through the network before being included in blocks.

## Overview

P2P Monitor is a lightweight Ethereum network monitoring tool that:

- **Monitors Real-time Transactions**: Captures transactions as they are broadcast to the Ethereum network
- **Tracks Peer Attribution**: Records which peer sent each transaction, including IP address, geographic location, and timing
- **Analyzes Network Propagation**: Studies how transactions spread through the P2P network
- **Provides Network Insights**: Offers metrics and insights into network activity and peer behavior

This tool is designed for network research, MEV analysis, security monitoring, and understanding Ethereum's P2P network topology.

## Project Status

**Phase 1: Foundation** ✅ **Complete** (100%)

- ✅ Project setup and dependencies
- ✅ RLP encoding/decoding utilities
- ✅ Cryptography utilities (Keccak-256, ECDSA signatures)
- ✅ Network configuration for mainnet and testnets
- ✅ Comprehensive test suite (86.3% coverage)
- ✅ Property-based testing with StreamData

**Next Phase**: Node Discovery (UDP-based discovery protocol, Kademlia DHT)

## Features

### Implemented (Phase 1)

- **RLP Encoding/Decoding**: Full support for Ethereum's RLP serialization format
  - Legacy transactions
  - EIP-1559 transactions (Type 2)
  - EIP-2930 transactions (Type 1)
  
- **Cryptography**:
  - Keccak-256 hashing
  - ECDSA signature creation and recovery (secp256k1)
  - EIP-55 checksum address encoding
  - EIP-155 transaction signing (chain-specific)
  - Public key to Ethereum address conversion

- **Network Configuration**:
  - Mainnet
  - Sepolia (testnet)
  - Holesky (testnet)
  - Goerli (deprecated testnet)
  - Configurable boot nodes and genesis hashes

### Planned Features

- **Node Discovery**: DHT-based peer discovery using Kademlia
- **RLPx Protocol**: Encrypted peer-to-peer communication
- **ETH Wire Protocol**: Transaction pool synchronization
- **Peer Management**: Connection management and health monitoring
- **Transaction Processing**: Real-time transaction parsing with peer attribution
- **Geographic Tracking**: IP-based geolocation of peers
- **Data Storage**: PostgreSQL storage for transactions and peer data
- **Web Dashboard**: Real-time visualization of network activity

## Prerequisites

- **Elixir**: 1.16 or higher
- **Erlang/OTP**: 26 or higher
- **Mix**: Elixir's build tool (comes with Elixir)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/p2p-monitor-elixir.git
cd p2p-monitor-elixir
```

### 2. Install Dependencies

```bash
mix deps.get
```

This will install all required dependencies including:
- `ex_secp256k1` - Elliptic curve cryptography
- `ex_keccak` - Keccak-256 hashing
- `ex_rlp` - RLP encoding/decoding
- Testing libraries (ExUnit, StreamData, Mox, Faker)
- Development tools (Credo, Dialyxir, ExDoc)

### 3. Compile the Project

```bash
mix compile
```

## Running Tests

### Run All Tests

```bash
mix test
```

### Run Tests with Coverage

```bash
MIX_ENV=test mix coveralls
```

### Generate HTML Coverage Report

```bash
MIX_ENV=test mix coveralls.html
```

Open `cover/excoveralls.html` in your browser to view the detailed coverage report.

### Run Specific Test Files

```bash
# Test RLP encoding/decoding
mix test test/p2p_monitor/rlp/

# Test cryptography
mix test test/p2p_monitor/crypto/

# Test network configuration
mix test test/p2p_monitor/config/

# Run property-based tests only
mix test test/p2p_monitor/rlp/property_test.exs
```

### Run Tests with Different Options

```bash
# Run tests with detailed output
mix test --trace

# Run tests with a specific seed for reproducibility
mix test --seed 123456

# Run only failed tests from last run
mix test --failed

# Run tests matching a pattern
mix test --only property
```

## Development

### Code Quality Checks

```bash
# Run static code analysis
mix credo --strict

# Run Dialyzer for type checking (first run will build PLT)
mix dialyzer

# Run security analysis
mix sobelow
```

### Generate Documentation

```bash
mix docs
```

Open `doc/index.html` in your browser to view the generated documentation.

### Interactive Shell

```bash
# Start IEx with the project loaded
iex -S mix

# Try out the modules
iex> P2PMonitor.Crypto.Keccak.hash("hello")
iex> P2PMonitor.Config.Network.get(:mainnet)
```

## Project Structure

```
p2p-monitor-elixir/
├── lib/
│   ├── p2p_monitor/
│   │   ├── config/
│   │   │   └── network.ex          # Network configurations
│   │   ├── crypto/
│   │   │   ├── keccak.ex           # Keccak-256 hashing
│   │   │   └── signature.ex        # ECDSA signatures
│   │   └── rlp/
│   │       ├── encoder.ex          # RLP encoding
│   │       └── decoder.ex          # RLP decoding
│   └── p2p_monitor.ex              # Main application module
├── test/
│   ├── support/
│   │   ├── factory.ex              # Test data factories
│   │   └── test_helper.ex          # Test utilities
│   └── p2p_monitor/
│       ├── config/
│       │   └── network_test.exs
│       ├── crypto/
│       │   ├── keccak_test.exs
│       │   └── signature_test.exs
│       └── rlp/
│           ├── encoder_test.exs
│           ├── decoder_test.exs
│           └── property_test.exs   # Property-based tests
├── config/
│   ├── config.exs                  # Main configuration
│   ├── dev.exs                     # Development config
│   └── test.exs                    # Test config
├── mix.exs                         # Project definition
├── SPECIFICATION.md                # Full project specification
└── README.md                       # This file
```

## Configuration

Edit `config/config.exs` to customize:

```elixir
config :p2p_monitor,
  # Network configuration
  network: :mainnet,              # :mainnet, :sepolia, :holesky, :goerli
  max_peers: 50,
  target_peers: 25,
  
  # Transaction filtering
  min_value_wei: 0,
  filter_contracts: false,
  
  # Peer tracking
  enable_geoip: false,
  track_propagation: true,
  max_propagations_per_tx: 50,
  
  # Output
  outputs: [:console],
  log_level: :info
```

## Usage Examples

### Encode and Decode RLP

```elixir
alias P2PMonitor.RLP.{Encoder, Decoder}

# Encode data
encoded = Encoder.encode("hello")
# => <<0x85, 0x68, 0x65, 0x6C, 0x6C, 0x6F>>

# Decode data
{:ok, decoded} = Decoder.decode(encoded)
# => {:ok, "hello"}

# Encode a transaction
tx = %{
  nonce: 0,
  gas_price: 20_000_000_000,
  gas_limit: 21_000,
  to: <<0x12, 0x34>>,
  value: 1_000_000_000_000_000_000,
  data: <<>>
}
encoded_tx = Encoder.encode_transaction(tx)
```

### Hash with Keccak-256

```elixir
alias P2PMonitor.Crypto.Keccak

# Hash data
hash = Keccak.hash("hello")
# => 32-byte hash

# Get hex representation
hex = Keccak.hash_hex("hello")
# => "1c8aff950685c2ed4bc3174f347228073ad27a1765555cce721ca7c5cbe553b6"

# Convert public key to Ethereum address
public_key = <<...>> # 64 bytes
address = Keccak.public_key_to_address(public_key)
# => 20-byte address

# Get checksummed address (EIP-55)
address_hex = Keccak.public_key_to_address_hex(public_key, checksum: true, prefix: true)
# => "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
```

### Sign and Recover Signatures

```elixir
alias P2PMonitor.Crypto.Signature

# Sign a message
private_key = :crypto.strong_rand_bytes(32)
message_hash = :crypto.strong_rand_bytes(32)

{:ok, signature} = Signature.sign(message_hash, private_key)
# => {:ok, %{v: 27, r: ..., s: ...}}

# Recover address from signature
{:ok, address} = Signature.recover_address(message_hash, signature)
# => {:ok, <<...>>} # 20-byte address
```

### Network Configuration

```elixir
alias P2PMonitor.Config.Network

# Get mainnet configuration
config = Network.get(:mainnet)
# => %{chain_id: 1, genesis_hash: <<...>>, boot_nodes: [...]}

# Get boot nodes for a network
nodes = Network.boot_nodes(:sepolia)
# => ["enode://...", ...]

# Get chain ID
chain_id = Network.chain_id(:mainnet)
# => 1
```

## Test Coverage

Current test coverage: **86.3%**

- Keccak module: 100%
- Network config: 100%
- RLP encoder: 96.0%
- RLP decoder: 85.7%
- Signature module: 64.5%

**Test Statistics:**
- 236 total tests (31 doctests + 21 properties + 184 unit tests)
- Property-based tests with StreamData
- Known test vectors for Ethereum compatibility

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Run code quality checks (`mix credo --strict`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Roadmap

See [SPECIFICATION.md](SPECIFICATION.md) for the complete implementation roadmap covering:

- Phase 1: Foundation ✅ **Complete**
- Phase 2: Node Discovery (In Progress)
- Phase 3: RLPx Protocol
- Phase 4: ETH Wire Protocol
- Phase 5: Transaction Processing
- Phase 6: Output & Storage
- Phase 7: Monitoring & Ops
- Phase 8: QA and Hardening

## License

[Add your license here]

## References

- [Ethereum DevP2P Specification](https://github.com/ethereum/devp2p)
- [ETH Wire Protocol](https://github.com/ethereum/devp2p/blob/master/caps/eth.md)
- [RLPx Transport Protocol](https://github.com/ethereum/devp2p/blob/master/rlpx.md)
- [EIP-1559: Fee Market](https://eips.ethereum.org/EIPS/eip-1559)
- [EIP-155: Simple Replay Attack Protection](https://eips.ethereum.org/EIPS/eip-155)
- [EIP-55: Mixed-case Checksum Address Encoding](https://eips.ethereum.org/EIPS/eip-55)

## Acknowledgments

Built with:
- [Elixir](https://elixir-lang.org/) - Dynamic, functional language
- [ex_secp256k1](https://github.com/omgnetwork/ex_secp256k1) - Elliptic curve cryptography
- [ex_keccak](https://github.com/tzumby/ex_keccak) - Keccak hashing
- [ex_rlp](https://github.com/exthereum/ex_rlp) - RLP encoding/decoding
