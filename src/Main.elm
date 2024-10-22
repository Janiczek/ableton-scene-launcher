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
    { name : String
    , index : Int
    , color : String
    }


type alias SceneSet =
    { name : String
    , scenes : List Scene
    }


type alias Model =
    { sceneSets : List SceneSet }


init : () -> ( Model, Cmd Msg )
init () =
    ( { sceneSets = [] }
    , Cmd.none
    )


type Msg
    = ReceivedInMsg String
    | SendOutMsg OutMsg


type InMsg
    = Scenes (List Scene)


type OutMsg
    = TriggerScene { index : Int }


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
    Json.Decode.map3 Scene
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "index" Json.Decode.int)
        (Json.Decode.field "color" Json.Decode.string)


encodeOutMsg : OutMsg -> Json.Encode.Value
encodeOutMsg msg =
    case msg of
        TriggerScene { index } ->
            Json.Encode.object
                [ ( "msg", Json.Encode.string "TriggerScene" )
                , ( "index", Json.Encode.int index )
                ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    onWebsocketMessage ReceivedInMsg


view : Model -> Html Msg
view model =
    Html.div [] <|
        List.map viewSceneSet model.sceneSets


viewSceneSet : SceneSet -> Html Msg
viewSceneSet sceneSet =
    Html.div []
        [ Html.h2 [] [ Html.text sceneSet.name ]
        , Html.div [ Attrs.class "sceneset-scenes" ]
            (List.map viewSceneButton sceneSet.scenes)
        ]


viewSceneButton : Scene -> Html Msg
viewSceneButton scene =
    Html.button
        [ Attrs.class "scene"
        , Events.onClick (SendOutMsg (TriggerScene { index = scene.index }))
        ]
        [ Html.text scene.name ]


sceneSetHeaderColor : String
sceneSetHeaderColor =
    "#3c3c3c"


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
        go : String -> List Scene -> List SceneSet -> List SceneSet
        go currentSetName remainingScenes acc =
            case remainingScenes of
                [] ->
                    List.reverse acc

                scene :: rest ->
                    if scene.color == sceneSetHeaderColor then
                        let
                            newSceneSet =
                                { name = scene.name
                                , scenes = []
                                }
                        in
                        go scene.name rest (newSceneSet :: acc)

                    else
                        case acc of
                            currentSet :: otherSets ->
                                let
                                    updatedSet =
                                        { currentSet | scenes = scene :: currentSet.scenes }
                                in
                                go currentSetName rest (updatedSet :: otherSets)

                            [] ->
                                let
                                    newSceneSet =
                                        { name = currentSetName
                                        , scenes = [ scene ]
                                        }
                                in
                                go currentSetName rest [ newSceneSet ]
    in
    go "Unnamed" scenes []
