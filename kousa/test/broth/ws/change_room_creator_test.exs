defmodule KousaTest.Broth.Ws.ChangeModStatusTest do
  use ExUnit.Case, async: true
  use Kousa.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Users
  alias Broth.WsClient
  alias Broth.WsClientFactory
  alias Kousa.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    ws_client = WsClientFactory.create_client_for(user)

    {:ok, user: user, ws_client: ws_client}
  end

  describe "the websocket change_room_creator operation" do
    test "makes the person a room_creator", t do
      # first, create a room owned by the primary user.
      {:ok, %{room: %{id: room_id}}} = Kousa.Room.create_room(t.user.id, "foo room", "foo", false)
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      Kousa.Room.join_room(speaker_id, room_id)

      WsClient.assert_frame("new_user_join_room", %{"user" => %{"id" => ^speaker_id}})

      # add the person as a speaker.
      WsClient.send_msg(t.ws_client, "add_speaker", %{"userId" => speaker_id})

      # both clients get notified
      WsClient.assert_frame(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id})

      WsClient.assert_frame(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id})

      # make the person a mod
      WsClient.send_msg(t.ws_client,
        "change_mod_status", %{"userId" => speaker_id, "value" => true})

      # both clients get notified
      WsClient.assert_frame(
        "mod_changed",
        %{"userId" => ^speaker_id, "roomId" => ^room_id})

      WsClient.assert_frame(
        "mod_changed",
        %{"userId" => ^speaker_id, "roomId" => ^room_id})

      # make the person a room creator.

      WsClient.send_msg(t.ws_client,
        "change_room_creator", %{
          "userId" => speaker_id
        })

      # NB: we get an extraneous speaker_added message here.
      WsClient.assert_frame(
        "new_room_creator",
        %{"userId" => ^speaker_id, "roomId" => ^room_id}
      )
    end

    @tag :skip
    test "you can't make someone a room creator when they aren't a mod first"

    @tag :skip
    test "a non-owner can't make someone a room creator"
  end
end
