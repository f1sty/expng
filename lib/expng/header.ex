defmodule Expng.Header do
  @spec strip(binary()) :: binary()
  def strip(data) do
    <<0x89, ?P, ?N, ?G, 0xD, 0xA, 0x1A, 0xA, body::binary>> = data
    body
  end

  @spec add(binary()) :: binary()
  def add(body) do
    <<0x89, ?P, ?N, ?G, 0xD, 0xA, 0x1A, 0xA, body::binary>>
  end
end
