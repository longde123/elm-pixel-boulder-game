module Renderer.Aframe.LevelRenderer exposing (renderLevel)

import Actor.Actor as Actor exposing (Level, LevelConfig)
import Actor.Common as Common
import Actor.Component.RenderComponent as Render
import Color exposing (Color)
import Data.Config exposing (Config)
import Data.Coordinate as Coordinate exposing (Coordinate)
import Data.Direction as Direction exposing (Direction)
import Data.Position exposing (Position)
import Dict exposing (Dict)
import Html exposing (Html, node)
import Html.Attributes exposing (attribute)
import Html.Keyed
import List.Extra
import Maybe.Extra
import String
import Util.Util as Util


type alias Vec3 =
    { x : Float
    , y : Float
    , z : Float
    }


renderLevel : Int -> Level -> LevelConfig -> Html msg
renderLevel currentTick level levelConfig =
    let
        elements =
            Util.fastConcat
                [ [ drawAssets levelConfig ]
                , drawLevel currentTick level levelConfig
                ]

        fillingElements =
            List.repeat (200 - List.length elements) ( "", Html.div [] [] )
                |> List.indexedMap
                    (\index ( _, html ) ->
                        ( "element-" ++ String.fromInt index, html )
                    )

        totalList =
            List.append elements fillingElements
                |> List.indexedMap
                    (\index ( _, html ) ->
                        ( "element-" ++ String.fromInt index, html )
                    )

        alternativeTotalList =
            List.append elements fillingElements

        _ =
            Debug.log "lenght" <| String.fromInt <| List.length elements
    in
    --    Util.fastConcat
    --        [ [ drawAssets levelConfig ]
    --        , drawLevel currentTick level levelConfig
    --        ]
    --        |> Html.Keyed.node "a-scene" []
    Html.Keyed.node "a-scene" [] totalList


drawAssets : LevelConfig -> ( String, Html msg )
drawAssets levelConfig =
    Util.fastConcat
        [ Dict.toList levelConfig.images |> List.map drawLoadImage
        , Dict.toList levelConfig.objects.assets |> List.map drawLoadObjectAsset
        ]
        |> node "a-assets" []
        |> (\html -> ( "the-assets", html ))


drawLoadImage : ( String, Actor.Image ) -> Html msg
drawLoadImage ( name, image ) =
    case image.imageType of
        Actor.RegularImage ->
            node "img"
                [ attribute "id" <| "image-" ++ name
                , attribute "src" image.path
                ]
                []

        Actor.PatternImage patternImageData ->
            node "img"
                [ attribute "id" <| "image-" ++ name
                , attribute "src" image.path
                ]
                []

        Actor.LinkImage linkData ->
            node "img"
                [ attribute "id" <| "image-" ++ name
                , attribute "src" image.path
                ]
                []


drawLoadObjectAsset : ( String, String ) -> Html msg
drawLoadObjectAsset ( name, path ) =
    node "a-asset-item"
        [ attribute "id" <| "asset-" ++ name
        , attribute "src" path
        ]
        []


drawCamera : Level -> LevelConfig -> Position -> Position -> ( String, Html msg )
drawCamera level levelConfig viewPositionCoordinate viewPixelOffset =
    let
        x =
            (toFloat level.view.coordinate.x / toFloat level.config.pixelSize) + (toFloat level.config.width / 2.0)

        y =
            (toFloat level.view.coordinate.y / toFloat level.config.pixelSize) + (toFloat level.config.height / 2.0)

        xOffset =
            toFloat viewPixelOffset.x / toFloat level.config.pixelSize

        yOffset =
            toFloat viewPixelOffset.y / toFloat level.config.pixelSize

        x2 =
            toFloat viewPositionCoordinate.x + (toFloat level.config.width / 2.0) - xOffset

        y2 =
            toFloat viewPositionCoordinate.y + (toFloat level.config.height / 2.0) - yOffset
    in
    ( "the-camera"
    , node "a-camera"
        [ attribute "position" <|
            String.join " "
                [ String.fromFloat x2
                , String.fromFloat (y2 * -1)
                , "7"
                ]
        , attribute "wasd-controls" "enabled: false;"
        ]
        []
    )



