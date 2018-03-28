defmodule PictureProcess do
  alias PictureProcess.Fragment, as: Fragment
  alias PictureProcess.State, as: State

  # TODO: rewrite, this function do many actions
  def process(n) do

    Application.ensure_all_started :inets

    {:ok, resp} = :httpc.request(:get, {image_url(), []}, [], [body_format: :binary])
    {{_, 200, 'OK'}, _headers, body} = resp

    image = ExPNG.decode(body)

    ranges = Map.get(image, :width)
    |> Fragment.get_ranges(n)

    {:ok , changed_colors} = State.start_link

    Enum.map(ranges, fn(range_y) ->
      Enum.map(ranges, fn(range_x) ->
          Fragment.pixel_sum(image, range_x, range_y)
          |>Fragment.get_average(range_x)
      end)
    end)
    |> List.flatten
    |> Enum.reduce(0, fn(color, index) ->
      State.put(changed_colors, index, color)
      index + 1
    end)

    IO.puts "Image received"

    changed_colors
  end

  def get_url do
    to_string(image_url())
  end

  def image_url do
    'http://res.cloudinary.com/df0xbva5c/image/upload/v1521722642/randevu.png'
  end
end
