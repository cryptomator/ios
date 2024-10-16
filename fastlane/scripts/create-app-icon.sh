#!/bin/sh

# Path is relative to the fastlane folder
cp "${1}" ../SharedResources/Assets.xcassets/AppIcon.appiconset/LightIcon.png
cp "${2}" ../SharedResources/Assets.xcassets/AppIcon.appiconset/DarkIcon.png
cp "${3}" ../SharedResources/Assets.xcassets/AppIcon.appiconset/TintedIcon.png
