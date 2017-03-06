module Main exposing (..)

import Html
import Html.Attributes as Attr
import Html.Events as Events
import WebSocket
import Json.Decode


main : Program Never Model Msg
main =
    Html.program
        { init = ( { room = Nothing, enteredRoomValue = "" }, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { room : Maybe String, enteredRoomValue : String }


type Msg
    = UpdateRoomName String
    | JoinRoom
    | SDP Json.Decode.Value
    | ICE Json.Decode.Value
    | MessageError String


view : Model -> Html.Html Msg
view model =
    case model.room of
        Nothing ->
            viewNoRoom model

        Just room ->
            viewWithRoom room


viewWithRoom : String -> Html.Html Msg
viewWithRoom name =
    Html.h1 [] [ Html.text name ]


viewNoRoom : Model -> Html.Html Msg
viewNoRoom model =
    Html.div []
        [ Html.h1 [] [ Html.text "Choose a room" ]
        , Html.input [ Attr.value model.enteredRoomValue, Events.onInput UpdateRoomName ] []
        , Html.button [ Events.onClick JoinRoom ] [ Html.text "Join" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateRoomName name ->
            ( { model | enteredRoomValue = name }, Cmd.none )

        JoinRoom ->
            ( { model | room = Just model.enteredRoomValue }, Cmd.none )

        MessageError e ->
            ( model, Cmd.none )

        ICE val ->
            ( model, receiveICE val )

        -- make ports here
        SDP val ->
            ( model, receiveSDP val )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.room of
        Nothing ->
            Sub.none

        Just name ->
            WebSocket.listen ("ws://127.0.0.1:3434/ws?room=" ++ name) decodeMessage


decodeMessage : String -> Msg
decodeMessage s =
    case Json.Decode.decodeString messageDecoder s of
        Ok r ->
            r

        Err e ->
            MessageError e


messageDecoder : Json.Decode.Decoder Msg
messageDecoder =
    Json.Decode.oneOf [ sdpDecoder, iceDecoder ]


sdpDecoder : Json.Decode.Decoder Msg
sdpDecoder =
    Json.Decode.field "sdp" Json.Decode.value |> Json.Decode.map SDP


iceDecoder : Json.Decode.Decoder Msg
iceDecoder =
    Json.Decode.field "ice" Json.Decode.value |> Json.Decode.map ICE
