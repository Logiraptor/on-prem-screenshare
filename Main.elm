port module Main exposing (..)

import Html
import Html.Attributes as Attr
import Html.Events as Events
import WebSocket
import Json.Decode
import Json.Encode


port onIceCandidate : (Json.Decode.Value -> msg) -> Sub msg


port addIceCandidate : Json.Decode.Value -> Cmd msg


port setRemoteDescription : Json.Decode.Value -> Cmd msg


port onAnswer : (Json.Decode.Value -> msg) -> Sub msg


port createOffer : () -> Cmd msg


port onOffer : (Json.Decode.Value -> msg) -> Sub msg


port onAddStream : (String -> msg) -> Sub msg


port errors : (String -> msg) -> Sub msg


main : Program String Model Msg
main =
    Html.programWithFlags
        { init =
            (\hostname ->
                ( { room = InLobby { roomName = "" }
                  , errors = []
                  , hostname = hostname
                  }
                , Cmd.none
                )
            )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { room : RoomState
    , errors : List String
    , hostname : String
    }


type Msg
    = UpdateRoomName String
    | JoinRoom String
    | NumClients Int
    | RemoteSDP Json.Decode.Value
    | RemoteICE Json.Decode.Value
    | LocalSDP Json.Decode.Value
    | ErrorEvent String
    | LocalICE Json.Decode.Value
    | AddStream String
    | StartShare


type alias ICECandiate =
    Json.Decode.Value


type alias SessionDescription =
    Json.Decode.Value


type alias Stream =
    String


type SDPState
    = Unknown
    | LocalOnly
    | RemoteOnly
    | Both


type RTCPeerConnectionState
    = GatheringICE
    | Connected Stream


type alias Room =
    { name : String, numClients : Int }


type alias Lobby =
    { roomName : String }


type RoomState
    = InLobby Lobby
    | Waiting Room
    | Sharing Room RTCPeerConnectionState


view : Model -> Html.Html Msg
view model =
    Html.div []
        [ viewContent model
        , viewErrors model
        ]


viewContent : Model -> Html.Html Msg
viewContent model =
    case model.room of
        InLobby lobby ->
            viewLobby lobby

        Waiting room ->
            viewWaiting room

        Sharing room connection ->
            viewSharing room connection


viewLobby : Lobby -> Html.Html Msg
viewLobby lobby =
    Html.div []
        [ Html.h1 [] [ Html.text ("Choose a room") ]
        , Html.input [ Attr.value lobby.roomName, Events.onInput UpdateRoomName ] []
        , Html.button [ Events.onClick (JoinRoom lobby.roomName) ] [ Html.text "Join" ]
        ]


viewWaiting : Room -> Html.Html Msg
viewWaiting room =
    Html.div []
        [ Html.h1 [] [ Html.text room.name ]
        , Html.span [] [ Html.text (room.numClients |> toString |> (++) "Clients: ") ]
        , Html.button [ Events.onClick StartShare ] [ Html.text "Start Share" ]
        ]


viewSharing : Room -> RTCPeerConnectionState -> Html.Html Msg
viewSharing room connection =
    Html.div []
        [ Html.h1 [] [ Html.text room.name ]
        , Html.span [] [ Html.text (room.numClients |> toString |> (++) "Clients: ") ]
        , viewConnection connection
        ]


viewConnection : RTCPeerConnectionState -> Html.Html Msg
viewConnection conn =
    case conn of
        GatheringICE ->
            Html.span []
                [ Html.text ("gathering ice.")
                ]

        Connected stream ->
            Html.video [ Attr.src stream, Attr.autoplay True ] []


viewErrors : Model -> Html.Html Msg
viewErrors model =
    Html.div [] (List.map viewError model.errors)


viewError : String -> Html.Html Msg
viewError s =
    Html.div []
        [ Html.text s
        ]


invalidMessage : Msg -> Model -> ( Model, Cmd Msg )
invalidMessage msg model =
    let
        message =
            "Invalid message in "
                ++ (toString model.room)
                ++ "\n"
                ++ (toString msg)
    in
        ( { model | errors = message :: model.errors }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model.room of
        InLobby l ->
            case msg of
                UpdateRoomName name ->
                    ( { model | room = InLobby { roomName = name } }, Cmd.none )

                JoinRoom s ->
                    ( { model | room = Waiting { name = s, numClients = 0 } }, Cmd.none )

                msg ->
                    invalidMessage msg model

        Waiting room ->
            case msg of
                StartShare ->
                    ( { model | room = Sharing room GatheringICE }, createOffer () )

                NumClients n ->
                    ( { model | room = Waiting ({ room | numClients = n }) }, Cmd.none )

                RemoteICE val ->
                    ( { model | room = Sharing room GatheringICE }, Cmd.none )

                RemoteSDP val ->
                    ( model, setRemoteDescription val )

                msg ->
                    invalidMessage msg model

        Sharing room conn ->
            case msg of
                NumClients n ->
                    ( { model | room = Sharing ({ room | numClients = n }) conn }, Cmd.none )

                LocalSDP val ->
                    ( model, sendToServer model (wrapWithField "sdp" val) )

                RemoteSDP val ->
                    ( model, setRemoteDescription val )

                LocalICE val ->
                    ( model, sendToServer model (wrapWithField "ice" val) )

                RemoteICE val ->
                    ( model, addIceCandidate val )

                AddStream s ->
                    ( { model | room = Sharing room (Connected s) }, Cmd.none )

                msg ->
                    invalidMessage msg model


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ wsSub model
        , onIceCandidate LocalICE
        , onAnswer LocalSDP
        , onOffer LocalSDP
        , onAddStream AddStream
        , errors ErrorEvent
        ]


wrapWithField : String -> Json.Decode.Value -> Json.Decode.Value
wrapWithField key val =
    Json.Encode.object [ ( key, val ) ]


wsSub : Model -> Sub Msg
wsSub model =
    case model.room of
        InLobby _ ->
            Sub.none

        Waiting room ->
            WebSocket.listen ("ws://" ++ model.hostname ++ "/ws?room=" ++ room.name) decodeMessage

        Sharing room conn ->
            WebSocket.listen ("ws://" ++ model.hostname ++ "/ws?room=" ++ room.name) decodeMessage


sendToServer : Model -> Json.Decode.Value -> Cmd Msg
sendToServer model val =
    case model.room of
        InLobby _ ->
            Cmd.none

        Waiting room ->
            Json.Encode.encode 0 val
                |> WebSocket.send ("ws://" ++ model.hostname ++ "/ws?room=" ++ room.name)

        Sharing room conn ->
            Json.Encode.encode 0 val
                |> WebSocket.send ("ws://" ++ model.hostname ++ "/ws?room=" ++ room.name)


decodeMessage : String -> Msg
decodeMessage s =
    case Json.Decode.decodeString messageDecoder s of
        Ok r ->
            r

        Err e ->
            ErrorEvent e


messageDecoder : Json.Decode.Decoder Msg
messageDecoder =
    Json.Decode.oneOf [ sdpDecoder, iceDecoder, numClientsDecoder ]


sdpDecoder : Json.Decode.Decoder Msg
sdpDecoder =
    Json.Decode.field "sdp" Json.Decode.value |> Json.Decode.map RemoteSDP


iceDecoder : Json.Decode.Decoder Msg
iceDecoder =
    Json.Decode.field "ice" Json.Decode.value |> Json.Decode.map RemoteICE


numClientsDecoder : Json.Decode.Decoder Msg
numClientsDecoder =
    Json.Decode.field "numClients" Json.Decode.int |> Json.Decode.map NumClients