--    node "a-camera"
--        [ Attributes.attribute "position" <|
--            String.join " "
--                [ String.fromFloat x
--                , String.fromFloat (y * -1)
--                , "20"
--                ]
--        , Attributes.attribute "wasd-controls" "enabled: false;"
--        ]
--        []


drawLevel : Int -> Level -> LevelConfig -> List ( String, Html msg )
drawLevel tick level levelConfig =
    let
        view =
            level.view

        xPixelOffset =
            modBy level.config.pixelSize view.coordinate.x

        yPixelOffset =
            modBy level.config.pixelSize view.coordinate.y

        viewPixelOffset =
            { x = xPixelOffset * -1
            , y = yPixelOffset * -1
            }

        xBasePosition =
            Coordinate.pixelToTile level.config.pixelSize view.coordinate.x - level.config.additionalViewBorder

        yBasePosition =
            Coordinate.pixelToTile level.config.pixelSize view.coordinate.y - level.config.additionalViewBorder

        viewPositionCoordinate =
            { x =
                if view.coordinate.x < 0 && viewPixelOffset.x /= 0 then
                    xBasePosition - 1 + level.config.additionalViewBorder

                else
                    xBasePosition + level.config.additionalViewBorder
            , y =
                if view.coordinate.y < 0 && viewPixelOffset.y /= 0 then
                    yBasePosition - 1 + level.config.additionalViewBorder

                else
                    yBasePosition + level.config.additionalViewBorder
            }

        xEndPosition =
            xBasePosition + level.config.width + (level.config.additionalViewBorder * 2)

        yEndPosition =
            yBasePosition + level.config.height + (level.config.additionalViewBorder * 2)

        drawEnvironment givenAcc =
            List.foldr
                (\y acc ->
                    List.range (xBasePosition - level.config.additionalEnvironment) xEndPosition
                        |> List.foldr
                            (\x innerAcc ->
                                drawActors
                                    tick
                                    viewPositionCoordinate
                                    { x = x, y = y }
                                    viewPixelOffset
                                    level
                                    levelConfig
                                    (Common.getEnvironmentActorsByPosition { x = x, y = y } level)
                                    innerAcc
                            )
                            acc
                )
                givenAcc
                (List.range (yBasePosition - level.config.additionalEnvironment) yEndPosition)

        drawOtherActors givenAcc =
            List.foldr
                (\y acc ->
                    List.range xBasePosition xEndPosition
                        |> List.foldr
                            (\x innerAcc ->
                                drawActors
                                    tick
                                    viewPositionCoordinate
                                    { x = x, y = y }
                                    viewPixelOffset
                                    level
                                    levelConfig
                                    (Common.getActorsByPosition { x = x, y = y } level)
                                    innerAcc
                            )
                            acc
                )
                givenAcc
                (List.range yBasePosition yEndPosition)
    in
    Util.fastConcat
        [ drawEnvironment []
        , drawOtherActors []
        , [ drawCamera level levelConfig viewPositionCoordinate viewPixelOffset ]
        ]


type alias RenderRequirements =
    { actorId : Int
    , tick : Int
    , viewPositionCoordinate : Position
    , position : Position
    , pixelOffset : Coordinate
    , render : Actor.RenderComponentData
    , transform : Actor.TransformComponentData
    , maybeTowards : Maybe Actor.MovingTowardsData
    }


