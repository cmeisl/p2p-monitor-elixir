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
  """
  @spec get_raw_transaction(tx_hash(), network()) :: {:ok, binary()} | {:error, term()}
  def get_raw_transaction(tx_hash, network \\ :mainnet) do
    rpc_url = get_rpc_url(network)
    
    payload = %{
      jsonrpc: "2.0",
      method: "eth_getRawTransactionByHash",
      params: [tx_hash],
      id: 1
    }
    
    case http_post(rpc_url, payload) do
      {:ok, %{"result" => raw_tx}} when is_binary(raw_tx) ->
        # Remove 0x prefix and decode hex
        raw_tx
        |> String.replace_prefix("0x", "")
        |> Base.decode16(case: :mixed)
        
      {:ok, %{"error" => error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
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
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(payload)
    
    case :httpc.request(:post, {String.to_charlist(url), headers, ~c"application/json", body}, [], []) do
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
end
