module GameState.PlayingLevel exposing (..)

import Data.Config exposing (Config)
import Data.Direction as Direction exposing (Direction)
import Actor.Actor as Actor
import Actor.Common as Common
import Dict
import LevelInitializer
import InputController
import Renderer.Canvas.LevelRenderer as LevelRenderer
import Html exposing (Html)
import Actor.CollectorComponent as Collector
import Actor.ControlComponent as Control
import Actor.CameraComponent as Camera
import Actor.DownSmashComponent as DownSmash
import Actor.LifetimeComponent as Lifetime
import Actor.DamageComponent as Damage
import Actor.TriggerExplodableComponent as TriggerExplodable
import Actor.SpawnComponent as Spawn


updateBorder : Int
updateBorder =
    5


type alias Model =
    { config : Config
    , levelConfig : Actor.LevelConfig
    , images : Actor.CanvasImages
    , level : Actor.Level
    }


type Action
    = Stay Model
    | GotoMainMenu


init : Config -> Actor.LevelConfig -> Actor.CanvasImages -> Model
init config levelConfig images =
    { config = config
    , levelConfig = levelConfig
    , images = images
    , level = LevelInitializer.initLevel config levelConfig
    }


updateTick : Int -> InputController.Model -> Model -> Action
updateTick currentTick inputModel model =
    case InputController.getOrderedPressedKeys inputModel |> List.head of
        Just InputController.StartKey ->
            GotoMainMenu

        _ ->
            updateLevel
                (InputController.getCurrentDirection inputModel)
                model.level
                model.levelConfig
                |> setLevel model
                |> Stay


updateLevel : Maybe Direction -> Actor.Level -> Actor.LevelConfig -> Actor.Level
updateLevel maybeDirection level levelConfig =
    List.foldr
        (\y level ->
            List.foldr
                (\x level ->
                    Common.getActorIdsByXY x y level
                        |> List.foldr
                            (\actorId level ->
                                Common.getActorById actorId level
                                    |> Maybe.andThen
                                        (\actor ->
                                            Dict.foldr
                                                (\_ component level ->
                                                    Common.getActorById actorId level
                                                        |> Maybe.andThen
                                                            (\actor ->
                                                                let
                                                                    updatedLevel =
                                                                        case component of
                                                                            Actor.TransformComponent transformData ->
                                                                                Common.updateTransformComponent transformData actor level

                                                                            Actor.CollectorComponent data ->
                                                                                Collector.updateCollectorComponent data actor level

                                                                            Actor.ControlComponent control ->
                                                                                Control.updateControlComponent maybeDirection control actor level

                                                                            Actor.CameraComponent camera ->
                                                                                Camera.updateCameraComponent camera actor level

                                                                            Actor.DownSmashComponent downSmash ->
                                                                                DownSmash.updateDownSmashComponent downSmash actor level

                                                                            Actor.LifetimeComponent lifetimeData ->
                                                                                Lifetime.updateLifetimeComponent lifetimeData actor level

                                                                            Actor.DamageComponent damageData ->
                                                                                Damage.updateDamageComponent damageData actor level

                                                                            Actor.TriggerExplodableComponent triggerData ->
                                                                                TriggerExplodable.updateTriggerExplodableComponent triggerData actor level

                                                                            Actor.SpawnComponent spawnData ->
                                                                                Spawn.updateSpawnComponent levelConfig.entities spawnData actor level

                                                                            _ ->
                                                                                level
                                                                in
                                                                    Just updatedLevel
                                                            )
                                                        |> Maybe.withDefault level
                                                )
                                                level
                                                actor.components
                                                |> Just
                                        )
                                    |> Maybe.withDefault level
                            )
                            level
                )
                level
                (List.range (level.view.position.x - updateBorder) (level.view.position.x + level.view.width + updateBorder))
        )
        level
        (List.range (level.view.position.y - updateBorder) (level.view.position.y + level.view.height + updateBorder))


setLevel : Model -> Actor.Level -> Model
setLevel model level =
    { model | level = level }


view : Int -> Model -> Html msg
view currentTick model =
    LevelRenderer.renderLevel currentTick model.level model.images
