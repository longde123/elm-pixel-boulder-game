module Actor.Decoder exposing (defaultBackgrounds, levelConfigDecoder)

import Actor.Actor as Actor
    exposing
        ( AdventAiData
        , AframeCamera
        , AframeRendererData
        , AiComponentData
        , AiType(..)
        , AnimationSetup
        , AreaComponentData
        , AttackComponentData
        , BecomeActorLifetimeActionData
        , CameraComponentData
        , CollectibleComponentData
        , CollectorComponentData
        , Component(..)
        , Components
        , ControlComponentData
        , ControlSettings
        , ControlType(..)
        , CounterComponentData
        , DamageComponentData
        , Entities
        , EventAction(..)
        , GameOfLifeAiAction
        , GameOfLifeAiData
        , HealthComponentData
        , Image
        , ImageType(..)
        , ImageTypeData
        , Images
        , ImagesData
        , InputControlData
        , Inventory
        , InventoryUpdatedSubscriberData
        , KeyedComponent
        , LevelCompletedData
        , LevelConfig
        , LevelFailedData
        , LevelFinishedDescriptionProvider(..)
        , LifetimeAction(..)
        , LifetimeComponentData
        , LinkImageData
        , LoadLevelData
        , MovementComponentData
        , MovingDownState(..)
        , MovingState(..)
        , ObjectAssets
        , ObjectPresetData
        , ObjectPresetName
        , ObjectPresets
        , ObjectSettings
        , ObjectTypeData
        , Objects
        , OffsetType(..)
        , PatternImageData
        , PhysicsComponentData
        , PixelTypeData
        , PositionOffsets
        , RenderComponentData
        , RenderType(..)
        , Renderer(..)
        , Scene
        , Shape(..)
        , Signs
        , SpawnComponentData
        , SpawnRepeat
        , SpawnRepeatTimes(..)
        , Subscriber
        , TagComponentData
        , TagDiedSubscriberData
        , TriggerAction(..)
        , TriggerComponentData
        , TriggerExplodableComponentData
        , TriggerSendTextData
        , WalkAroundAiControlData
        )
import Color exposing (Color)
import Data.Config exposing (Config)
import Data.Coordinate exposing (Coordinate)
import Data.Direction as Direction exposing (Direction)
import Data.Position exposing (Position)
import Data.Rotation exposing (Rotation)
import Dict exposing (Dict)
import GameState.PlayingLevel.Animation.CurrentTick as CurrentTickAnimation
import GameState.PlayingLevel.Animation.PseudoRandomTraversal as PseudoRandomTraversalAnimation
import GameState.PlayingLevel.Animation.ReadingDirection as ReadingDirectionAnimation
import GameState.PlayingLevel.Animation.Skip as SkipAnimation
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as JDP
import Maybe.Extra
import Util.PrimeSearch as PrimeSearch


defaultCameraBorderSize : Int
defaultCameraBorderSize =
    3


levelConfigDecoder : Decoder LevelConfig
levelConfigDecoder =
    Decode.succeed LevelConfig
        |> JDP.required "entities" entitiesDecoder
        |> JDP.optional "signLength" Decode.int 1
        |> JDP.required "signs" signsDecoder
        |> JDP.required "scene" sceneDecoder
        |> JDP.optional "viewCoordinate" coordinateDecoder defaultViewCoordinate
        |> JDP.optional "updateBorder" Decode.int defaultUpdateBorder
        |> JDP.optional "images" imagesDecoder Dict.empty
        |> JDP.optional "objects" objectDecoder defaultObjects
        |> JDP.optional "backgrounds" (Decode.list renderDataDecoder) defaultBackgrounds
        |> JDP.optional "subscribers" (Decode.list subscriberDecoder) []
        |> JDP.optional "config" (Decode.maybe configDecoder) Nothing
        |> JDP.optional "renderer" decodeRenderer SvgRenderer


defaultObjects : Objects
defaultObjects =
    { assets = Dict.empty
    , presets = Dict.empty
    }