drawActors : Int -> Position -> Position -> Coordinate -> Level -> LevelConfig -> List Actor.Actor -> List ( String, Html msg ) -> List ( String, Html msg )
drawActors tick viewPositionCoordinate position pixelOffset level levelConfig actors acc =
    let
        asRenderRequirements : Actor.Actor -> Maybe RenderRequirements
        asRenderRequirements actor =
            Maybe.map3
                (RenderRequirements actor.id tick viewPositionCoordinate position pixelOffset)
                (Render.getRenderComponent actor)
                (Common.getTransformComponent actor)
                (Common.getMovementComponent actor
                    |> Maybe.map Common.getMovingTowardsData
                    |> Maybe.withDefault Nothing
                    |> Just
                )
    in
    actors
        |> List.filterMap asRenderRequirements
        |> List.foldr
            (\renderRequirements innerAcc -> drawRenderRequirements renderRequirements levelConfig level innerAcc)
            acc


drawRenderRequirements : RenderRequirements -> LevelConfig -> Level -> List ( String, Html msg ) -> List ( String, Html msg )
drawRenderRequirements renderRequirements levelConfig level acc =
    let
        pixelSize : Float
        pixelSize =
            toFloat level.config.pixelSize

        asXPoint : Int -> Float
        asXPoint givenX =
            toFloat givenX

        -- toFloat renderRequirements.viewPositionCoordinate.x + (toFloat renderRequirements.pixelOffset.x / pixelSize)
        asYPoint : Int -> Float
        asYPoint givenY =
            toFloat givenY

        -- toFloat renderRequirements.viewPositionCoordinate.y + (toFloat renderRequirements.pixelOffset.y / pixelSize)
        xPoint =
            asXPoint renderRequirements.transform.position.x

        yPoint =
            asYPoint renderRequirements.transform.position.y

        zPoint =
            toFloat renderRequirements.render.layer / pixelSize

        imageNotMovingOp : Actor.ImageTypeData -> List ( String, Html msg )
        imageNotMovingOp imageData =
            getImageName renderRequirements.tick imageData.default
                |> Maybe.map (renderImage renderRequirements.actorId pixelSize xPoint yPoint zPoint levelConfig.images)
                |> Maybe.map (List.append acc)
                |> Maybe.withDefault acc

        imageMovingOp : Actor.ImageTypeData -> Actor.MovingTowardsData -> List ( String, Html msg )
        imageMovingOp imageData towardsData =
            let
                xDestPoint =
                    asXPoint towardsData.position.x

                yDestPoint =
                    asYPoint towardsData.position.y

                asMovementLocation : Float -> Float -> Float -> Float
                asMovementLocation xCurrent xDest completion =
                    (xDest - xCurrent) / 100.0 * completion + xCurrent

                xFinal =
                    asMovementLocation xPoint xDestPoint towardsData.completionPercentage

                yFinal =
                    asMovementLocation yPoint yDestPoint towardsData.completionPercentage
            in
            getImageNamesDataByDirection towardsData.direction imageData
                |> getImageName renderRequirements.tick
                |> Maybe.map (renderImage renderRequirements.actorId pixelSize xFinal yFinal zPoint levelConfig.images)
                |> Maybe.map (List.append acc)
                |> Maybe.withDefault acc

        pixelNotMovingOp : Actor.PixelTypeData -> List ( String, Html msg )
        pixelNotMovingOp pixelData =
            let
                pixelElement : ( String, Html msg )
                pixelElement =
                    asPixel
                        level.config
                        renderRequirements.actorId
                        xPoint
                        yPoint
                        (getColor renderRequirements.tick pixelData)
            in
            pixelElement :: acc

        pixelMovingOp : Actor.PixelTypeData -> Actor.MovingTowardsData -> List ( String, Html msg )
        pixelMovingOp pixelData towardsData =
            let
                xDestPoint =
                    asXPoint towardsData.position.x

                yDestPoint =
                    asYPoint towardsData.position.y

                originElement : ( String, Html msg )
                originElement =
                    asPixel
                        level.config
                        renderRequirements.actorId
                        xPoint
                        yPoint
                        (getColor renderRequirements.tick pixelData |> withCompletionPercentage (100 - towardsData.completionPercentage))

                destinationElement : ( String, Html msg )
                destinationElement =
                    asPixel
                        level.config
                        (renderRequirements.actorId + 10000000)
                        xDestPoint
                        yDestPoint
                        (getColor renderRequirements.tick pixelData |> withCompletionPercentage towardsData.completionPercentage)
            in
            originElement :: destinationElement :: acc

        objectNotMovingOp : Actor.ObjectTypeData -> List ( String, Html msg )
        objectNotMovingOp objectData =
            presetNameToHtml { x = xPoint, y = yPoint, z = zPoint } renderRequirements.actorId levelConfig.objects.presets objectData.default
                |> Maybe.map (\objectHtml -> objectHtml :: acc)
                |> Maybe.withDefault acc

        objectMovingOp : Actor.ObjectTypeData -> Actor.MovingTowardsData -> List ( String, Html msg )
        objectMovingOp objectData towardsData =
            let
                xDestPoint =
                    asXPoint towardsData.position.x

                yDestPoint =
                    asYPoint towardsData.position.y

                asMovementLocation : Float -> Float -> Float -> Float
                asMovementLocation xCurrent xDest completion =
                    (xDest - xCurrent) / 100.0 * completion + xCurrent

                xFinal =
                    asMovementLocation xPoint xDestPoint towardsData.completionPercentage

                yFinal =
                    asMovementLocation yPoint yDestPoint towardsData.completionPercentage
            in
            getPresetNameByDirection towardsData.direction objectData
                |> presetNameToHtml { x = xFinal, y = yFinal, z = zPoint } renderRequirements.actorId levelConfig.objects.presets
                |> Maybe.map (\objectHtml -> objectHtml :: acc)
                |> Maybe.withDefault acc
    in
    case ( renderRequirements.render.renderType, renderRequirements.maybeTowards ) of
        ( Actor.PixelRenderType pixelData, Nothing ) ->
            pixelNotMovingOp pixelData

        ( Actor.PixelRenderType pixelData, Just towardsData ) ->
            pixelMovingOp pixelData towardsData

        ( Actor.ImageRenderType imageData, Nothing ) ->
            imageNotMovingOp imageData

        ( Actor.ImageRenderType imageData, Just towardsData ) ->
            imageMovingOp imageData towardsData

        ( Actor.ObjectRenderType objectData, Nothing ) ->
            objectNotMovingOp objectData

        ( Actor.ObjectRenderType objectData, Just towardsData ) ->
            objectMovingOp objectData towardsData


