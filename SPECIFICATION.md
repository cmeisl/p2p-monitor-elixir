# Ethereum P2P Network Monitor - Specification

## Project Overview

An Elixir application that connects to the Ethereum peer-to-peer network using the DevP2P and ETH wire protocols to monitor and list transactions in real-time as they propagate through the network before being included in blocks.

## Goals

1. **Real-time Transaction Monitoring**: Capture transactions as they are broadcast to the Ethereum network
2. **P2P Network Integration**: Implement DevP2P and ETH protocol to connect as a lightweight Ethereum node
3. **Transaction Listing**: Display and optionally store detected transactions with full attribution
4. **Peer Tracking and Attribution**: Track which peer sent each transaction, including IP address, geographic location, and timing
5. **Scalability**: Handle high transaction throughput during network congestion
6. **Observability**: Provide metrics and insights into network activity and peer behavior

## Technical Requirements

### Core Functionality

1. **DevP2P Protocol Implementation**
   - RLPx transport layer (encrypted/authenticated connection)
   - Node discovery via DHT (Kademlia)
   - Peer connection management
   - Capability negotiation

2. **ETH Wire Protocol**
   - Support ETH/68 or ETH/67 protocol version
   - Handle protocol messages:
     - `NewPooledTransactionHashes` - notification of new transactions
     - `GetPooledTransactions` - request transaction details
     - `PooledTransactions` - receive full transaction data
     - `Transactions` - unsolicited transaction broadcasts
   - Status message exchange for handshake

3. **Transaction Processing**
   - Parse RLP-encoded transaction data
   - Decode transaction fields:
     - From address (derived from signature)
     - To address
     - Value (in Wei)
     - Gas price/fees (base fee + priority fee for EIP-1559)
     - Gas limit
     - Nonce
     - Data/input
     - Transaction hash
   - Support both legacy and EIP-1559 transaction types
   - **Peer Attribution**: Track and store which peer sent each transaction:
     - Peer node ID
     - Peer IP address and port
     - Detection timestamp
     - Propagation order (first seen, subsequent duplicates)

4. **Data Output**
   - Real-time console logging of transactions
   - Optional structured storage (PostgreSQL, ETS, or file-based)
   - Configurable output formats (JSON, text, custom)
   - Optional filtering capabilities

### Non-Functional Requirements

1. **Performance**
   - Support monitoring 100+ concurrent peer connections
   - Handle 1000+ transactions per second during peak times
   - Minimal latency in transaction detection

2. **Reliability**
   - Automatic peer reconnection on disconnection
   - Graceful handling of malformed messages
   - Error recovery and logging

3. **Security**
   - Validate all incoming messages
   - Implement rate limiting for peer messages
   - Protect against malicious peers

4. **Configurability**
   - Configurable peer count
   - Network selection (mainnet, testnet, etc.)
   - Filtering rules (by value, address, etc.)
   - Output destinations and formats

## Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────┐
│                   P2P Monitor Application                │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐     ┌──────────────┐                  │
│  │   Discovery  │────▶│ Peer Manager │                  │
│  │   Service    │     │              │                  │
│  └──────────────┘     └──────┬───────┘                  │
│                              │                           │
│                              ▼                           │
│                     ┌────────────────┐                   │
│                     │ Peer Connection│                   │
│                     │  Supervisor    │                   │
│                     └────────┬───────┘                   │
│                              │                           │
│                    ┌─────────┴─────────┐                │
│                    ▼                   ▼                 │
│           ┌─────────────────┐  ┌─────────────────┐      │
│           │  Peer Process 1 │  │  Peer Process N │      │
│           │   (GenServer)   │  │   (GenServer)   │      │
│           └────────┬─────────┘  └────────┬────────┘      │
│                    │                     │               │
│                    └──────────┬──────────┘               │
│                               ▼                          │
│                    ┌─────────────────────┐               │
│                    │ Transaction Handler │               │
│                    │   (GenStage/Flow)   │               │
│                    └──────────┬──────────┘               │
│                               ▼                          │
│                    ┌─────────────────────┐               │
│                    │  Output / Storage   │               │
│                    └─────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

### Component Details

#### 1. Discovery Service
- **Responsibility**: Find and maintain a list of active Ethereum nodes
- **Implementation**: GenServer
- **Key Functions**:
  - Bootstrap from known boot nodes
  - Kademlia DHT lookup for peer discovery
  - Maintain routing table of discovered nodes
  - Periodic peer refresh

#### 2. Peer Manager
- **Responsibility**: Manage overall peer connections and health
- **Implementation**: GenServer
- **Key Functions**:
  - Decide when to connect to new peers
  - Monitor peer quality/responsiveness
  - Implement peer selection strategy
  - Enforce max peer limits

#### 3. Peer Connection Supervisor
- **Responsibility**: Supervise individual peer connection processes
- **Implementation**: DynamicSupervisor
- **Key Functions**:
  - Start new peer connection workers
  - Restart failed connections
  - Monitor active connections

#### 4. Peer Process
- **Responsibility**: Manage a single peer connection
- **Implementation**: GenServer
- **Key Functions**:
  - Establish RLPx encrypted connection
  - **Capture peer IP address and port** from TCP socket
  - Perform protocol handshake
  - Send/receive ETH wire protocol messages
  - Request pooled transactions
  - Forward received transactions to handler **with peer metadata**
  - Update peer metrics (latency, transaction count, quality score)

#### 5. Transaction Handler
- **Responsibility**: Process and deduplicate transactions from multiple peers
- **Implementation**: GenStage or Flow
- **Key Functions**:
  - Deduplicate transactions by hash
  - Parse and validate transaction data
  - Enrich transaction data (calculate from address, convert Wei, etc.)
  - **Track peer attribution**: Associate each transaction with source peer(s)
  - **Maintain transaction cache**: Track which transactions seen and from which peers
  - **Calculate propagation metrics**: Timing between first and subsequent peer notifications
  - Route to output destinations with full peer metadata

#### 6. Output/Storage
- **Responsibility**: Handle transaction output
- **Implementation**: Multiple modules based on config
- **Options**:
  - Console logger
  - File writer
  - Database writer (Ecto + PostgreSQL)
  - External API webhook

## Technology Stack

### Core Dependencies

1. **Cryptography**
   - `ex_secp256k1` or `libsecp256k1` - ECDSA signature operations
   - `:crypto` (Erlang) - AES encryption for RLPx
   - `ex_keccak` - Keccak-256 hashing

2. **Encoding/Decoding**
   - `ex_rlp` - RLP encoding/decoding
   - `ex_abi` - ABI encoding for contract calls (future)

3. **Networking**
   - `:gen_tcp` (Erlang) - TCP socket connections
   - `:inet` (Erlang) - Network utilities
   - `ex_udp` or `:gen_udp` - UDP for node discovery

4. **Concurrency**
   - `gen_stage` - Back-pressure handling for transaction processing
   - Native OTP supervisors and GenServers

