defmodule Expng.Chunk do
  alias Expng.Header

  defstruct [:length, :type, :data, :crc32, :valid_crc?]

  @type t :: %__MODULE__{}

  @spec new(Keyword.t()) :: t()
  def new(args \\ []) do
    struct(__MODULE__, args)
  end

  @spec get_chunks(binary()) :: list()
  def get_chunks(data) do
    data
    |> Header.strip()
    |> get_chunks([])
  end

  defp get_chunks("", chunks), do: Enum.reverse(chunks)

  defp get_chunks(data, chunks) do
    {chunk, data} = fetch_chunk(data)

    get_chunks(data, [chunk | chunks])
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
  def parse_chunk(%__MODULE__{type: "pHYs", data: data} = raw_chunk) do
    <<ppu_x::unsigned-integer-32, ppu_y::unsigned-integer-32, unit_specifier::integer>> = data
    unit_specifier = (unit_specifier == 0 && :unknown) || :meter

    parsed_data = %{
      ppu_x: ppu_x,
      ppu_y: ppu_y,
      unit_specifier: unit_specifier
    }

    %{raw_chunk | data: parsed_data}
  end

  def parse_chunk(%__MODULE__{type: "gAMA", data: <<data::unsigned-integer-32>>} = raw_chunk) do
    parsed_data = %{image_gamma: data / 100_000}

    %{raw_chunk | data: parsed_data}
  end

  def parse_chunk(%__MODULE__{type: "sRGB", data: <<key>>} = raw_chunk) do
    rendering_intent_map = %{
      0 => "perceptual",
      1 => "relative colorimetric",
      2 => "saturation",
      3 => "absolute colorimetric"
    }

    parsed_data = %{rendering_intent: rendering_intent_map[key]}

    %{raw_chunk | data: parsed_data}
  end

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

    compression_flag = (compression_flag == 0 && :uncompressed_text) || :compressed_text
    compression_method = (compression_method == 0 && :deflate) || :unknown

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
    <<width::integer-32, height::integer-32, bit_depth::integer, colour_type::integer,
      compression_method::integer, filter_method::integer, interlace_method::integer>> = data

    compression_method = (compression_method == 0 && :deflate) || :unknown
    interlace_method = (interlace_method == 0 && "no interlance") || "Adam7 interlance"

    colour_type_map = %{
      0 => "greyscale",
      2 => "truecolour",
      3 => "indexed-colour",
      4 => "greyscale with alpha",
      6 => "truecolour with alpha"
    }

    parsed_data = %{
      width: width,
      height: height,
      bit_depth: bit_depth,
      colour_type: colour_type_map[colour_type],
      compression_method: compression_method,
      filter_method: filter_method,
      interlace_method: interlace_method
    }

    %{raw_chunk | data: parsed_data}
  end
end