decodeRenderer : Decoder Renderer
decodeRenderer =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "svg" ->
                        Decode.succeed SvgRenderer

                    "aframe" ->
                        Decode.map AframeRenderer <| Decode.field "data" aframeRendererDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode renderer, but renderer "
                                ++ theType
                                ++ " is not supported"
            )


aframeRendererDecoder : Decoder AframeRendererData
aframeRendererDecoder =
    Decode.succeed AframeRendererData
        |> JDP.optional "camera" aframeCameraDecoder defaultAframeCamera


aframeCameraDecoder : Decoder AframeCamera
aframeCameraDecoder =
    Decode.succeed AframeCamera
        |> JDP.optional "rotation" rotationDecoder defaultAframeCamera.rotation
        |> JDP.optional "offsets" positionOffsetsDecoder defaultAframeCamera.offsets


rotationDecoder : Decoder Rotation
rotationDecoder =
    Decode.succeed Rotation
        |> JDP.optional "x" Decode.float 0.0
        |> JDP.optional "y" Decode.float 0.0
        |> JDP.optional "z" Decode.float 0.0


defaultAframeCamera : AframeCamera
defaultAframeCamera =
    { rotation = defaultRotation
    , offsets = emptyPositionOffsets
    }


defaultRotation : Rotation
defaultRotation =
    { x = 0.0
    , y = 0.0
    , z = 0.0
    }


defaultBackgrounds : List RenderComponentData
defaultBackgrounds =
    []


configDecoder : Decoder Config
configDecoder =
    Decode.succeed Config
        |> JDP.required "width" Decode.int
        |> JDP.required "height" Decode.int
        |> JDP.required "pixelSize" Decode.int
        |> JDP.required "additionalViewBorder" Decode.int
        |> JDP.hardcoded 20


entitiesDecoder : Decoder Entities
entitiesDecoder =
    Decode.dict componentsDecoder


componentsDecoder : Decoder Components
componentsDecoder =
    Decode.list componentDecoder
        |> Decode.andThen
            (\keyedComponents ->
                Decode.succeed <| Dict.fromList keyedComponents
            )


componentDecoder : Decoder KeyedComponent
componentDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                (case theType of
                    "ai" ->
                        Decode.map AiComponent <| Decode.field "data" aiDataDecoder

                    "zarea" ->
                        Decode.map AreaComponent <| Decode.field "data" areaDataDecoder

                    "control" ->
                        Decode.map ControlComponent <| Decode.field "data" controlDataDecoder

                    "camera" ->
                        Decode.map CameraComponent <| Decode.field "data" cameraDataDecoder

                    "lifetime" ->
                        Decode.map LifetimeComponent <| Decode.field "data" lifetimeDataDecoder

                    "damage" ->
                        Decode.map DamageComponent <| Decode.field "data" damageDataDecoder

                    "collectible" ->
                        Decode.map CollectibleComponent <| Decode.field "data" collectibleDecoder

                    "collector" ->
                        Decode.map CollectorComponent <| Decode.field "data" collectorDecoder

                    "explodable" ->
                        Decode.succeed ExplodableComponent

                    "physics" ->
                        Decode.map PhysicsComponent <| Decode.field "data" physicsDataDecoder

                    "render" ->
                        Decode.map RenderComponent <| Decode.field "data" renderDataDecoder

                    "rigid" ->
                        Decode.succeed RigidComponent

                    "trigger-explodable" ->
                        Decode.map TriggerExplodableComponent <| Decode.field "data" triggerExplodableDataDecoder

                    "smash-down" ->
                        Decode.succeed <| DownSmashComponent { movingDownState = NotMovingDown }

                    "spawn" ->
                        Decode.map SpawnComponent <| Decode.field "data" spawnDataDecoder

                    "tag" ->
                        Decode.map TagComponent <| Decode.field "data" tagDataDecoder

                    "health" ->
                        Decode.map HealthComponent <| Decode.field "data" healthDataDecoder

                    "attack" ->
                        Decode.map AttackComponent <| Decode.field "data" attackDataDecoder

                    "counter" ->
                        Decode.map CounterComponent <| Decode.field "data" counterDataDecoder

                    "movement" ->
                        Decode.map MovementComponent <| Decode.field "data" movementDataDecoder

                    "trigger" ->
                        Decode.map TriggerComponent <| Decode.field "data" triggerDataDecoder

                    "trigger-activator" ->
                        Decode.succeed <| TriggerActivatorComponent {}

                    _ ->
                        Decode.fail <|
                            "Trying to decode component, but type "
                                ++ theType
                                ++ " is not supported"
                )
                    |> Decode.andThen
                        (\component ->
                            Decode.succeed ( theType, component )
                        )
            )