5. **Storage (Optional)**
   - `ecto` - Database abstraction
   - `postgrex` - PostgreSQL driver

6. **Configuration**
   - `config` - Elixir native configuration
   - `dotenv` or `config_tuples` - Environment-based config

7. **Observability**
   - `telemetry` - Metrics and instrumentation
   - `logger` - Structured logging

8. **Geographic Data (Optional)**
   - `geolix` - IP geolocation lookup
   - `geolix_adapter_mmdb2` - MaxMind database adapter
   - MaxMind GeoLite2 database (free) - IP to location mapping

### Development and Testing Dependencies

- `credo` - Code analysis and linting
- `dialyxir` - Static type checking with Dialyzer
- `ex_doc` - Documentation generation
- `mix_test_watch` - Continuous testing during development
- `stream_data` - Property-based testing
- `mox` - Mocking library for behaviors
- `bypass` - Mock HTTP servers for testing
- `faker` - Generate fake data for tests
- `excoveralls` - Test coverage reporting
- `benchee` - Benchmarking and performance testing
- `sobelow` - Security-focused static analysis
- `doctor` - Documentation coverage checker

## Data Models

### Peer Structure

```elixir
%Peer{
  id: binary(),              # Node ID (64 bytes)
  ip: tuple(),               # IP address (e.g., {192, 168, 1, 1})
  ip_string: String.t(),     # IP address as string for logging/storage
  tcp_port: integer(),       # TCP port
  udp_port: integer(),       # UDP port
  capabilities: [%Capability{}],
  status: :disconnected | :connecting | :connected | :failed,

  # Connection tracking
  connected_at: DateTime.t() | nil,
  disconnected_at: DateTime.t() | nil,
  last_seen: DateTime.t(),

  # Performance metrics
  quality_score: float(),    # 0.0 to 1.0 based on reliability
  latency_ms: integer() | nil,
  transactions_received: integer(),  # Count of txs from this peer

  # Geographic information (optional, via IP lookup)
  country: String.t() | nil,
  city: String.t() | nil,
  latitude: float() | nil,
  longitude: float() | nil,

  # Client information
  client_version: String.t() | nil  # e.g., "Geth/v1.13.0"
}
```

### Transaction Structure

```elixir
%Transaction{
  # Transaction data
  hash: binary(),            # Transaction hash (32 bytes)
  from: binary(),            # Sender address (20 bytes)
  to: binary() | nil,        # Recipient address (nil for contract creation)
  value: integer(),          # Value in Wei
  gas_limit: integer(),
  gas_price: integer() | nil,  # Legacy transactions
  max_fee_per_gas: integer() | nil,        # EIP-1559
  max_priority_fee_per_gas: integer() | nil,  # EIP-1559
  nonce: integer(),
  data: binary(),
  v: integer(),              # Signature V
  r: integer(),              # Signature R
  s: integer(),              # Signature S
  type: :legacy | :eip2930 | :eip1559,

  # Peer attribution (first peer that sent this transaction)
  first_seen_at: DateTime.t(),
  first_seen_peer_id: binary(),          # Peer node ID
  first_seen_peer_ip: String.t(),        # Peer IP address
  first_seen_peer_port: integer(),       # Peer TCP port
  first_seen_peer_country: String.t() | nil,  # Geographic location

  # Multi-peer tracking (if same transaction received from multiple peers)
  seen_count: integer(),     # How many peers sent this tx
  peer_propagations: [%TransactionPropagation{}]  # List of all peers
}
```

### Transaction Propagation Structure

Tracks each time a transaction is seen from a different peer:

```elixir
%TransactionPropagation{
  transaction_hash: binary(),
  peer_id: binary(),
  peer_ip: String.t(),
  peer_port: integer(),
  peer_country: String.t() | nil,
  seen_at: DateTime.t(),
  latency_from_first_ms: integer()  # Time difference from first detection
}
```

## Configuration

### Application Config (config/config.exs)

```elixir
config :p2p_monitor,
  # Network
  network: :mainnet,  # :mainnet, :sepolia, :holesky
  max_peers: 50,
  target_peers: 25,

  # Discovery
  boot_nodes: [
    # Ethereum Foundation boot nodes
    "enode://d860a01f9722d78051619d1e2351aba3f43f943f6f00718d1b9baa4101932a1f5011f16bb2b1bb35db20d6fe28fa0bf09636d26a87d31de9ec6203eeedb1f666@18.138.108.67:30303",
    # ... more boot nodes
  ],

  # Transaction filtering
  min_value_wei: 0,
  filter_contracts: false,

  # Peer tracking
  enable_geoip: true,
  geoip_database_path: "priv/GeoLite2-City.mmdb",
  track_propagation: true,  # Track same tx from multiple peers
  max_propagations_per_tx: 50,  # Limit storage for popular txs

  # Output
  outputs: [:console, :postgres],
  log_level: :info,
  console_show_peer_info: true

config :p2p_monitor, P2PMonitor.Repo,
  database: "p2p_monitor_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
```

## Peer Tracking and Transaction Attribution

A core feature of this application is comprehensive tracking of which peers send which transactions, enabling network topology analysis and propagation studies.

### Key Features

#### 1. IP Address Capture
Every peer connection maintains:
- **IP Address**: Captured during connection establishment (TCP handshake)
- **Port Numbers**: Both TCP (for RLPx) and UDP (for discovery) ports
- **Connection Metadata**: Timestamps for connection, disconnection, last activity
- **Geographic Data**: Optional IP-to-location mapping using GeoIP databases

#### 2. Transaction-to-Peer Association
Each transaction is tagged with complete peer information:
- **First Seen**: Which peer first sent the transaction (most valuable for propagation analysis)
- **All Sources**: Track all peers that sent the same transaction hash
- **Timing**: Precise timestamps for each peer's transmission
- **Propagation Order**: Reconstruct how transactions spread through the network

#### 3. Peer Reputation and Scoring
Track peer quality metrics:
- **Transaction Volume**: How many unique transactions each peer provides
- **Latency**: Response time for transaction requests
- **Reliability**: Connection stability and uptime
- **First-Seen Rate**: How often this peer is first to send new transactions (indicates network position)

### Use Cases

#### Network Research
- **Propagation Analysis**: Study how quickly transactions spread through the P2P network
- **Geographic Distribution**: Understand where Ethereum nodes are located globally
- **Topology Mapping**: Identify well-connected nodes and network clusters
- **Client Distribution**: See which client implementations (Geth, Nethermind, etc.) are most common

#### MEV and Priority Analysis
- **Transaction Source Tracking**: Identify which peers consistently send high-value transactions first
- **Bundle Detection**: Recognize when multiple related transactions come from the same source
- **Latency Analysis**: Measure geographic latency effects on transaction arrival

#### Security and Monitoring
- **Spam Detection**: Identify peers sending invalid or spam transactions
- **Peer Reputation**: Build trust scores for peers based on behavior
- **Network Health**: Monitor peer availability and connection quality
- **Anomaly Detection**: Detect unusual patterns in transaction sources