presetNameToHtml : Vec3 -> Int -> Actor.ObjectPresets -> Actor.ObjectPresetName -> Maybe ( String, Html msg )
presetNameToHtml position actorId presets presetName =
    Dict.get presetName presets
        |> Maybe.map (presetToHtml position actorId)


presetToHtml : Vec3 -> Int -> Actor.ObjectPresetData -> ( String, Html msg )
presetToHtml position actorId preset =
    ( "actor-" ++ String.fromInt actorId
    , node "a-gltf-model"
        (List.append
            [ attribute "src" <| "#asset-" ++ preset.assetName
            , attribute "position" <|
                String.join " "
                    [ String.fromFloat (position.x + preset.xOffset)
                    , String.fromFloat ((position.y + preset.yOffset) * -1)
                    , String.fromFloat (position.z + preset.zOffset)
                    ]
            ]
            (preset.settings
                |> Dict.toList
                |> List.map
                    (\( settingKey, settingData ) ->
                        attribute settingKey settingData
                    )
            )
        )
        []
    )


renderImage : Int -> Float -> Float -> Float -> Float -> Actor.Images -> String -> List ( String, Html msg )
renderImage actorId pixelSize x y z images imageName =
    let
        asImage : Actor.Image -> List (Html.Attribute msg) -> ( String, Html msg )
        asImage image additionalAttributes =
            ( "actor" ++ String.fromInt actorId
            , node "a-image"
                (List.append
                    [ attribute "material" <|
                        String.join ""
                            [ "src: #image-"
                            , imageName
                            , "; transparent: true;"
                            ]
                    , attribute "position" <|
                        String.join " "
                            [ String.fromFloat <| x + (toFloat image.xOffset / pixelSize) + (toFloat image.width / pixelSize / 2.0)
                            , String.fromFloat <| (y + (toFloat image.yOffset / pixelSize) + (toFloat image.height / pixelSize / 2.0)) * -1.0
                            , String.fromFloat z
                            ]
                    , attribute "geometry" <|
                        String.join ""
                            [ "width: "
                            , String.fromFloat <| (toFloat image.width / pixelSize)
                            , "; height: "
                            , String.fromFloat <| (toFloat image.height / pixelSize)
                            , ";"
                            ]
                    ]
                    additionalAttributes
                )
                []
            )
    in
    Dict.get imageName images
        |> Maybe.map
            (\image ->
                case image.imageType of
                    Actor.RegularImage ->
                        asImage image []

                    Actor.PatternImage _ ->
                        asImage image []

                    Actor.LinkImage linkData ->
                        asImage image
                            [ attribute "link" <|
                                String.join ""
                                    [ "href: "
                                    , linkData.href
                                    , ";"
                                    ]
                            ]
            )
        |> Maybe.Extra.toList