triggerDataDecoder : Decoder TriggerComponentData
triggerDataDecoder =
    Decode.succeed TriggerComponentData
        |> JDP.required "action" triggerActionDecoder


triggerActionDecoder : Decoder TriggerAction
triggerActionDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "send-text" ->
                        Decode.map TriggerSendText <| Decode.field "data" triggerSendTextDataDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode trigger action, but the type "
                                ++ theType
                                ++ " is not supported."
            )


triggerSendTextDataDecoder : Decoder TriggerSendTextData
triggerSendTextDataDecoder =
    Decode.succeed TriggerSendTextData
        |> JDP.required "message" Decode.string


renderDataDecoder : Decoder RenderComponentData
renderDataDecoder =
    Decode.succeed RenderComponentData
        |> JDP.required "renderType" renderObjectDecoder
        |> JDP.optional "layer" Decode.int 1


renderObjectDecoder : Decoder RenderType
renderObjectDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "pixel" ->
                        Decode.map PixelRenderType <| Decode.field "data" renderPixelDataDecoder

                    "image" ->
                        Decode.map ImageRenderType <| Decode.field "data" renderImageDataDecoder

                    "object" ->
                        Decode.map ObjectRenderType <| Decode.field "data" renderObjectDataDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode render, but the objectType "
                                ++ theType
                                ++ " is not supported."
            )


renderPixelDataDecoder : Decoder PixelTypeData
renderPixelDataDecoder =
    Decode.succeed PixelTypeData
        |> JDP.required "colors" (Decode.list colorDecoder)
        |> JDP.optional "ticksPerColor" Decode.int 1


renderImageDataDecoder : Decoder ImageTypeData
renderImageDataDecoder =
    Decode.succeed ImageTypeData
        |> JDP.required "default" imagesDataDecoder
        |> JDP.optional "direction" decodeDirectionImagesData Dict.empty


type alias DirectionNames =
    { directionId : Int
    , entityNames : List String
    }


imagesDataDecoder : Decoder ImagesData
imagesDataDecoder =
    Decode.succeed ImagesData
        |> JDP.required "names" (Decode.list Decode.string)
        |> JDP.optional "ticksPerImage" Decode.int 1


decodeDirectionImagesData : Decoder (Dict Int ImagesData)
decodeDirectionImagesData =
    Decode.dict imagesDataDecoder
        |> Decode.andThen
            (\dict ->
                Dict.toList dict
                    |> List.map
                        (\( directionName, imagesData ) ->
                            Direction.getIDFromKey directionName
                                |> Maybe.map
                                    (\directionId ->
                                        ( directionId, imagesData )
                                    )
                        )
                    |> Maybe.Extra.values
                    |> Dict.fromList
                    |> (\newDict ->
                            if Dict.size dict == Dict.size newDict then
                                Decode.succeed newDict

                            else
                                Decode.fail "There are invalid directions in the render image data"
                       )
            )


renderObjectDataDecoder : Decoder ObjectTypeData
renderObjectDataDecoder =
    Decode.succeed ObjectTypeData
        |> JDP.required "default" objectPresetNameDecoder
        |> JDP.optional "direction" objectTypeDirectionDecoder Dict.empty


