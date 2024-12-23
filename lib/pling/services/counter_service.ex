defmodule Pling.Services.CounterService do
  def increment(state, color) do
    counter_key = String.to_atom("#{color}_count")
    Map.update!(state, counter_key, &(&1 + 1))
  end

  def decrement(state, color) do
    counter_key = String.to_atom("#{color}_count")
    Map.update!(state, counter_key, &max(0, &1 - 1))
  end
end
