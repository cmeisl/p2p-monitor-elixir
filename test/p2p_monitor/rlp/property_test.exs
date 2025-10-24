defmodule P2PMonitor.RLP.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias P2PMonitor.RLP.{Encoder, Decoder}

  @moduledoc """
  Property-based tests for RLP encoding/decoding.
  These tests verify that encoding and decoding are inverse operations
  for all valid inputs.
  """

  describe "RLP encoding/decoding properties" do
    property "encode then decode returns original binary" do
      check all binary <- binary(min_length: 0, max_length: 200) do
        encoded = Encoder.encode(binary)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == binary
      end
    end

    property "encode then decode returns original for small integers" do
      check all int <- integer(0..1000) do
        encoded = Encoder.encode(int)
        assert {:ok, decoded_binary} = Decoder.decode(encoded)
        
        # Convert decoded binary back to integer
        decoded_int = case decoded_binary do
          "" -> 0
          bin when is_binary(bin) -> :binary.decode_unsigned(bin, :big)
        end
        
        assert decoded_int == int
      end
    end

    property "encode then decode returns original for lists of binaries" do
      check all list <- list_of(binary(min_length: 0, max_length: 50), min_length: 0, max_length: 20) do
        encoded = Encoder.encode(list)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == list
      end
    end

    property "encode then decode is idempotent for binaries" do
      check all binary <- binary(min_length: 0, max_length: 100) do
        encoded1 = Encoder.encode(binary)
        {:ok, decoded1} = Decoder.decode(encoded1)
        
        encoded2 = Encoder.encode(decoded1)
        {:ok, decoded2} = Decoder.decode(encoded2)
        
        assert decoded1 == decoded2
        assert encoded1 == encoded2
      end
    end

    property "encoding is deterministic" do
      check all binary <- binary(min_length: 0, max_length: 100) do
        encoded1 = Encoder.encode(binary)
        encoded2 = Encoder.encode(binary)
        
        assert encoded1 == encoded2
      end
    end

    property "encoded length is related to input length" do
      check all binary <- binary(min_length: 1, max_length: 100) do
        encoded = Encoder.encode(binary)
        
        # Encoded size should be at most input size + small overhead
        # For strings < 56 bytes: overhead is 1 byte
        # For strings >= 56 bytes: overhead is 1-9 bytes
        max_overhead = if byte_size(binary) < 56, do: 1, else: 9
        
        assert byte_size(encoded) <= byte_size(binary) + max_overhead
        assert byte_size(encoded) >= byte_size(binary)
      end
    end

    property "empty collections have specific encodings" do
      check all _iteration <- integer(1..100) do
        # Empty string always encodes to 0x80
        assert Encoder.encode(<<>>) == <<0x80>>
        assert Encoder.encode("") == <<0x80>>
        assert Encoder.encode(0) == <<0x80>>
        
        # Empty list always encodes to 0xC0
        assert Encoder.encode([]) == <<0xC0>>
      end
    end

    property "single bytes less than 0x80 encode to themselves" do
      check all byte <- integer(0..127) do
        encoded = Encoder.encode(<<byte>>)
        assert encoded == <<byte>>
      end
    end

    property "nested lists roundtrip correctly" do
      check all depth <- integer(1..5),
                inner <- binary(min_length: 0, max_length: 10) do
        # Create nested structure
        nested = nest_data(inner, depth)
        
        encoded = Encoder.encode(nested)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == nested
      end
    end

    property "mixed lists roundtrip correctly" do
      check all binaries <- list_of(binary(min_length: 0, max_length: 20), min_length: 0, max_length: 10),
                nested_lists <- list_of(list_of(binary(min_length: 0, max_length: 10), min_length: 0, max_length: 3), min_length: 0, max_length: 3) do
        mixed_list = binaries ++ nested_lists
        
        encoded = Encoder.encode(mixed_list)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == mixed_list
      end
    end

    property "encoding preserves list length" do
      check all list <- list_of(binary(min_length: 0, max_length: 20), min_length: 0, max_length: 50) do
        encoded = Encoder.encode(list)
        {:ok, decoded} = Decoder.decode(encoded)
        
        assert length(decoded) == length(list)
      end
    end

    property "decoding never crashes on random data" do
      check all random_data <- binary(min_length: 1, max_length: 100) do
        # Decoder should either succeed or return error, never crash
        case Decoder.decode(random_data) do
          {:ok, _} -> true
          {:error, :invalid_rlp} -> true
          other -> flunk("Unexpected decoder result: #{inspect(other)}")
        end
      end
    end

    property "encoded data is never empty for non-empty input" do
      check all binary <- binary(min_length: 1, max_length: 100) do
        encoded = Encoder.encode(binary)
        assert byte_size(encoded) > 0
      end
    end

    property "list encoding preserves element order" do
      check all list <- list_of(binary(min_length: 1, max_length: 10), min_length: 2, max_length: 10) do
        encoded = Encoder.encode(list)
        {:ok, decoded} = Decoder.decode(encoded)
        
        assert decoded == list
        # Verify each element matches
        Enum.zip(list, decoded)
        |> Enum.each(fn {original, decoded_elem} ->
          assert original == decoded_elem
        end)
      end
    end
  end

  describe "Transaction encoding/decoding properties" do
    property "legacy transaction roundtrips preserve key fields" do
      check all nonce <- integer(0..1000),
                gas_price <- integer(1..100_000_000_000),
                gas_limit <- integer(21_000..1_000_000),
                value <- integer(0..1_000_000_000_000_000_000) do
        tx = %{
          type: :legacy,
          nonce: nonce,
          gas_price: gas_price,
          gas_limit: gas_limit,
          to: <<0x12, 0x34>>,
          value: value,
          data: <<>>
        }
        
        encoded = Encoder.encode_transaction(tx)
        assert {:ok, decoded} = Decoder.decode_transaction(encoded)
        
        assert decoded.type == :legacy
        assert decoded.nonce == nonce
        assert decoded.gas_price == gas_price
        assert decoded.gas_limit == gas_limit
        assert decoded.value == value
      end
    end

    property "EIP-1559 transaction roundtrips correctly" do
      check all nonce <- integer(0..100),
                max_fee <- integer(1..50_000_000_000),
                max_priority_fee <- integer(1..10_000_000_000),
                value <- integer(0..1_000_000_000_000_000) do
        tx = %{
          type: :eip1559,
          chain_id: 1,
          nonce: nonce,
          max_fee_per_gas: max_fee,
          max_priority_fee_per_gas: max_priority_fee,
          gas_limit: 21_000,
          to: <<0x12, 0x34>>,
          value: value,
          data: <<>>,
          access_list: []
        }
        
        encoded = Encoder.encode_transaction(tx)
        assert {:ok, decoded} = Decoder.decode_transaction(encoded)
        
        assert decoded.type == :eip1559
        assert decoded.nonce == nonce
        assert decoded.max_fee_per_gas == max_fee
        assert decoded.max_priority_fee_per_gas == max_priority_fee
      end
    end

    property "transaction with signature roundtrips" do
      check all nonce <- integer(0..100),
                v <- integer(27..28),
                r <- integer(1..100_000),
                s <- integer(1..100_000) do
        tx = %{
          type: :legacy,
          nonce: nonce,
          gas_price: 20_000_000_000,
          gas_limit: 21_000,
          to: <<0x12, 0x34>>,
          value: 0,
          data: <<>>,
          v: v,
          r: r,
          s: s
        }
        
        encoded = Encoder.encode_transaction(tx)
        assert {:ok, decoded} = Decoder.decode_transaction(encoded)
        
        assert decoded.v == v
        assert decoded.r == r
        assert decoded.s == s
      end
    end

    property "transaction encoding never crashes" do
      check all nonce <- integer(0..1000),
                gas_price <- integer(0..100_000_000_000),
                gas_limit <- integer(0..10_000_000),
                value <- integer(0..0xFFFFFFFFFFFFFFFF) do
        tx = %{
          type: :legacy,
          nonce: nonce,
          gas_price: gas_price,
          gas_limit: gas_limit,
          to: <<>>,
          value: value,
          data: <<>>
        }
        
        # Should never crash
        encoded = Encoder.encode_transaction(tx)
        assert is_binary(encoded)
      end
    end
  end

  describe "Integer encoding properties" do
    property "large integers encode without leading zeros" do
      check all int <- integer(128..0xFFFFFFFF) do
        encoded = Encoder.encode(int)
        {:ok, decoded_binary} = Decoder.decode(encoded)
        
        # Should not have leading zero bytes
        case decoded_binary do
          <<0, _rest::binary>> -> flunk("Encoded integer has leading zero")
          _ -> true
        end
      end
    end

    property "zero encodes to empty string" do
      check all _iteration <- integer(1..100) do
        assert Encoder.encode(0) == <<0x80>>
      end
    end

    property "powers of two encode correctly" do
      check all exp <- integer(0..20) do
        value = :math.pow(2, exp) |> round()
        encoded = Encoder.encode(value)
        
        {:ok, decoded_binary} = Decoder.decode(encoded)
        decoded_int = if decoded_binary == "", do: 0, else: :binary.decode_unsigned(decoded_binary, :big)
        
        assert decoded_int == value
      end
    end
  end

  # Helper function to create nested list structures
  defp nest_data(data, 0), do: data
  defp nest_data(data, depth) when depth > 0 do
    [nest_data(data, depth - 1)]
  end
end
