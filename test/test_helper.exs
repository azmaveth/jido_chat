# In test/test_helper.exs

ExUnit.start()
# Mimic.copy(Phoenix.PubSub)

# Ensure consistent test environment
Application.put_env(:jido_chat, :pubsub_adapter, Phoenix.PubSub)
Application.put_env(:jido_chat, :persistence_adapter, JidoChat.Channel.Persistence.ETS)

# Start required applications for testing
Application.ensure_all_started(:phoenix_pubsub)
