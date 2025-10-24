# Load support files before starting ExUnit
Code.require_file("support/test_helper.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)
Code.require_file("support/ethereum_client.ex", __DIR__)

# Start ExUnit
# Exclude integration tests by default (run with: mix test --only integration)
ExUnit.start(exclude: [:integration])