### Implementation Details

#### Peer Information Capture
When a peer connection is established:
1. Extract IP address from TCP socket: `:inet.peername(socket)`
2. Store peer info in ETS table for fast lookup
3. Persist to database for historical analysis
4. Optionally perform GeoIP lookup for location data

#### Transaction Attribution Flow
```
Peer Process receives transaction
    ↓
Extract peer info from connection state
    ↓
Pass to Transaction Handler with metadata
    ↓
Check if transaction already seen (by hash)
    ↓
If first time: Mark as "first_seen" with peer info
    ↓
If duplicate: Add to propagations list
    ↓
Store in database with full peer attribution
```

#### Database Schema

**peers table:**
```sql
CREATE TABLE peers (
  id BIGSERIAL PRIMARY KEY,
  node_id BYTEA NOT NULL UNIQUE,
  ip_address INET NOT NULL,
  tcp_port INTEGER NOT NULL,
  udp_port INTEGER,
  client_version TEXT,
  country VARCHAR(2),
  city TEXT,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  connected_at TIMESTAMP,
  disconnected_at TIMESTAMP,
  last_seen_at TIMESTAMP NOT NULL,
  quality_score REAL DEFAULT 0.5,
  latency_ms INTEGER,
  transactions_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_peers_node_id ON peers(node_id);
CREATE INDEX idx_peers_ip ON peers(ip_address);
CREATE INDEX idx_peers_country ON peers(country);
```

**transactions table:**
```sql
CREATE TABLE transactions (
  id BIGSERIAL PRIMARY KEY,
  hash BYTEA NOT NULL UNIQUE,
  from_address BYTEA NOT NULL,
  to_address BYTEA,
  value NUMERIC(78, 0) NOT NULL,  -- Supports up to 2^256
  gas_limit BIGINT NOT NULL,
  gas_price BIGINT,
  max_fee_per_gas BIGINT,
  max_priority_fee_per_gas BIGINT,
  nonce BIGINT NOT NULL,
  data BYTEA,
  tx_type VARCHAR(20) NOT NULL,

  -- First peer attribution
  first_seen_at TIMESTAMP NOT NULL,
  first_seen_peer_id BIGINT REFERENCES peers(id),
  first_seen_peer_ip INET NOT NULL,
  first_seen_peer_country VARCHAR(2),

  -- Propagation tracking
  seen_count INTEGER DEFAULT 1,

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_transactions_hash ON transactions(hash);
CREATE INDEX idx_transactions_first_seen_at ON transactions(first_seen_at);
CREATE INDEX idx_transactions_first_seen_peer ON transactions(first_seen_peer_id);
CREATE INDEX idx_transactions_from ON transactions(from_address);
CREATE INDEX idx_transactions_to ON transactions(to_address);
```

**transaction_propagations table:**
```sql
CREATE TABLE transaction_propagations (
  id BIGSERIAL PRIMARY KEY,
  transaction_id BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  peer_id BIGINT NOT NULL REFERENCES peers(id),
  peer_ip INET NOT NULL,
  peer_country VARCHAR(2),
  seen_at TIMESTAMP NOT NULL,
  latency_from_first_ms INTEGER NOT NULL,

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tx_props_transaction ON transaction_propagations(transaction_id);
CREATE INDEX idx_tx_props_peer ON transaction_propagations(peer_id);
CREATE INDEX idx_tx_props_seen_at ON transaction_propagations(seen_at);
```

#### GeoIP Integration
Optional dependency for geographic data:
- Use `freegeoip` or `geolix` Elixir library
- Load MaxMind GeoLite2 database (free)
- Perform lookup on peer connection
- Cache results to avoid repeated lookups

### Console Output Format

Transaction display includes peer information:
```
[2025-10-24 14:23:45.123] NEW TRANSACTION
  Hash: 0x1234...5678
  From: 0xabcd...ef01 → To: 0x9876...5432
  Value: 1.5 ETH
  Gas: 21000 @ 25 Gwei
  Type: EIP-1559

  First Seen From:
    Peer: 0xabc...def
    IP: 45.123.67.89:30303
    Location: San Francisco, US
    Latency: 45ms

  Also seen from 3 other peers:
    - 178.234.12.45 (London, GB) +127ms
    - 23.45.67.89 (Tokyo, JP) +231ms
    - 92.123.45.67 (Berlin, DE) +156ms
```

### Analytics Queries

Example queries enabled by peer tracking:

```elixir
# Find most active peers
Repo.all(from p in Peer,
  order_by: [desc: p.transactions_count],
  limit: 10
)

# Transactions by country
Repo.all(from t in Transaction,
  group_by: t.first_seen_peer_country,
  select: {t.first_seen_peer_country, count(t.id)}
)

# Average propagation time
Repo.one(from tp in TransactionPropagation,
  select: avg(tp.latency_from_first_ms)
)

# Peers that are often first to see transactions
Repo.all(from t in Transaction,
  join: p in Peer, on: t.first_seen_peer_id == p.id,
  group_by: [p.id, p.ip_address],
  select: {p.ip_address, count(t.id)},
  order_by: [desc: count(t.id)],
  limit: 20
)
```

## Testing Strategy

Comprehensive testing is critical for a P2P network application where correctness, reliability, and performance are essential. The testing strategy covers multiple layers from unit tests to end-to-end network simulations.

### Testing Objectives

1. **Correctness**: Ensure all protocol implementations match specifications
2. **Reliability**: Verify error handling and recovery mechanisms
3. **Performance**: Validate throughput and resource usage under load
4. **Security**: Test resistance to malicious peers and invalid data
5. **Peer Attribution**: Verify accurate tracking of transaction sources

### Test Coverage Requirements

- **Minimum Coverage**: 80% overall code coverage
- **Critical Paths**: 95% coverage for cryptography, RLP encoding, and protocol handling
- **Integration Points**: 90% coverage for peer connections and transaction processing
- **Database Operations**: 85% coverage for Ecto schemas and queries

### Testing Layers

#### 1. Unit Tests

Test individual modules and functions in isolation.

**Cryptography Module** (`test/p2p_monitor/crypto_test.exs`):
```elixir
defmodule P2PMonitor.CryptoTest do
  use ExUnit.Case, async: true

  describe "keccak256/1" do
    test "produces correct hash for known inputs" do
      assert Crypto.keccak256("") == <<0xC5, 0xD2, 0x46, ...>>
      assert Crypto.keccak256("hello") == <<0x1C, 0x8A, ...>>
    end
  end

  describe "recover_address/2" do
    test "recovers correct address from signature" do
      signature = %{v: 27, r: ..., s: ...}
      message_hash = <<...>>
      assert {:ok, address} = Crypto.recover_address(message_hash, signature)
      assert address == <<0x12, 0x34, ...>>
    end

    test "returns error for invalid signature" do
      assert {:error, :invalid_signature} = Crypto.recover_address(hash, bad_sig)
    end
  end
end
```

