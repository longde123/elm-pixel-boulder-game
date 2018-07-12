module InputController
    exposing
        ( Model
        , Msg
        , KeyStatus(..)
        , Keys
        , init
        , update
        , subscriptions
        , getCurrentDirection
        , resetWasPressed
        )

import Keyboard
import Dict exposing (Dict)
import Maybe.Extra
import Data.Common exposing (Direction)


type alias Model =
    { keys : Keys
    , counter : Int
    }


type alias Keys =
    Dict Keyboard.KeyCode KeyStatus


type KeyStatus
    = NotPressed
    | WasPressed Int
    | IsPressed Int


type Msg
    = KeyPressed Keyboard.KeyCode
    | KeyDown Keyboard.KeyCode
    | KeyUp Keyboard.KeyCode


leftArrow : Int
leftArrow =
    37


upArrow : Int
upArrow =
    38


rightArrow : Int
rightArrow =
    39


downArrow : Int
downArrow =
    40


keyCodeToDirection : Dict Keyboard.KeyCode Direction
keyCodeToDirection =
    Dict.fromList
        [ ( leftArrow, Data.Common.Left )
        , ( upArrow, Data.Common.Up )
        , ( rightArrow, Data.Common.Right )
        , ( downArrow, Data.Common.Down )
        ]


init : Model
init =
    { keys =
        { left = NotPressed
        , up = NotPressed
        , right = NotPressed
        , down = NotPressed
        }
    , counter = 0
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        KeyPressed keyCode ->
            handleIsPressed keyCode model

        KeyDown keyCode ->
            handleIsPressed keyCode model

        KeyUp keyCode ->
            handleWasPressed keyCode model


getCurrentDirection : Model -> Maybe Direction
getCurrentDirection model =
    Dict.map
        (\( code, direction ) ->
            getCounter code model.keys
                |> Maybe.andThen
                    (\counter ->
                        Just ( counter, direction )
                    )
        )
        keyCodeToDirection
        |> Maybe.Extra.values
        |> List.sort
        |> List.head
        |> Maybe.andThen
            (\( _, direction ) ->
                Just direction
            )


resetWasPressed : Model -> Model
resetWasPressed model =
    { model
        | keys =
            Dict.map
                (\keyCode status ->
                    case status of
                        WasPressed _ ->
                            NotPressed

                        _ ->
                            status
                )
                model.keys
    }


handleIsPressed : Keyboard.KeyCode -> Model -> Model
handleIsPressed keyCode model =
    model
        |> incrementCounter
        |> (\model ->
                { model
                    | keys =
                        updateKey keyCode (IsPressed model.counter) model.keys
                }
           )


handleWasPressed : Keyboard.KeyCode -> Model -> Model
handleWasPressed keyCode model =
    model
        -- In case we did not have a counter on the key
        |> incrementCounter
        |> (\model ->
                { model
                    | keys =
                        updateKey keyCode
                            (getCounter keyCode model.keys
                                |> Maybe.withDefault model.counter
                                |> WasPressed
                            )
                            model.keys
                }
           )


incrementCounter : Model -> Model
incrementCounter model =
    { model | counter = model.counter + 1 }


getCounter : Keyboard.KeyCode -> Keys -> Just Int
getCounter keyCode keys =
    Dict.get keyCode keys
        |> Maybe.andThen
            (\keyStatus ->
                case keyStatus of
                    IsPressed counter ->
                        Just counter

                    WasPressed counter ->
                        Just counter

                    NotPressed ->
                        Nothing
            )


updateKey : Keyboard.KeyCode -> KeyStatus -> Keys -> Keys
updateKey keyCode status keys =
    -- Do not store keys we do not care about
    if Dict.member keyCode keyCodeToDirection then
        Dict.insert keyCode status keys
    else
        keys


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Keyboard.presses KeyPressed
        , Keyboard.downs KeyDown
        , Keyboard.ups KeyUp
        ]