objectTypeDirectionDecoder : Decoder (Dict Int ObjectPresetName)
objectTypeDirectionDecoder =
    Decode.dict objectPresetNameDecoder
        |> Decode.andThen
            (\dict ->
                Dict.toList dict
                    |> List.map
                        (\( directionName, imagesData ) ->
                            Direction.getIDFromKey directionName
                                |> Maybe.map (\directionId -> ( directionId, imagesData ))
                        )
                    |> Maybe.Extra.values
                    |> Dict.fromList
                    |> (\newDict ->
                            if Dict.size dict == Dict.size newDict then
                                Decode.succeed newDict

                            else
                                Decode.fail "There are invalid directions in the render object data"
                       )
            )


objectPresetNameDecoder : Decoder ObjectPresetName
objectPresetNameDecoder =
    Decode.string


tagDataDecoder : Decoder TagComponentData
tagDataDecoder =
    Decode.succeed TagComponentData
        |> JDP.required "name" Decode.string


healthDataDecoder : Decoder HealthComponentData
healthDataDecoder =
    Decode.succeed HealthComponentData
        |> JDP.required "health" Decode.int
        |> JDP.custom (Decode.at [ "health" ] Decode.int)


attackDataDecoder : Decoder AttackComponentData
attackDataDecoder =
    Decode.succeed AttackComponentData
        |> JDP.required "power" Decode.int


counterDataDecoder : Decoder CounterComponentData
counterDataDecoder =
    Decode.succeed CounterComponentData
        |> JDP.optional "count" Decode.int 0


movementDataDecoder : Decoder MovementComponentData
movementDataDecoder =
    Decode.succeed MovementComponentData
        |> JDP.optional "movingTicks" Decode.int 0
        |> JDP.hardcoded 0
        |> JDP.hardcoded NotMoving


spawnDataDecoder : Decoder SpawnComponentData
spawnDataDecoder =
    Decode.succeed SpawnComponentData
        |> JDP.required "entityName" Decode.string
        |> JDP.required "position" positionDecoder
        |> JDP.optional "delayTicks" Decode.int 0
        |> JDP.optional "repeat" spawnRepeatDecoder spawnNeverRepeat


spawnRepeatDecoder : Decoder SpawnRepeat
spawnRepeatDecoder =
    Decode.succeed SpawnRepeat
        |> JDP.required "times" spawnRepeatTimesDecoder
        |> JDP.required "delayTicks" Decode.int


spawnRepeatTimesDecoder : Decoder SpawnRepeatTimes
spawnRepeatTimesDecoder =
    Decode.oneOf
        [ Decode.string
            |> Decode.andThen
                (\times ->
                    case times of
                        "forever" ->
                            Decode.succeed RepeatForever

                        "never" ->
                            Decode.succeed RepeatNever

                        other ->
                            case String.toInt other of
                                Just timesInt ->
                                    Decode.succeed <| RepeatTimes timesInt

                                _ ->
                                    Decode.fail <|
                                        "Trying to decode spawn repeat times, but the times "
                                            ++ other
                                            ++ " should be something that can be parsed to an int."
                )
        , Decode.int
            |> Decode.andThen
                (\times ->
                    Decode.succeed <| RepeatTimes times
                )
        ]


coordinateDecoder : Decoder Coordinate
coordinateDecoder =
    Decode.succeed Coordinate
        |> JDP.required "x" Decode.int
        |> JDP.required "y" Decode.int


positionDecoder : Decoder Position
positionDecoder =
    Decode.succeed Position
        |> JDP.required "x" Decode.int
        |> JDP.required "y" Decode.int


cameraDataDecoder : Decoder CameraComponentData
cameraDataDecoder =
    Decode.succeed CameraComponentData
        |> JDP.optional "borderLeft" Decode.int defaultCameraBorderSize
        |> JDP.optional "borderUp" Decode.int defaultCameraBorderSize
        |> JDP.optional "borderRight" Decode.int defaultCameraBorderSize
        |> JDP.optional "borderDown" Decode.int defaultCameraBorderSize


physicsDataDecoder : Decoder PhysicsComponentData
physicsDataDecoder =
    Decode.succeed PhysicsComponentData
        |> JDP.required "strength" Decode.int
        |> JDP.required "shape" physicsShapeDecoder