**RLP Encoding** (`test/p2p_monitor/rlp_test.exs`):
```elixir
defmodule P2PMonitor.RLPTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  describe "encode/decode roundtrip" do
    property "any valid Elixir term can be encoded and decoded" do
      check all term <- rlp_compatible_term() do
        encoded = RLP.encode(term)
        assert {:ok, decoded} = RLP.decode(encoded)
        assert decoded == term
      end
    end
  end

  test "encodes known Ethereum transaction correctly" do
    tx = %{nonce: 0, gas_price: 20_000_000_000, ...}
    encoded = RLP.encode_transaction(tx)
    assert encoded == <<0xF8, 0x6C, ...>>  # Known valid encoding
  end
end
```

**Transaction Parser** (`test/p2p_monitor/transaction_parser_test.exs`):
```elixir
defmodule P2PMonitor.TransactionParserTest do
  use ExUnit.Case, async: true

  describe "parse_transaction/1" do
    test "parses legacy transaction correctly" do
      raw_tx = <<0xF8, 0x6C, ...>>  # Real transaction from mainnet
      assert {:ok, tx} = TransactionParser.parse(raw_tx)
      assert tx.type == :legacy
      assert tx.from == <<0xAB, 0xCD, ...>>
      assert tx.nonce == 42
    end

    test "parses EIP-1559 transaction correctly" do
      raw_tx = <<0x02, 0xF8, ...>>
      assert {:ok, tx} = TransactionParser.parse(raw_tx)
      assert tx.type == :eip1559
      assert tx.max_fee_per_gas == 30_000_000_000
    end

    test "returns error for malformed transaction" do
      assert {:error, :invalid_rlp} = TransactionParser.parse(<<0xFF>>)
    end

    test "validates signature correctly" do
      # Transaction with invalid signature
      bad_tx = %{v: 99, r: 0, s: 0, ...}
      assert {:error, :invalid_signature} = TransactionParser.parse(bad_tx)
    end
  end
end
```

**Peer Tracking** (`test/p2p_monitor/peer_tracker_test.exs`):
```elixir
defmodule P2PMonitor.PeerTrackerTest do
  use ExUnit.Case, async: false  # Uses ETS

  setup do
    :ets.delete_all_objects(:peer_table)
    :ok
  end

  test "stores peer information correctly" do
    peer = %Peer{
      id: <<1, 2, 3>>,
      ip: {192, 168, 1, 1},
      tcp_port: 30303
    }

    assert :ok = PeerTracker.register(peer)
    assert {:ok, stored} = PeerTracker.get(peer.id)
    assert stored.ip == peer.ip
  end

  test "captures IP address from socket" do
    # Mock socket connection
    socket = create_mock_socket({45, 123, 67, 89}, 30303)

    assert {:ok, ip, port} = PeerTracker.extract_peer_info(socket)
    assert ip == {45, 123, 67, 89}
    assert port == 30303
  end

  test "increments transaction count for peer" do
    peer_id = <<1, 2, 3>>
    PeerTracker.register(%Peer{id: peer_id, transactions_received: 0})

    PeerTracker.increment_transaction_count(peer_id)
    PeerTracker.increment_transaction_count(peer_id)

    {:ok, peer} = PeerTracker.get(peer_id)
    assert peer.transactions_received == 2
  end
end
```

#### 2. Integration Tests

Test interactions between components.

**Peer Connection Integration** (`test/integration/peer_connection_test.exs`):
```elixir
defmodule P2PMonitor.Integration.PeerConnectionTest do
  use ExUnit.Case, async: false

  setup do
    # Start a mock Ethereum peer
    {:ok, mock_peer} = MockEthereumPeer.start_link(port: 30304)
    on_exit(fn -> MockEthereumPeer.stop(mock_peer) end)
    %{mock_peer: mock_peer}
  end

  test "establishes RLPx connection and performs handshake", %{mock_peer: peer} do
    peer_info = %{ip: {127, 0, 0, 1}, port: 30304}

    {:ok, conn} = PeerConnection.start_link(peer_info)

    # Wait for connection
    assert_receive {:peer_connected, ^conn}, 5000

    # Verify handshake completed
    state = :sys.get_state(conn)
    assert state.status == :connected
    assert state.capabilities != []
  end

  test "receives transaction and attributes to correct peer", %{mock_peer: peer} do
    peer_info = %{ip: {127, 0, 0, 1}, port: 30304}
    {:ok, conn} = PeerConnection.start_link(peer_info)

    # Mock peer sends transaction
    tx = create_test_transaction()
    MockEthereumPeer.broadcast_transaction(peer, tx)

    # Verify transaction received with peer attribution
    assert_receive {:transaction_received, received_tx, peer_metadata}, 2000
    assert peer_metadata.ip == "127.0.0.1"
    assert peer_metadata.port == 30304
    assert received_tx.hash == tx.hash
  end

  test "handles peer disconnection gracefully", %{mock_peer: peer} do
    peer_info = %{ip: {127, 0, 0, 1}, port: 30304}
    {:ok, conn} = PeerConnection.start_link(peer_info)

    assert_receive {:peer_connected, ^conn}, 5000

    # Simulate disconnect
    MockEthereumPeer.disconnect(peer)

    # Verify proper cleanup
    assert_receive {:peer_disconnected, ^conn}, 2000
    refute Process.alive?(conn)
  end
end
```

**Transaction Handler Integration** (`test/integration/transaction_handler_test.exs`):
```elixir
defmodule P2PMonitor.Integration.TransactionHandlerTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!(TransactionHandler)
    start_supervised!(P2PMonitor.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(P2PMonitor.Repo, :manual)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(P2PMonitor.Repo)
  end

  test "deduplicates transactions from multiple peers" do
    tx = create_test_transaction()
    peer1 = %{id: <<1>>, ip: "45.1.2.3", port: 30303}
    peer2 = %{id: <<2>>, ip: "67.4.5.6", port: 30303}

    # Same transaction from two peers
    TransactionHandler.process_transaction(tx, peer1)
    TransactionHandler.process_transaction(tx, peer2)

    # Should only store once, but track both peers
    stored_tx = Repo.get_by!(Transaction, hash: tx.hash)
    assert stored_tx.first_seen_peer_ip == "45.1.2.3"
    assert stored_tx.seen_count == 2

    propagations = Repo.all(
      from tp in TransactionPropagation,
      where: tp.transaction_id == ^stored_tx.id
    )
    assert length(propagations) == 2
  end

  test "calculates propagation latency correctly" do
    tx = create_test_transaction()
    peer1 = %{id: <<1>>, ip: "1.1.1.1", port: 30303}
    peer2 = %{id: <<2>>, ip: "2.2.2.2", port: 30303}

    # First peer sends transaction
    TransactionHandler.process_transaction(tx, peer1)

    # Wait 100ms, then second peer sends
    Process.sleep(100)
    TransactionHandler.process_transaction(tx, peer2)

    # Check propagation latency
    stored_tx = Repo.get_by!(Transaction, hash: tx.hash)
    [_first, second] = Repo.all(
      from tp in TransactionPropagation,
      where: tp.transaction_id == ^stored_tx.id,
      order_by: tp.seen_at
    )

    assert second.latency_from_first_ms >= 100
    assert second.latency_from_first_ms < 150
  end

  test "enforces max propagations limit" do
    tx = create_test_transaction()

    # Send same transaction from 100 peers
    for i <- 1..100 do
      peer = %{id: <<i>>, ip: "1.1.1.#{i}", port: 30303}
      TransactionHandler.process_transaction(tx, peer)
    end

    # Should only store up to configured max
    stored_tx = Repo.get_by!(Transaction, hash: tx.hash)
    propagations = Repo.all(
      from tp in TransactionPropagation,
      where: tp.transaction_id == ^stored_tx.id
    )

    max_propagations = Application.get_env(:p2p_monitor, :max_propagations_per_tx, 50)
    assert length(propagations) <= max_propagations
  end
end
```

