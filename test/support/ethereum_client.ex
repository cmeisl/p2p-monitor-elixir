defmodule P2PMonitor.Test.EthereumClient do
  @moduledoc """
  Helper module for fetching real Ethereum transaction data for integration tests.
  
  ## Usage
  
  ### Fetch transaction by hash:
  
      {:ok, tx_data} = EthereumClient.get_transaction("0x123...")
  
  ### Fetch raw transaction data:
  
      {:ok, raw_tx} = EthereumClient.get_raw_transaction("0x123...")
  
  ## Configuration
  
  Set these environment variables for API access:
  
  - `ETHEREUM_RPC_URL` - Your Ethereum RPC endpoint (default: public endpoint)
  - `ETHERSCAN_API_KEY` - Your Etherscan API key (optional, for higher rate limits)
  
  ## Using Public RPC Endpoints
  
  Free public endpoints (no API key needed):
  - Mainnet: https://eth.llamarpc.com
  - Sepolia: https://sepolia.gateway.tenderly.co
  - Holesky: https://ethereum-holesky.publicnode.com
  
  ## Using Etherscan API
  
  Get a free API key at https://etherscan.io/apis
  """
  
  @type tx_hash :: String.t()
  @type network :: :mainnet | :sepolia | :holesky
  
  @doc """
  Fetches raw transaction bytes by transaction hash.
  
  Returns the RLP-encoded transaction data.
  
  Note: Uses eth_getBlockByNumber + transaction index since eth_getRawTransactionByHash
  is not widely supported by public RPC endpoints.
  """
  @spec get_raw_transaction(tx_hash(), network()) :: {:ok, binary()} | {:error, term()}
  def get_raw_transaction(tx_hash, network \\ :mainnet) do
    # First, get the transaction to find its block
    with {:ok, tx} <- get_transaction(tx_hash, network),
         block_number when is_binary(block_number) <- tx["blockNumber"],
         tx_index when is_binary(tx_index) <- tx["transactionIndex"] do
      # Get the block with full transactions
      get_raw_transaction_from_block(block_number, tx_index, network)
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :transaction_not_found}
      _ -> {:error, :invalid_transaction_data}
    end
  end
  
  defp get_raw_transaction_from_block(block_number, tx_index, network) do
    rpc_url = get_rpc_url(network)
    
    # Convert hex index to integer
    index = hex_to_integer(tx_index)
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_getBlockByNumber",
      params: [block_number, true],  # true = include full transaction objects
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => %{"transactions" => txs}}} when is_list(txs) ->
        case Enum.at(txs, index) do
          nil -> {:error, :transaction_not_found_in_block}
          tx -> encode_transaction_from_json(tx)
        end
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp encode_transaction_from_json(tx) do
    # Convert JSON transaction to RLP-encoded format
    # This requires reconstructing the transaction from its fields
    
    # Determine transaction type
    type = case tx["type"] do
      "0x0" -> :legacy
      "0x1" -> :eip2930
      "0x2" -> :eip1559
      "0x3" -> :eip4844
      _ -> :legacy
    end
    
    # Build transaction map
    tx_map = %{
      type: type,
      nonce: hex_to_integer(tx["nonce"]),
      gas_limit: hex_to_integer(tx["gas"]),
      to: hex_to_binary(tx["to"] || "0x"),
      value: hex_to_integer(tx["value"]),
      data: hex_to_binary(tx["input"]),
      v: calculate_v_from_json(tx),
      r: hex_to_integer(tx["r"]),
      s: hex_to_integer(tx["s"])
    }
    
    # Add type-specific fields
    tx_map = case type do
      :legacy ->
        Map.put(tx_map, :gas_price, hex_to_integer(tx["gasPrice"]))
        
      :eip2930 ->
        tx_map
        |> Map.put(:chain_id, hex_to_integer(tx["chainId"] || "0x1"))
        |> Map.put(:gas_price, hex_to_integer(tx["gasPrice"]))
        |> Map.put(:access_list, parse_access_list(tx["accessList"] || []))
        
      :eip1559 ->
        tx_map
        |> Map.put(:chain_id, hex_to_integer(tx["chainId"] || "0x1"))
        |> Map.put(:max_priority_fee_per_gas, hex_to_integer(tx["maxPriorityFeePerGas"]))
        |> Map.put(:max_fee_per_gas, hex_to_integer(tx["maxFeePerGas"]))
        |> Map.put(:access_list, parse_access_list(tx["accessList"] || []))
        
      :eip4844 ->
        tx_map
        |> Map.put(:chain_id, hex_to_integer(tx["chainId"] || "0x1"))
        |> Map.put(:max_priority_fee_per_gas, hex_to_integer(tx["maxPriorityFeePerGas"]))
        |> Map.put(:max_fee_per_gas, hex_to_integer(tx["maxFeePerGas"]))
        |> Map.put(:access_list, parse_access_list(tx["accessList"] || []))
        |> Map.put(:max_fee_per_blob_gas, hex_to_integer(tx["maxFeePerBlobGas"] || "0x0"))
        |> Map.put(:blob_versioned_hashes, parse_blob_hashes(tx["blobVersionedHashes"] || []))
    end
    
    # Encode using our RLP encoder
    encoded = P2PMonitor.RLP.Encoder.encode_transaction(tx_map)
    {:ok, encoded}
  rescue
    e -> {:error, {:encoding_failed, e}}
  end
  
  defp calculate_v_from_json(tx) do
    # The v value in JSON might be in different formats
    # For EIP-155, it's chainId * 2 + 35 + {0, 1}
    # For pre-EIP-155, it's 27 or 28
    hex_to_integer(tx["v"])
  end
  
  defp parse_access_list(list) when is_list(list) do
    Enum.map(list, fn item ->
      %{
        address: hex_to_binary(item["address"]),
        storage_keys: Enum.map(item["storageKeys"] || [], &hex_to_binary/1)
      }
    end)
  end
  defp parse_access_list(_), do: []
  
  defp parse_blob_hashes(list) when is_list(list) do
    Enum.map(list, &hex_to_binary/1)
  end
  defp parse_blob_hashes(_), do: []
  
  @doc """
  Fetches transaction details by hash.
  
  Returns full transaction information including receipt.
  """
  @spec get_transaction(tx_hash(), network()) :: {:ok, map()} | {:error, term()}
  def get_transaction(tx_hash, network \\ :mainnet) do
    rpc_url = get_rpc_url(network)
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_getTransactionByHash",
      params: [tx_hash],
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => tx}} when is_map(tx) ->
        {:ok, tx}
        
      {:ok, %{"result" => nil}} ->
        {:error, :transaction_not_found}
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Fetches transaction receipt by hash.
  """
  @spec get_transaction_receipt(tx_hash(), network()) :: {:ok, map()} | {:error, term()}
  def get_transaction_receipt(tx_hash, network \\ :mainnet) do
    rpc_url = get_rpc_url(network)
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_getTransactionReceipt",
      params: [tx_hash],
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => receipt}} when is_map(receipt) ->
        {:ok, receipt}
        
      {:ok, %{"result" => nil}} ->
        {:error, :receipt_not_found}
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Gets the latest block number.
  """
  @spec get_latest_block(network()) :: {:ok, integer()} | {:error, term()}
  def get_latest_block(network \\ :mainnet) do
    rpc_url = get_rpc_url(network)
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_blockNumber",
      params: [],
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => block_hex}} ->
        block_number = hex_to_integer(block_hex)
        {:ok, block_number}
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Fetches transactions from a specific block.
  """
  @spec get_block_transactions(integer() | String.t(), network()) :: {:ok, [map()]} | {:error, term()}
  def get_block_transactions(block_number, network \\ :mainnet) do
    rpc_url = get_rpc_url(network)
    
    block_param = if is_integer(block_number) do
      "0x" <> Integer.to_string(block_number, 16)
    else
      block_number
    end
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_getBlockByNumber",
      params: [block_param, true],  # true = include full transaction objects
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => %{"transactions" => txs}}} when is_list(txs) ->
        {:ok, txs}
        
      {:ok, %{"result" => nil}} ->
        {:error, :block_not_found}
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private functions
  
  defp get_rpc_url(:mainnet) do
    System.get_env("ETHEREUM_RPC_URL") || "https://eth.llamarpc.com"
  end
  
  defp get_rpc_url(:sepolia) do
    System.get_env("SEPOLIA_RPC_URL") || "https://sepolia.gateway.tenderly.co"
  end
  
  defp get_rpc_url(:holesky) do
    System.get_env("HOLESKY_RPC_URL") || "https://ethereum-holesky.publicnode.com"
  end
  
  defp http_post(url, payload) do
    headers = [{~c"content-type", ~c"application/json"}]
    body = Jason.encode!(payload)
    
    case :httpc.request(:post, {String.to_charlist(url), headers, ~c"application/json", String.to_charlist(body)}, [], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        {:ok, Jason.decode!(to_string(response_body))}
        
      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:http_error, status, to_string(response_body)}}
        
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end
  
  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(hex), do: String.to_integer(hex, 16)
  
  defp hex_to_binary("0x" <> hex), do: hex_to_binary(hex)
  defp hex_to_binary(""), do: <<>>
  defp hex_to_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} -> binary
      :error -> <<>>
    end
  end
end
