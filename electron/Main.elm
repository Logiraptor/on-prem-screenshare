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


main : Program Never Model Msg
main =
    Html.program
        { init =
            ( { room = Nothing
              , enteredRoomValue = ""
              , stream = Nothing
              , errors = []
              , numClients = 0
              }
            , Cmd.none
            )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { room : Maybe String
    , enteredRoomValue : String
    , stream : Maybe String
    , errors : List String
    , numClients : Int
    }


type Msg
    = UpdateRoomName String
    | JoinRoom
    | NumClients Int
    | SDP Json.Decode.Value
    | ICE Json.Decode.Value
    | ErrorEvent String
    | SendToServer Json.Decode.Value
    | AddStream String
    | StartShare


view : Model -> Html.Html Msg
view model =
    Html.div []
        [ viewContent model
        , viewErrors model
        ]


viewContent : Model -> Html.Html Msg
viewContent model =
    case model.room of
        Nothing ->
            viewNoRoom model

        Just room ->
            viewWithRoom room model


viewErrors : Model -> Html.Html Msg
viewErrors model =
    Html.div [] (List.map viewError model.errors)


viewError : String -> Html.Html Msg
viewError s =
    Html.div []
        [ Html.text s
        ]


viewWithRoom : String -> Model -> Html.Html Msg
viewWithRoom name model =
    case model.stream of
        Nothing ->
            Html.div []
                [ Html.h1 [] [ Html.text name ]
                , Html.span [] [ Html.text (model.numClients |> toString |> (++) "Clients: ") ]
                , Html.button [ Events.onClick StartShare ] [ Html.text "Start Share" ]
                ]

        Just s ->
            Html.div []
                [ Html.h1 [] [ Html.text name ]
                , Html.span [] [ Html.text (model.numClients |> toString |> (++) "Clients: ") ]
                , Html.video [ Attr.src s, Attr.autoplay True ] []
                ]


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

        ErrorEvent e ->
            ( { model | errors = e :: model.errors }, Cmd.none )

        ICE val ->
            ( model, addIceCandidate val )

        SDP val ->
            ( model, setRemoteDescription val )

        SendToServer val ->
            ( model, sendToServer model val )

        AddStream s ->
            ( { model | stream = Just s }, Cmd.none )

        NumClients n ->
            ( { model | numClients = n }, Cmd.none )

        StartShare ->
            ( model, createOffer () )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ wsSub model
        , onIceCandidate (wrapWithField "ice" >> SendToServer)
        , onAnswer (wrapWithField "sdp" >> SendToServer)
        , onOffer (wrapWithField "sdp" >> SendToServer)
        , onAddStream AddStream
        , errors ErrorEvent
        ]


wrapWithField : String -> Json.Decode.Value -> Json.Decode.Value
wrapWithField key val =
    Json.Encode.object [ ( key, val ) ]


wsSub : Model -> Sub Msg
wsSub model =
    case model.room of
        Nothing ->
            Sub.none

        Just name ->
            WebSocket.listen ("ws://127.0.0.1:3434/ws?room=" ++ name) decodeMessage


sendToServer : Model -> Json.Decode.Value -> Cmd Msg
sendToServer model val =
    case model.room of
        Nothing ->
            Cmd.none

        Just name ->
            let
                body =
                    Json.Encode.encode 0 val
            in
                WebSocket.send ("ws://127.0.0.1:3434/ws?room=" ++ name) body


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
    Json.Decode.field "sdp" Json.Decode.value |> Json.Decode.map SDP


iceDecoder : Json.Decode.Decoder Msg
iceDecoder =
    Json.Decode.field "ice" Json.Decode.value |> Json.Decode.map ICE


numClientsDecoder : Json.Decode.Decoder Msg
numClientsDecoder =
    Json.Decode.field "numClients" Json.Decode.int |> Json.Decode.map NumClients
