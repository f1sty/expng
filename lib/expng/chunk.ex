defmodule Expng.Chunk do
  alias Expng.Header

  defstruct [:length, :type, :data, :crc32, :valid_crc?]

  @type t :: %__MODULE__{}

  @spec new(Keyword.t()) :: t()
  def new(args \\ []) do
    struct(__MODULE__, args)
  end

  @spec fetch_chunks(binary()) :: list()
  def fetch_chunks(data) do
    data
    |> Header.strip()
    |> fetch_chunks([])
  end

  defp fetch_chunks("", chunks), do: Enum.reverse(chunks)

  defp fetch_chunks(data, chunks) do
    {chunk, data} = fetch_chunk(data)

    fetch_chunks(data, [chunk | chunks])
  end

  @spec fetch_chunk(binary()) :: {t(), binary()}
  def fetch_chunk(data) do
    <<length::integer-big-32, chunk_type::bytes-4, chunk_data::bytes-size(length),
      crc32::integer-32, rest::binary>> = data

    valid_crc? = :erlang.crc32(<<chunk_type::bytes-4>> <> chunk_data) == crc32

    chunk =
      new(
        length: length,
        type: chunk_type,
        data: chunk_data,
        crc32: crc32,
        valid_crc?: valid_crc?
      )

    chunk = parse_chunk(chunk)

    {chunk, rest}
  end

  @spec parse_chunk(t()) :: t()
  def parse_chunk(%__MODULE__{type: "IDAT", data: _data} = raw_chunk) do
    raw_chunk
  end

  def parse_chunk(%__MODULE__{type: "IEND", data: _data} = raw_chunk) do
    raw_chunk
  end

  def parse_chunk(%__MODULE__{type: "iTXt", data: data} = raw_chunk) do
    [keyword, <<compression_flag::integer, compression_method::integer, rest::binary>>] =
      :binary.split(data, <<0>>)

    [language_tag, translated_keyword, text] = String.split(rest, <<0>>)

    parsed_data = %{
      keyword: keyword,
      compression_flag: compression_flag,
      compression_method: compression_method,
      language_tag: language_tag,
      translated_keyword: translated_keyword,
      text: text
    }

    %{raw_chunk | data: parsed_data}
  end

  def parse_chunk(%__MODULE__{type: "tEXt", data: data} = raw_chunk) do
    [key, value] = String.split(data, <<0>>)
    parsed_data = Map.put(%{}, key, value)

    %{raw_chunk | data: parsed_data}
  end

  def parse_chunk(%__MODULE__{type: "IHDR", data: data} = raw_chunk) do
    <<width::integer-32, height::integer-32, bit_depth::integer, color_type::integer,
      compression_method::integer, filter_method::integer, interlace_method::integer>> = data

    parsed_data = %{
      width: width,
      height: height,
      bit_depth: bit_depth,
      color_type: color_type,
      compression_method: compression_method,
      filter_method: filter_method,
      interlace_method: interlace_method
    }

    %{raw_chunk | data: parsed_data}
  end
end
