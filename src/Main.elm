port module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import Json.Decode exposing (Decoder)
import Json.Encode


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


port alert : String -> Cmd msg


port sendWebsocketMessage : String -> Cmd msg


port onWebsocketMessage : (String -> msg) -> Sub msg


type alias Scene =
    { id : String
    , name : String
    , index : Int
    , color : String
    , isTriggered : Bool
    , isPlaying : Bool
    }


type alias SceneSet =
    { name : String
    , scenes : List Scene
    }


type alias Model =
    { sceneSets : List SceneSet
    }


init : () -> ( Model, Cmd Msg )
init () =
    ( { sceneSets = []
      }
    , Cmd.none
    )


type Msg
    = ReceivedInMsg String
    | SendOutMsg OutMsg


type InMsg
    = Scenes (List Scene)


type OutMsg
    = TriggerScene { index : Int }
    | StopNicely
    | StopNow


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedInMsg string ->
            case Json.Decode.decodeString inMsgDecoder string of
                Err err ->
                    ( model
                    , alert <|
                        "Error decoding websocket message: "
                            ++ Debug.toString
                                { message = string
                                , error = err
                                }
                    )

                Ok message ->
                    updateInMsg message model

        SendOutMsg outMsg ->
            ( model
            , sendWebsocketMessage (Json.Encode.encode 0 (encodeOutMsg outMsg))
            )


updateInMsg : InMsg -> Model -> ( Model, Cmd Msg )
updateInMsg msg model =
    case msg of
        Scenes scenes ->
            ( { model | sceneSets = scenesToSceneSets scenes }
            , Cmd.none
            )


inMsgDecoder : Decoder InMsg
inMsgDecoder =
    Json.Decode.field "msg" Json.Decode.string
        |> Json.Decode.andThen
            (\msgType ->
                case msgType of
                    "scenes" ->
                        Json.Decode.field "scenes" (Json.Decode.list sceneDecoder)
                            |> Json.Decode.map Scenes

                    _ ->
                        Json.Decode.fail ("Unknown message type: " ++ msgType)
            )


sceneDecoder : Decoder Scene
sceneDecoder =
    Json.Decode.map6 Scene
        (Json.Decode.field "id" Json.Decode.string)
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "index" Json.Decode.int)
        (Json.Decode.field "color" Json.Decode.string)
        (Json.Decode.field "isTriggered" Json.Decode.bool)
        (Json.Decode.field "isPlaying" Json.Decode.bool)


encodeOutMsg : OutMsg -> Json.Encode.Value
encodeOutMsg msg =
    case msg of
        TriggerScene { index } ->
            Json.Encode.object
                [ ( "msg", Json.Encode.string "TriggerScene" )
                , ( "index", Json.Encode.int index )
                ]

        StopNicely ->
            Json.Encode.object
                [ ( "msg", Json.Encode.string "StopNicely" )
                ]

        StopNow ->
            Json.Encode.object
                [ ( "msg", Json.Encode.string "StopNow" )
                ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    onWebsocketMessage ReceivedInMsg


view : Model -> Html Msg
view model =
    Html.div [ Attrs.class "app" ]
        [ Html.div [ Attrs.class "scenesets" ]
            [ Html.div [ Attrs.class "scenesets-inner" ] <|
                List.map viewSceneSet model.sceneSets
            ]
        , Html.div [ Attrs.class "controls" ]
            [ Html.div [ Attrs.class "controls-inner" ]
                [ Html.button
                    [ Events.onClick (SendOutMsg StopNicely)
                    , Attrs.class "control"
                    ]
                    [ Html.text "Stop nicely" ]
                , Html.button
                    [ Events.onClick (SendOutMsg StopNow)
                    , Attrs.class "control"
                    ]
                    [ Html.text "Stop now" ]
                ]
            ]
        ]


viewSceneSet : SceneSet -> Html Msg
viewSceneSet sceneSet =
    Html.div []
        [ Html.h2 [ Attrs.class "sceneset-name" ] [ Html.text sceneSet.name ]
        , Html.div [ Attrs.class "sceneset-scenes" ]
            (List.map viewSceneButton sceneSet.scenes)
        ]


viewSceneButton : Scene -> Html Msg
viewSceneButton scene =
    Html.button
        [ Attrs.classList
            [ ( "scene", True )
            , ( "triggered", scene.isTriggered )
            , ( "playing", scene.isPlaying )
            ]
        , Events.onClick (SendOutMsg (TriggerScene { index = scene.index }))
        ]
        [ Html.text scene.name ]


{-|

    scenesToSceneSets
        [ Scene "Foo" "#ff0000"
        , Scene "Bar" "#ff0000"
        , Scene "Baz" "#ff0000"
        , Scene "Song 1" "#3c3c3c"
        , Scene "Quux" "#ff0000"
        , Scene "A" "#ff0000"
        , Scene "B" "#ff0000"
        , Scene "Song 2" "#3c3c3c"
        , Scene "C" "#ff0000"
        , Scene "D" "#ff0000"
        , Scene "E" "#ff0000"
        , Scene "Song 3" "#3c3c3c"
        , Scene "F" "#ff0000"
        , Scene "G" "#ff0000"
        , Scene "H" "#ff0000"
        , Scene "Song 4" "#3c3c3c"
        , Scene "OTHER" "#3c3c3c"
        , Scene "I" "#ff0000"
        , Scene "J" "#ff0000"
        ]
        == [ { name = "Unnamed"
             , scenes =
                [ Scene "Foo" "#ff0000"
                , Scene "Bar" "#ff0000"
                , Scene "Baz" "#ff0000"
                ]
             }
           , { name = "Song 1"
             , scenes =
                [ Scene "Quux" "#ff0000"
                , Scene "A" "#ff0000"
                , Scene "B" "#ff0000"
                ]
             }
           , { name = "Song 2"
             , scenes =
                [ Scene "C" "#ff0000"
                , Scene "D" "#ff0000"
                , Scene "E" "#ff0000"
                ]
             }
           , { name = "Song 3"
             , scenes =
                [ Scene "F" "#ff0000"
                , Scene "G" "#ff0000"
                , Scene "H" "#ff0000"
                ]
             }
           , { name = "Song 4"
             , scenes = []
             }
           , { name = "OTHER"
             , scenes =
                [ Scene "I" "#ff0000"
                , Scene "J" "#ff0000"
                ]
             }
           ]

-}
scenesToSceneSets : List Scene -> List SceneSet
scenesToSceneSets scenes =
    let
        sceneSetHeaderColor : String
        sceneSetHeaderColor =
            "#3c3c3c"

        unnamed : String
        unnamed =
            "Unnamed"

        go : String -> List Scene -> List Scene -> List SceneSet -> List SceneSet
        go currentSetName currentScenes remainingScenes acc =
            case remainingScenes of
                [] ->
                    if currentScenes == [] then
                        List.reverse acc

                    else
                        List.reverse
                            ({ name = currentSetName
                             , scenes = List.reverse currentScenes
                             }
                                :: acc
                            )

                scene :: rest ->
                    if scene.color == sceneSetHeaderColor then
                        -- we can commit the acc scenes
                        if currentScenes == [] && currentSetName == unnamed then
                            -- skip the Unnamed catch-all set if it's empty
                            go scene.name [] rest acc

                        else
                            -- new set! compile the current set into the acc
                            go scene.name
                                []
                                rest
                                ({ name = currentSetName
                                 , scenes = List.reverse currentScenes
                                 }
                                    :: acc
                                )

                    else
                        -- add the scene to the current set
                        go currentSetName (scene :: currentScenes) rest acc
    in
    go unnamed [] scenes []
