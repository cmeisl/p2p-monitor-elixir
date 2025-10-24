# LoadLoad support files before starting ExUnitfiles before starting ExUnit
Code.require_file("support/test_helper.ex", __DIR__)
# Load support files
Code.require_file("support/test_helper.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)

# Start ExUnit
ExUnit.start()
ExUnit.configure(exclude: [test_load_filters: ~r/support/])