#### 3. Property-Based Tests

Use StreamData/PropCheck for generative testing.

**Protocol Message Handling** (`test/property/protocol_test.exs`):
```elixir
defmodule P2PMonitor.Property.ProtocolTest do
  use ExUnit.Case
  use ExUnitProperties

  property "all valid ETH protocol messages can be encoded and decoded" do
    check all message <- eth_protocol_message() do
      encoded = Protocol.encode_message(message)
      assert {:ok, decoded} = Protocol.decode_message(encoded)
      assert messages_equivalent?(message, decoded)
    end
  end

  property "transaction hash is deterministic" do
    check all tx <- valid_transaction() do
      hash1 = TransactionParser.calculate_hash(tx)
      hash2 = TransactionParser.calculate_hash(tx)
      assert hash1 == hash2
      assert byte_size(hash1) == 32
    end
  end

  property "peer quality score stays within bounds" do
    check all events <- list_of(peer_event()) do
      score = PeerManager.calculate_quality_score(events)
      assert score >= 0.0 and score <= 1.0
    end
  end
end
```

#### 4. Database Tests

Test Ecto schemas and queries.

**Peer Schema** (`test/p2p_monitor/schemas/peer_test.exs`):
```elixir
defmodule P2PMonitor.Schemas.PeerTest do
  use P2PMonitor.DataCase, async: true

  alias P2PMonitor.Schemas.Peer

  describe "changeset/2" do
    test "valid peer data" do
      attrs = %{
        node_id: <<1, 2, 3>>,
        ip_address: "45.123.67.89",
        tcp_port: 30303,
        last_seen_at: DateTime.utc_now()
      }

      changeset = Peer.changeset(%Peer{}, attrs)
      assert changeset.valid?
    end

    test "requires node_id to be unique" do
      node_id = <<1, 2, 3>>
      create_peer(node_id: node_id)

      attrs = %{node_id: node_id, ip_address: "1.1.1.1", tcp_port: 30303}
      changeset = Peer.changeset(%Peer{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).node_id
    end

    test "validates IP address format" do
      attrs = %{node_id: <<1>>, ip_address: "invalid", tcp_port: 30303}
      changeset = Peer.changeset(%Peer{}, attrs)
      refute changeset.valid?
    end
  end

  describe "queries" do
    test "finds most active peers" do
      create_peer(transactions_count: 100)
      create_peer(transactions_count: 50)
      create_peer(transactions_count: 200)

      peers = Peer.most_active(limit: 2) |> Repo.all()
      assert length(peers) == 2
      assert hd(peers).transactions_count == 200
    end

    test "filters by country" do
      create_peer(country: "US")
      create_peer(country: "GB")
      create_peer(country: "US")

      us_peers = Peer.by_country("US") |> Repo.all()
      assert length(us_peers) == 2
    end
  end
end
```

**Transaction Attribution Queries** (`test/p2p_monitor/queries/transaction_attribution_test.exs`):
```elixir
defmodule P2PMonitor.Queries.TransactionAttributionTest do
  use P2PMonitor.DataCase, async: true

  test "finds transactions by peer" do
    peer = create_peer()
    tx1 = create_transaction(first_seen_peer_id: peer.id)
    tx2 = create_transaction(first_seen_peer_id: peer.id)
    _other_tx = create_transaction()

    txs = TransactionQueries.by_first_peer(peer.id) |> Repo.all()
    assert length(txs) == 2
    assert tx1.id in Enum.map(txs, & &1.id)
  end

  test "calculates average propagation time" do
    tx = create_transaction()
    create_propagation(transaction_id: tx.id, latency_from_first_ms: 100)
    create_propagation(transaction_id: tx.id, latency_from_first_ms: 200)
    create_propagation(transaction_id: tx.id, latency_from_first_ms: 150)

    avg = TransactionQueries.average_propagation_time() |> Repo.one()
    assert_in_delta avg, 150.0, 1.0
  end

  test "finds peers that are often first" do
    peer1 = create_peer()
    peer2 = create_peer()

    # peer1 is first 5 times
    for _ <- 1..5, do: create_transaction(first_seen_peer_id: peer1.id)
    # peer2 is first 2 times
    for _ <- 1..2, do: create_transaction(first_seen_peer_id: peer2.id)

    results = TransactionQueries.peers_often_first(limit: 1) |> Repo.all()
    assert length(results) == 1
    assert hd(results).peer_id == peer1.id
  end
end
```

#### 5. End-to-End Tests

Test complete workflows from peer connection to data storage.

**Complete Transaction Flow** (`test/e2e/transaction_flow_test.exs`):
```elixir
defmodule P2PMonitor.E2E.TransactionFlowTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  setup do
    # Start full application
    {:ok, _} = Application.ensure_all_started(:p2p_monitor)

    # Start mock Ethereum network with 3 peers
    {:ok, network} = MockEthereumNetwork.start_link(peer_count: 3)

    on_exit(fn ->
      MockEthereumNetwork.stop(network)
      Application.stop(:p2p_monitor)
    end)

    %{network: network}
  end

  test "detects transaction and attributes to correct peer", %{network: network} do
    # Create transaction on mock network
    tx = create_test_transaction()
    peer_id = MockEthereumNetwork.broadcast_transaction(network, tx, from_peer: 0)

    # Wait for detection
    assert_receive {:transaction_detected, detected_tx}, 5000

    # Verify in database with correct peer attribution
    Process.sleep(100)  # Allow time for DB write

    stored = Repo.get_by(Transaction, hash: tx.hash)
    assert stored != nil
    assert stored.first_seen_peer_ip != nil
    assert stored.seen_count >= 1
  end

  test "handles rapid transaction influx", %{network: network} do
    # Send 100 transactions rapidly
    txs = for i <- 1..100 do
      tx = create_test_transaction(nonce: i)
      MockEthereumNetwork.broadcast_transaction(network, tx)
      tx
    end

    # Wait for processing
    Process.sleep(2000)

    # Verify all stored
    stored_count = Repo.aggregate(Transaction, :count)
    assert stored_count >= 90  # Allow for some processing delay
  end

  test "tracks transaction propagation across peers", %{network: network} do
    tx = create_test_transaction()

    # Broadcast from first peer, should propagate to others
    MockEthereumNetwork.broadcast_transaction(network, tx, from_peer: 0)

    # Wait for propagation
    Process.sleep(1000)

    # Verify multiple propagations recorded
    stored = Repo.get_by(Transaction, hash: tx.hash)
    propagations = Repo.all(
      from tp in TransactionPropagation,
      where: tp.transaction_id == ^stored.id
    )

    # Should see from multiple peers
    assert length(propagations) >= 2

    # Verify latencies are calculated
    assert Enum.all?(propagations, fn p -> p.latency_from_first_ms >= 0 end)
  end
end
```