lifetimeDataDecoder : Decoder LifetimeComponentData
lifetimeDataDecoder =
    Decode.succeed LifetimeComponentData
        |> JDP.required "remainingTicks" Decode.int
        |> JDP.optional "action" lifetimeAction RemoveActorLifetimeAction


lifetimeAction : Decoder LifetimeAction
lifetimeAction =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\action ->
                case action of
                    "remove" ->
                        Decode.succeed RemoveActorLifetimeAction

                    "become" ->
                        Decode.map BecomeActorLifetimeAction <| Decode.field "data" becomeActorLifetimeDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode a lifetime action, but the action "
                                ++ action
                                ++ " is not supported."
            )


becomeActorLifetimeDecoder : Decoder BecomeActorLifetimeActionData
becomeActorLifetimeDecoder =
    Decode.succeed BecomeActorLifetimeActionData
        |> JDP.required "entityName" Decode.string


damageDataDecoder : Decoder DamageComponentData
damageDataDecoder =
    Decode.succeed DamageComponentData
        |> JDP.required "damageStrength" Decode.int


triggerExplodableDataDecoder : Decoder TriggerExplodableComponentData
triggerExplodableDataDecoder =
    Decode.succeed TriggerExplodableComponentData
        |> JDP.required "triggerStrength" Decode.int


collectibleDecoder : Decoder CollectibleComponentData
collectibleDecoder =
    Decode.succeed CollectibleComponentData
        |> JDP.required "name" Decode.string
        |> JDP.optional "quantity" Decode.int 1


collectorDecoder : Decoder CollectorComponentData
collectorDecoder =
    Decode.succeed CollectorComponentData
        |> JDP.required "interestedIn" (Decode.list Decode.string)
        |> JDP.optional "inventory" inventoryDecoder Dict.empty


inventoryDecoder : Decoder Inventory
inventoryDecoder =
    Decode.dict Decode.int


physicsShapeDecoder : Decoder Shape
physicsShapeDecoder =
    Decode.string
        |> Decode.andThen
            (\shape ->
                case shape of
                    "circle" ->
                        Decode.succeed Circle

                    "square" ->
                        Decode.succeed Square

                    _ ->
                        Decode.fail <|
                            "Trying to decode a physics shape, but the shape "
                                ++ shape
                                ++ " is not supported."
            )


aiDataDecoder : Decoder AiComponentData
aiDataDecoder =
    Decode.succeed AiComponentData
        |> JDP.required "ai" aiTypeDecoder


aiTypeDecoder : Decoder AiType
aiTypeDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "gameOfLifeAi" ->
                        Decode.map GameOfLifeAi <| Decode.field "data" gameOfLifeAiDataDecoder

                    "advent" ->
                        Decode.map AdventAi <| Decode.field "data" adventAiDataDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode ai components ai type, but the type "
                                ++ theType
                                ++ " is not supported."
            )


gameOfLifeAiDataDecoder : Decoder GameOfLifeAiData
gameOfLifeAiDataDecoder =
    Decode.succeed GameOfLifeAiData
        |> JDP.required "tagToSearch" Decode.string
        |> JDP.optional "delayTicks" Decode.int 8
        |> JDP.custom
            (Decode.oneOf
                [ Decode.at [ "delayTicks" ] Decode.int
                , Decode.succeed 8
                ]
            )
        |> JDP.required "actions" (Decode.list gameOfLifeAiActionDecoder)


gameOfLifeAiActionDecoder : Decoder GameOfLifeAiAction
gameOfLifeAiActionDecoder =
    Decode.succeed GameOfLifeAiAction
        |> JDP.required "count" Decode.int
        |> JDP.required "become" Decode.string


adventAiDataDecoder : Decoder AdventAiData
adventAiDataDecoder =
    Decode.succeed AdventAiData
        |> JDP.required "target" Decode.string


