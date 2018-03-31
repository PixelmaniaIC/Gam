defmodule GameServer.Receiver do
  alias GameServer.Message, as: Message
  alias GameServer.StatesKeeper, as: StatesKeeper
  alias GameServer.Constants, as: Constants

  def receive(%Message{playerId: id, networkName: "ColorChanger", payload: payload}, states) do
    %PictureProcess.Cell{r: r, g: g, b: b, a: a, index: index} =
      Poison.decode!(payload, as: %PictureProcess.Cell{})

    distance =
      StatesKeeper.current_picture_state(states)
      |> PictureProcess.State.get(index)
      |> PictureProcess.Cell.get_distance(%PictureProcess.Color{r: r, g: g, b: b})
      |> GameServer.Leaderboard.to_points

    user_state = StatesKeeper.users_state(states)
    user_state |> GameServer.UserState.update_score(id, distance)

    picture_curr_state = StatesKeeper.current_picture_state(states)
    PictureProcess.State.put(picture_curr_state,
                              index,
                              %PictureProcess.Color{r: r, g: g, b: b, a: a, status: 1})

    {:ok, change_color_message} =
      GameServer.Command.change_color(id, payload)
      |> JSON.encode()

    {:ok, update_score_message} =
      GameServer.Command.update_score(id, distance)
      |> JSON.encode();

    message_list = [change_color_message, update_score_message]

    {:stupid_broadcast, message_list, StatesKeeper.clients_pid(states)}
  end

  def receive(%Message{playerId: id, networkName: "NameSetter", payload: name}, states) do
    StatesKeeper.users_state(states)
    |> GameServer.UserState.new_player(id, name)

    {:ok, json_message} = GameServer.Command.add_user(id, name) |> JSON.encode
    {:except_sender, json_message, StatesKeeper.clients_pid(states), id}
  end

  def receive(%Message{playerId: id, networkName: "ImageDownloaded", payload: _}, states) do

    picture_curr_state = StatesKeeper.current_picture_state(states)
    {:ok, message} =
      (0..Constants.picture_parts)
      |> Enum.reduce([], fn(index, list) ->
        indexed = PictureProcess.State.get(picture_curr_state, index)
        [Map.update!(indexed, :index, fn(x) -> index end) | list ] end)
      |> Enum.filter(fn(x) -> x.status == 1 end)
      |> GameServer.Command.set_changed_state(id)
      |> JSON.encode()

    client = StatesKeeper.clients_pid(states) |> GameServer.Clients.get(id)
    {:client, message, client}
  end
end