#### 6. Performance Tests

Validate performance under load.

**Load Testing** (`test/performance/load_test.exs`):
```elixir
defmodule P2PMonitor.Performance.LoadTest do
  use ExUnit.Case

  @moduletag :performance
  @moduletag timeout: 120_000

  test "handles 1000 transactions per second" do
    # Setup
    start_supervised!(TransactionHandler)

    # Generate 10,000 transactions
    transactions = for i <- 1..10_000 do
      create_test_transaction(nonce: i)
    end

    # Measure processing time
    start_time = System.monotonic_time(:millisecond)

    # Process all transactions
    Enum.each(transactions, fn tx ->
      peer = %{id: <<1>>, ip: "1.1.1.1", port: 30303}
      TransactionHandler.process_transaction(tx, peer)
    end)

    # Wait for queue to empty
    :sys.get_state(TransactionHandler)

    end_time = System.monotonic_time(:millisecond)
    duration_seconds = (end_time - start_time) / 1000

    throughput = 10_000 / duration_seconds

    IO.puts("Throughput: #{throughput} tx/sec")
    assert throughput >= 1000
  end

  test "maintains 50 concurrent peer connections" do
    # Start 50 mock peers
    peers = for i <- 1..50 do
      {:ok, peer} = MockEthereumPeer.start_link(port: 30400 + i)
      peer
    end

    # Connect to all peers
    connections = Enum.map(peers, fn peer ->
      peer_info = MockEthereumPeer.info(peer)
      {:ok, conn} = PeerConnection.start_link(peer_info)
      conn
    end)

    # Verify all connected
    Process.sleep(2000)

    connected_count = Enum.count(connections, fn conn ->
      state = :sys.get_state(conn)
      state.status == :connected
    end)

    assert connected_count >= 45  # 90% success rate

    # Measure memory usage
    memory_mb = :erlang.memory(:total) / 1_024 / 1_024
    IO.puts("Memory usage: #{memory_mb} MB")
    assert memory_mb < 500
  end

  test "peer lookup performance with large peer table" do
    # Insert 10,000 peers
    for i <- 1..10_000 do
      peer = %Peer{
        id: <<i::256>>,
        ip: {192, 168, div(i, 256), rem(i, 256)},
        tcp_port: 30303
      }
      PeerTracker.register(peer)
    end

    # Measure lookup time
    iterations = 1000
    peer_ids = Enum.map(1..iterations, fn i -> <<i::256>> end)

    {time_us, _} = :timer.tc(fn ->
      Enum.each(peer_ids, fn id ->
        PeerTracker.get(id)
      end)
    end)

    avg_lookup_us = time_us / iterations
    IO.puts("Average lookup time: #{avg_lookup_us} μs")

    # Should be < 100μs per lookup
    assert avg_lookup_us < 100
  end
end
```

#### 7. Security Tests

Test resilience against malicious inputs.

**Malicious Peer Tests** (`test/security/malicious_peer_test.exs`):
```elixir
defmodule P2PMonitor.Security.MaliciousPeerTest do
  use ExUnit.Case

  @moduletag :security

  test "rejects invalid RLP encoding" do
    malformed_data = <<0xFF, 0xFF, 0xFF, 0xFF>>

    assert {:error, :invalid_rlp} = Protocol.decode_message(malformed_data)

    # Verify system remains stable
    assert Process.whereis(TransactionHandler) != nil
  end

  test "rejects transaction with invalid signature" do
    tx = %{
      nonce: 0,
      gas_price: 1000,
      gas_limit: 21000,
      to: <<1, 2, 3>>,
      value: 100,
      data: <<>>,
      v: 27,
      r: 0,  # Invalid
      s: 0   # Invalid
    }

    assert {:error, :invalid_signature} = TransactionParser.parse(tx)
  end

  test "rate limits excessive messages from single peer" do
    peer_info = %{id: <<1>>, ip: "1.1.1.1", port: 30303}

    # Send 1000 messages rapidly
    results = for _ <- 1..1000 do
      PeerConnection.handle_message(peer_info, create_test_message())
    end

    # Some should be rate limited
    rate_limited = Enum.count(results, fn r -> r == {:error, :rate_limited} end)
    assert rate_limited > 0
  end

  test "disconnects peer sending invalid transactions repeatedly" do
    {:ok, conn} = PeerConnection.start_link(%{ip: {127, 0, 0, 1}, port: 30304})

    # Send 10 invalid transactions
    for _ <- 1..10 do
      invalid_tx = create_invalid_transaction()
      send(conn, {:eth_message, :transactions, [invalid_tx]})
      Process.sleep(10)
    end

    # Peer should be disconnected
    Process.sleep(100)
    refute Process.alive?(conn)
  end

  test "validates peer IP addresses" do
    # Private/local IPs should be rejected in production
    invalid_ips = [
      {127, 0, 0, 1},      # Localhost
      {192, 168, 1, 1},    # Private
      {10, 0, 0, 1},       # Private
      {0, 0, 0, 0}         # Invalid
    ]

    for ip <- invalid_ips do
      peer = %{ip: ip, port: 30303}
      result = PeerManager.validate_peer(peer)
      assert result == {:error, :invalid_ip}
    end
  end
end
```

#### 8. GeoIP Tests

Test geographic location features.

**GeoIP Integration** (`test/p2p_monitor/geoip_test.exs`):
```elixir
defmodule P2PMonitor.GeoIPTest do
  use ExUnit.Case

  @moduletag :geoip

  setup do
    # Ensure GeoIP database is loaded
    Application.ensure_all_started(:geolix)
    :ok
  end

  test "resolves known IP to location" do
    # Google DNS
    ip = "8.8.8.8"

    assert {:ok, location} = GeoIP.lookup(ip)
    assert location.country == "US"
    assert location.latitude != nil
    assert location.longitude != nil
  end

  test "handles unknown IP gracefully" do
    # Private IP
    ip = "192.168.1.1"

    assert {:ok, location} = GeoIP.lookup(ip)
    assert location.country == nil
  end

  test "caches lookups for performance" do
    ip = "8.8.8.8"

    # First lookup
    {time1, _} = :timer.tc(fn -> GeoIP.lookup(ip) end)

    # Cached lookup
    {time2, _} = :timer.tc(fn -> GeoIP.lookup(ip) end)

    # Cached should be much faster
    assert time2 < time1 / 10
  end
end
```