areaDataDecoder : Decoder AreaComponentData
areaDataDecoder =
    Decode.succeed AreaComponentData
        |> JDP.required "width" Decode.int
        |> JDP.required "height" Decode.int
        |> JDP.required "direction" directionDecoder
        |> JDP.required "tags" (Decode.list Decode.string)


controlDataDecoder : Decoder ControlComponentData
controlDataDecoder =
    Decode.succeed ControlComponentData
        |> JDP.optional "settings" controlSettingsDecoder emptyControlSettings
        |> JDP.required "control" controlTypeDecoder
        |> JDP.optional "steps" Decode.int 1
        |> JDP.optional "queue" (Decode.list directionDecoder) []


controlSettingsDecoder : Decoder ControlSettings
controlSettingsDecoder =
    Decode.succeed ControlSettings
        |> JDP.optional "pushStrength" Decode.int emptyControlSettings.pushStrength
        |> JDP.optional "walkOverStrength" Decode.int emptyControlSettings.walkOverStrength


emptyControlSettings : ControlSettings
emptyControlSettings =
    { pushStrength = 0
    , walkOverStrength = 0
    }


controlTypeDecoder : Decoder ControlType
controlTypeDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "input" ->
                        Decode.map InputControl <| Decode.field "data" inputControlDataDecoder

                    "walkAroundAi" ->
                        Decode.map WalkAroundAiControl <| Decode.field "data" walkAroundAiDataDecoder

                    "gravityAi" ->
                        Decode.succeed GravityAiControl

                    _ ->
                        Decode.fail <|
                            "Trying to decode control components control type, but the type "
                                ++ theType
                                ++ " is not supported."
            )


inputControlDataDecoder : Decoder InputControlData
inputControlDataDecoder =
    Decode.succeed InputControlData
        |> JDP.optional "allowedDirections" (Decode.list directionDecoder) []


walkAroundAiDataDecoder : Decoder WalkAroundAiControlData
walkAroundAiDataDecoder =
    Decode.succeed WalkAroundAiControlData
        |> JDP.optional "previousDirection" directionDecoder Direction.Left
        |> JDP.required "nextDirectionOffsets" (Decode.list Decode.int)


directionDecoder : Decoder Direction
directionDecoder =
    Decode.string
        |> Decode.andThen
            (\direction ->
                case direction of
                    "left" ->
                        Decode.succeed Direction.Left

                    "up" ->
                        Decode.succeed Direction.Up

                    "right" ->
                        Decode.succeed Direction.Right

                    "down" ->
                        Decode.succeed Direction.Down

                    _ ->
                        Decode.fail <|
                            "Trying to decode direction, but the direction "
                                ++ direction
                                ++ " is not supported. Supported directions are: left, up, right, down."
            )


directionIdDecoder : Decoder Int
directionIdDecoder =
    directionDecoder
        |> Decode.andThen
            (\direction ->
                Decode.succeed <| Direction.getIDFromDirection direction
            )



-- @TODO Implement


colorDecoder : Decoder Color
colorDecoder =
    Decode.succeed (\r g b -> Color.rgb255 r g b)
        |> JDP.required "red" Decode.int
        |> JDP.required "green" Decode.int
        |> JDP.required "blue" Decode.int


signsDecoder : Decoder Signs
signsDecoder =
    Decode.dict Decode.string


sceneDecoder : Decoder Scene
sceneDecoder =
    Decode.list Decode.string


imagesDecoder : Decoder Images
imagesDecoder =
    Decode.dict imageDecoder


imageDecoder : Decoder Image
imageDecoder =
    Decode.succeed Image
        |> JDP.required "path" Decode.string
        |> JDP.required "width" Decode.int
        |> JDP.required "height" Decode.int
        |> JDP.optional "imageType" imageTypeDecoder defaultImageType
        |> JDP.optional "xOffset" Decode.int 0
        |> JDP.optional "yOffset" Decode.int 0


