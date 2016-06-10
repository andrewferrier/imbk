#!/bin/sh -v
#
# See https://makeappicon.com/ios8icon

ABSOLUTE_PATH=$(cd $(dirname "$0"); pwd)

LOCATION="$ABSOLUTE_PATH/../imbk/Assets.xcassets/AppIcon.appiconset/"

convert -resize '29x29'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-Small.png"
convert -resize '58x58'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-Small@2x.png"
convert -resize '87x87'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-Small@3x.png"

convert -resize '40x40'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-40.png"
convert -resize '80x80'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-40@2x.png"
convert -resize '120x120' -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-40@3x.png"

convert -resize '120x120' -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-60@2x.png"
convert -resize '180x180' -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-60@3x.png"

convert -resize '76x76'   -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-76.png"
convert -resize '152x152' -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-76@2x.png"

convert -resize '167x167' -unsharp 1x4 $ABSOLUTE_PATH/../model/imbk-icon.svg "$LOCATION/Icon-83.5@2x.png"