withCompletionPercentage : Float -> Color -> Color
withCompletionPercentage completionPercentage color =
    let
        rgba =
            Color.toRgba color

        updatedAlpha =
            { rgba | alpha = rgba.alpha / 100.0 * completionPercentage }
    in
    Color.fromRgba updatedAlpha


getPresetNameByDirection : Direction -> Actor.ObjectTypeData -> Actor.ObjectPresetName
getPresetNameByDirection direction objectData =
    Direction.getIDFromDirection direction
        |> (\a -> Dict.get a objectData.direction)
        |> Maybe.withDefault objectData.default


getImageNamesDataByDirection : Direction -> Actor.ImageTypeData -> Actor.ImagesData
getImageNamesDataByDirection direction imageRenderData =
    Direction.getIDFromDirection direction
        |> (\a -> Dict.get a imageRenderData.direction)
        |> Maybe.withDefault imageRenderData.default


getColor : Int -> Actor.PixelTypeData -> Color
getColor tick renderData =
    modBy (max 1 <| List.length renderData.colors) (round (toFloat tick / toFloat (max renderData.ticksPerColor 1)))
        |> (\b a -> List.Extra.getAt a b) renderData.colors
        |> Maybe.withDefault noColor


getImageName : Int -> Actor.ImagesData -> Maybe String
getImageName tick imagesData =
    modBy (max 1 <| List.length imagesData.names) (round (toFloat tick / toFloat (max imagesData.ticksPerImage 1)))
        |> (\b a -> List.Extra.getAt a b) imagesData.names


noColor : Color
noColor =
    Color.white


asPixel : Config -> Int -> Float -> Float -> Color -> ( String, Html msg )
asPixel config actorId xPoint yPoint color =
    let
        rgba =
            Color.toRgba color

        asCssString : String
        asCssString =
            let
                pct x =
                    ((x * 10000) |> round |> toFloat)
                        / 100
                        |> round
            in
            String.concat
                [ "rgb("
                , String.fromInt (pct rgba.red)
                , "%,"
                , String.fromInt (pct rgba.green)
                , "%,"
                , String.fromInt (pct rgba.blue)
                , "%)"
                ]
    in
    ( "actor-" ++ String.fromInt actorId
    , node "a-box"
        [ attribute "material" <|
            String.join ""
                [ "color: "
                , asCssString
                , "; transparent: true;"
                , "opacity: "
                , String.fromFloat rgba.alpha
                , ";"
                ]
        , attribute "position" <|
            String.join " "
                [ String.fromFloat xPoint
                , String.fromFloat (yPoint * -1)
                , "0"
                ]
        ]
        []
    )