### Testing Tools and Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # Testing
    {:ex_unit, "~> 1.15", only: :test},
    {:stream_data, "~> 0.6", only: :test},
    {:mox, "~> 1.0", only: :test},
    {:bypass, "~> 2.1", only: :test},
    {:faker, "~> 0.18", only: :test},
    {:excoveralls, "~> 0.18", only: :test},
    {:benchee, "~> 1.1", only: [:dev, :test]},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},  # Security analysis
    {:doctor, "~> 0.21", only: :dev},  # Documentation coverage
  ]
end
```

### Test Helpers and Factories

**Test Factory** (`test/support/factory.ex`):
```elixir
defmodule P2PMonitor.Factory do
  alias P2PMonitor.Schemas.{Peer, Transaction, TransactionPropagation}

  def create_peer(attrs \\ %{}) do
    defaults = %{
      node_id: :crypto.strong_rand_bytes(64),
      ip_address: Faker.Internet.ip_v4_address(),
      tcp_port: 30303,
      last_seen_at: DateTime.utc_now(),
      transactions_count: 0
    }

    attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    %Peer{}
    |> Peer.changeset(attrs)
    |> Repo.insert!()
  end

  def create_transaction(attrs \\ %{}) do
    defaults = %{
      hash: :crypto.strong_rand_bytes(32),
      from_address: :crypto.strong_rand_bytes(20),
      to_address: :crypto.strong_rand_bytes(20),
      value: Enum.random(0..1_000_000_000_000_000_000),
      gas_limit: 21_000,
      gas_price: 20_000_000_000,
      nonce: Enum.random(0..1000),
      data: <<>>,
      tx_type: "legacy",
      first_seen_at: DateTime.utc_now(),
      first_seen_peer_ip: Faker.Internet.ip_v4_address(),
      seen_count: 1
    }

    attrs = Map.merge(defaults, Enum.into(attrs, %{}))

    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert!()
  end

  def create_test_transaction(attrs \\ %{}) do
    # For in-memory testing (not database)
    defaults = %{
      hash: :crypto.strong_rand_bytes(32),
      from: :crypto.strong_rand_bytes(20),
      to: :crypto.strong_rand_bytes(20),
      value: 1_000_000_000_000_000_000,
      gas_limit: 21_000,
      gas_price: 20_000_000_000,
      nonce: 0,
      data: <<>>,
      type: :legacy,
      v: 27,
      r: :crypto.strong_rand_bytes(32),
      s: :crypto.strong_rand_bytes(32)
    }

    Map.merge(defaults, Enum.into(attrs, %{}))
  end
end
```

### Continuous Integration

**`.github/workflows/test.yml`**:
```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'

      - name: Cache deps
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Run tests
        run: mix test --cover

      - name: Upload coverage
        run: mix coveralls.github
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run Credo
        run: mix credo --strict

      - name: Run Dialyzer
        run: mix dialyzer

      - name: Run Security Checks
        run: mix sobelow --config
```

### Test Execution Strategy

**Run different test suites:**
```bash
# All tests
mix test

# Unit tests only
mix test test/p2p_monitor/

# Integration tests
mix test test/integration/ --include integration

# E2E tests (slower)
mix test test/e2e/ --include e2e

# Performance tests
mix test test/performance/ --include performance

# Security tests
mix test test/security/ --include security

# Coverage report
mix test --cover
mix coveralls.html

# Specific module
mix test test/p2p_monitor/crypto_test.exs

# Watch mode during development
mix test.watch
```

### Test Quality Metrics

Track these metrics in CI:

1. **Code Coverage**: Minimum 80% overall, 95% for critical paths
2. **Test Count**: Track growth of test suite
3. **Test Duration**: Monitor for slow tests (warn if > 5 seconds)
4. **Flaky Tests**: Track intermittent failures
5. **Property Test Iterations**: Default 100, increase for release builds

### Documentation Testing

Use ExDoc with doctests:

```elixir
defmodule P2PMonitor.Crypto do
  @doc """
  Calculates Keccak-256 hash.

  ## Examples

      iex> P2PMonitor.Crypto.keccak256("hello")
      <<0x1C, 0x8A, 0xFF, ...>>

      iex> P2PMonitor.Crypto.keccak256("")
      <<0xC5, 0xD2, 0x46, ...>>
  """
  def keccak256(data), do: ...
end
```

Run doctests:
```bash
mix test --only doctest
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Implementation:**
- [ ] Project setup and mix dependencies
- [ ] RLP encoding/decoding utilities
- [ ] Basic cryptography utilities (Keccak, secp256k1)
- [ ] Network configuration management

**Testing:**
- [ ] Unit tests for RLP encode/decode with known Ethereum data
- [ ] Property-based tests for RLP roundtrip encoding
- [ ] Unit tests for cryptography functions (Keccak, ECDSA)
- [ ] Test helpers and factory setup
- [ ] CI/CD pipeline setup (GitHub Actions)

### Phase 2: Node Discovery (Week 2-3)
**Implementation:**
- [ ] UDP-based discovery protocol
- [ ] Kademlia DHT implementation
- [ ] Boot node connectivity
- [ ] Peer database/routing table

**Testing:**
- [ ] Unit tests for discovery message encoding/decoding
- [ ] Unit tests for Kademlia distance calculation
- [ ] Integration tests with mock UDP peers
- [ ] Test peer table operations (add, remove, lookup)
- [ ] Property tests for distance and bucket operations

### Phase 3: RLPx Protocol (Week 3-4)
**Implementation:**
- [ ] RLPx handshake (ECIES encryption)
- [ ] Frame encoding/decoding
- [ ] MAC authentication
- [ ] Connection management

**Testing:**
- [ ] Unit tests for ECIES encryption/decryption
- [ ] Unit tests for frame encoding/decoding
- [ ] Unit tests for MAC generation and validation
- [ ] Integration tests with mock RLPx peer
- [ ] Security tests for invalid/malformed frames
- [ ] Test connection lifecycle (connect, disconnect, timeout)

### Phase 4: ETH Wire Protocol (Week 4-5)
**Implementation:**
- [ ] Protocol handshake and capability negotiation
- [ ] Message type handlers
- [ ] Transaction pool sync
- [ ] Peer connection GenServer
- [ ] **IP address and port capture** from socket
- [ ] **Peer metadata storage** in ETS

**Testing:**
- [ ] Unit tests for ETH protocol message encoding/decoding
- [ ] Unit tests for peer IP extraction from socket
- [ ] Integration tests for full peer connection lifecycle
- [ ] Test IP address capture and storage
- [ ] Test peer metadata persistence in ETS
- [ ] Mock Ethereum peer for integration tests
- [ ] Test rate limiting and peer disconnection