imageTypeDecoder : Decoder ImageType
imageTypeDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "regular" ->
                        Decode.succeed RegularImage

                    "pattern" ->
                        Decode.map PatternImage <| Decode.field "data" decodePatternImageData

                    "link" ->
                        Decode.map LinkImage <| Decode.field "data" decodeLinkImageData

                    _ ->
                        Decode.fail <|
                            "Trying to decode imageType, but the type "
                                ++ theType
                                ++ " is not supported."
            )


defaultImageType : ImageType
defaultImageType =
    RegularImage


decodePatternImageData : Decoder PatternImageData
decodePatternImageData =
    Decode.succeed PatternImageData
        |> JDP.optional "offsets" positionOffsetsDecoder emptyPositionOffsets


decodeLinkImageData : Decoder LinkImageData
decodeLinkImageData =
    Decode.succeed LinkImageData
        |> JDP.required "href" Decode.string


offsetTypeDecoder : Decoder OffsetType
offsetTypeDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "fixed" ->
                        Decode.map FixedOffset <| Decode.field "data" Decode.float

                    "view_x_multiplier" ->
                        Decode.map MultipliedByViewX <| Decode.field "data" Decode.float

                    "view_y_multiplier" ->
                        Decode.map MultipliedByViewY <| Decode.field "data" Decode.float

                    "view_offset_x" ->
                        Decode.succeed ViewOffsetX

                    "view_offset_y" ->
                        Decode.succeed ViewOffsetY

                    _ ->
                        Decode.fail <|
                            "Trying to decode imageType, but the type "
                                ++ theType
                                ++ " is not supported."
            )


objectDecoder : Decoder Objects
objectDecoder =
    Decode.succeed Objects
        |> JDP.optional "assets" objectAssertsDecoder defaultObjects.assets
        |> JDP.optional "presets" objectPresetsDecoder defaultObjects.presets


objectAssertsDecoder : Decoder ObjectAssets
objectAssertsDecoder =
    Decode.dict Decode.string


objectPresetsDecoder : Decoder ObjectPresets
objectPresetsDecoder =
    Decode.dict objectPresetDataDecoder


objectPresetDataDecoder : Decoder ObjectPresetData
objectPresetDataDecoder =
    Decode.succeed ObjectPresetData
        |> JDP.optional "settings" decodeObjectSettingsDecoder Dict.empty
        |> JDP.optional "offsets" positionOffsetsDecoder emptyPositionOffsets


positionOffsetsDecoder : Decoder PositionOffsets
positionOffsetsDecoder =
    Decode.succeed PositionOffsets
        |> JDP.optional "x" (Decode.list offsetTypeDecoder) []
        |> JDP.optional "y" (Decode.list offsetTypeDecoder) []
        |> JDP.optional "z" (Decode.list offsetTypeDecoder) []


emptyPositionOffsets : PositionOffsets
emptyPositionOffsets =
    { x = []
    , y = []
    , z = []
    }


decodeObjectSettingsDecoder : Decoder ObjectSettings
decodeObjectSettingsDecoder =
    Decode.dict Decode.string


subscriberDecoder : Decoder Subscriber
subscriberDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "onTagDied" ->
                        Decode.succeed Actor.TagDiedSubscriber
                            |> JDP.required "eventActionData" eventActionDecoder
                            |> JDP.required "tagDiedData" onTagDiedSubscriberDecoder

                    "onInventoryUpdated" ->
                        Decode.succeed Actor.InventoryUpdatedSubscriber
                            |> JDP.required "eventActionData" eventActionDecoder
                            |> JDP.required "inventoryUpdatedData" onInventoryUpdatedSubscriberDecoder

                    "onTriggerActivated" ->
                        Decode.succeed Actor.TriggerActivatedSubscriber

                    _ ->
                        Decode.fail <|
                            "Trying to decode subscriber, but the type "
                                ++ theType
                                ++ " is not supported."
            )


onTagDiedSubscriberDecoder : Decoder TagDiedSubscriberData
onTagDiedSubscriberDecoder =
    Decode.succeed TagDiedSubscriberData
        |> JDP.required "tagName" Decode.string
        |> JDP.optional "limit" Decode.int 1
        |> JDP.hardcoded 0