### Phase 5: Transaction Processing (Week 5-6)
**Implementation:**
- [ ] Transaction parser
- [ ] Signature recovery (derive from address)
- [ ] Deduplication logic with peer tracking
- [ ] GenStage pipeline
- [ ] **Peer attribution tracking** in transaction handler
- [ ] **Transaction propagation metrics** calculation

**Testing:**
- [ ] Unit tests for transaction parsing (legacy, EIP-1559, EIP-2930)
- [ ] Unit tests for signature recovery with known transactions
- [ ] Unit tests for peer attribution tracking
- [ ] Integration tests for transaction deduplication
- [ ] Integration tests for propagation latency calculation
- [ ] Test handling transactions from multiple peers
- [ ] Property tests for transaction hash determinism
- [ ] Test max propagations limit enforcement
- [ ] Performance tests for transaction throughput (1000+ tx/sec)

### Phase 6: Output & Storage (Week 6-7)
**Implementation:**
- [ ] Console logger with peer information
- [ ] Database schema for peers, transactions, and propagations
- [ ] Ecto schemas and changesets
- [ ] **Peer metadata persistence** (IP, location, metrics)
- [ ] **Transaction-to-peer relationship** storage
- [ ] Filtering rules
- [ ] Performance optimization
- [ ] **GeoIP integration** (optional)

**Testing:**
- [ ] Unit tests for Ecto schemas and changesets
- [ ] Unit tests for validation (IP format, unique constraints)
- [ ] Database tests for peer queries (most active, by country)
- [ ] Database tests for transaction attribution queries
- [ ] Integration tests for full transaction flow to database
- [ ] Test GeoIP lookup and caching
- [ ] Test console output formatting
- [ ] Performance tests for database operations
- [ ] Test filtering rules and configurations

### Phase 7: Monitoring & Ops (Week 7-8)
**Implementation:**
- [ ] Telemetry metrics
- [ ] Health checks
- [ ] Graceful shutdown
- [ ] Documentation

**Testing:**
- [ ] E2E tests with full application and mock network
- [ ] E2E tests for transaction propagation tracking
- [ ] Performance tests for 50+ concurrent peer connections
- [ ] Performance tests for large peer table (10,000+ peers)
- [ ] Load tests for rapid transaction influx
- [ ] Security tests for malicious peers
- [ ] Security tests for invalid data handling
- [ ] Test graceful shutdown and cleanup
- [ ] Verify telemetry metrics are emitted
- [ ] Documentation tests (doctests)
- [ ] Final coverage report (target 80%+ overall, 95%+ critical)

### Phase 8: QA and Hardening (Week 8-9)
**Focus: Testing and Refinement**
- [ ] Run full test suite on CI
- [ ] Property-based testing with increased iterations (10,000+)
- [ ] Chaos testing (random peer disconnections, network delays)
- [ ] Memory leak detection (run for extended periods)
- [ ] Security audit with Sobelow
- [ ] Load testing on realistic network conditions
- [ ] Fix all critical bugs and test failures
- [ ] Achieve test coverage targets
- [ ] Performance profiling and optimization
- [ ] Documentation review and completion

## Challenges and Considerations

### Technical Challenges

1. **Protocol Complexity**: Ethereum's DevP2P is complex with RLPx encryption, capability negotiation, and multiple sub-protocols
2. **Transaction Volume**: Mainnet can have very high transaction throughput requiring efficient processing
3. **Peer Management**: Maintaining healthy connections with diverse peers across the network
4. **State Synchronization**: Even as a lightweight node, some state awareness is needed
5. **Testing Complexity**: Testing P2P networking code requires:
   - Mock Ethereum peers that accurately simulate protocol behavior
   - Network simulation for testing propagation timing
   - Generating valid cryptographic signatures for test transactions
   - Managing concurrent processes in tests
   - Testing timing-dependent behavior (propagation latency) reliably

### Design Decisions

1. **No Block Sync**: This is a transaction monitor only - no block synchronization or state storage
2. **Mempool Focus**: Only track pending transactions in the mempool, not historical data
3. **Read-Only**: No transaction broadcasting or mining capabilities
4. **Stateless**: Minimal state beyond active connections and recent transaction cache

### Security Considerations

1. **Input Validation**: All network data must be validated and sanitized
2. **Resource Limits**: Implement limits on memory usage, connection counts, and message rates
3. **Peer Reputation**: Track peer behavior and disconnect from misbehaving nodes
4. **DoS Protection**: Rate limiting and connection throttling

## Success Metrics

### Operational Metrics
1. **Connectivity**: Successfully maintain 25+ peer connections
2. **Coverage**: Detect 90%+ of transactions that eventually get mined
3. **Latency**: Report transactions within 500ms of network propagation
4. **Stability**: Run continuously for 24+ hours without crashes
5. **Performance**: Use <500MB RAM and <10% CPU under normal load

### Testing and Quality Metrics
6. **Test Coverage**: Achieve 80%+ overall code coverage, 95%+ on critical paths
7. **Test Suite Size**: Maintain 200+ test cases across all layers
8. **Test Performance**: Full test suite completes in <5 minutes
9. **CI/CD**: All tests pass on CI before merge
10. **Zero Critical Security Issues**: Pass Sobelow security audit
11. **Type Safety**: Zero Dialyzer warnings on release builds

## Future Enhancements

1. **Advanced Filtering**: Smart contract event decoding, MEV detection
2. **Historical Data**: Transaction database with queryable API
3. **Web Dashboard**: Real-time visualization of network activity
   - Geographic map showing peer locations
   - Transaction propagation visualization
   - Network topology graph
   - Live peer connection status
4. **Multiple Networks**: Simultaneous monitoring of multiple chains
5. **Analytics**:
   - Gas price trends and prediction
   - Transaction pattern analysis
   - **Peer reputation scoring system**
   - **Network topology analysis**
   - **Transaction propagation heatmaps**
   - **Geographic distribution reports**
   - **Peer performance benchmarking**
6. **Alerts**: Webhook notifications for specific transaction patterns
   - Alert when specific peer sends high-value transactions
   - Anomaly detection in propagation patterns
7. **Peer Intelligence**:
   - Identify and track known MEV bots by peer signature
   - Detect validator nodes vs full nodes
   - Map relationships between peers
8. **Export Capabilities**:
   - CSV export of peer statistics
   - Transaction propagation timeline exports
   - Network graph data export for external analysis

## References

- [Ethereum DevP2P Specification](https://github.com/ethereum/devp2p)
- [ETH Wire Protocol (ETH/68)](https://github.com/ethereum/devp2p/blob/master/caps/eth.md)
- [RLPx Transport Protocol](https://github.com/ethereum/devp2p/blob/master/rlpx.md)
- [Node Discovery Protocol v4](https://github.com/ethereum/devp2p/blob/master/discv4.md)
- [EIP-1559 Transaction Type](https://eips.ethereum.org/EIPS/eip-1559)
- [Transaction Structure](https://ethereum.org/en/developers/docs/transactions/)