onInventoryUpdatedSubscriberDecoder : Decoder InventoryUpdatedSubscriberData
onInventoryUpdatedSubscriberDecoder =
    Decode.succeed InventoryUpdatedSubscriberData
        |> JDP.required "interestedIn" Decode.string
        |> JDP.required "minimumQuantity" Decode.int


eventActionDecoder : Decoder EventAction
eventActionDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "failed" ->
                        Decode.map LevelFailed <| Decode.field "data" eventActionFailedDataDecoder

                    "completed" ->
                        Decode.map LevelCompleted <| Decode.field "data" eventActionCompletedDataDecoder

                    "loadLevel" ->
                        Decode.map LoadLevel <| Decode.field "data" eventActionLoadLevelDataDecoder

                    _ ->
                        Decode.fail <|
                            "Trying to decode subscriber action, but the type "
                                ++ theType
                                ++ " is not supported."
            )


eventActionFailedDataDecoder : Decoder LevelFailedData
eventActionFailedDataDecoder =
    Decode.succeed LevelFailedData
        |> JDP.required "descriptionProvider" descriptionProviderDecoder
        |> JDP.required "entityNames" (Decode.list Decode.string)
        |> JDP.required "animation" animationSetupDecoder


eventActionCompletedDataDecoder : Decoder LevelCompletedData
eventActionCompletedDataDecoder =
    Decode.succeed LevelCompletedData
        |> JDP.required "descriptionProvider" descriptionProviderDecoder
        |> JDP.required "nextLevel" Decode.string
        |> JDP.required "entityNames" (Decode.list Decode.string)
        |> JDP.required "animation" animationSetupDecoder


eventActionLoadLevelDataDecoder : Decoder LoadLevelData
eventActionLoadLevelDataDecoder =
    Decode.succeed LoadLevelData
        |> JDP.required "nextLevel" Decode.string


descriptionProviderDecoder : Decoder LevelFinishedDescriptionProvider
descriptionProviderDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "static" ->
                        Decode.map StaticDescriptionProvider <| Decode.field "data" staticDescriptionProviderDecoder

                    "advent" ->
                        Decode.succeed AdventOfCodeDescriptionProvider

                    _ ->
                        Decode.fail <|
                            "Trying to decode description, but the type "
                                ++ theType
                                ++ " is not supported."
            )


staticDescriptionProviderDecoder : Decoder String
staticDescriptionProviderDecoder =
    Decode.field "text" Decode.string


animationSetupDecoder : Decoder AnimationSetup
animationSetupDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\theType ->
                case theType of
                    "readingDirection" ->
                        Decode.succeed ReadingDirectionAnimation.init

                    "pseudoRandomTraversal" ->
                        Decode.field "data" pseudoRandomTraversalAnimationSetupDecoder

                    "currentTick" ->
                        Decode.succeed CurrentTickAnimation.init

                    "skip" ->
                        Decode.succeed SkipAnimation.init

                    _ ->
                        Decode.fail <|
                            "Trying to decode animation, but the type "
                                ++ theType
                                ++ " is not supported."
            )


pseudoRandomTraversalAnimationSetupDecoder : Decoder AnimationSetup
pseudoRandomTraversalAnimationSetupDecoder =
    Decode.field "coefficients" coefficientsDecoder
        |> Decode.andThen
            (\coefficients ->
                Decode.succeed <| PseudoRandomTraversalAnimation.init coefficients
            )


coefficientsDecoder : Decoder PrimeSearch.Coefficients
coefficientsDecoder =
    Decode.succeed PrimeSearch.Coefficients
        |> JDP.required "a" Decode.int
        |> JDP.required "b" Decode.int
        |> JDP.required "c" Decode.int


spawnNeverRepeat : SpawnRepeat
spawnNeverRepeat =
    { times = RepeatNever
    , delayTicks = 0
    }


defaultViewCoordinate : Coordinate
defaultViewCoordinate =
    { x = 0
    , y = 0
    }


defaultUpdateBorder : Int
defaultUpdateBorder =
    5
