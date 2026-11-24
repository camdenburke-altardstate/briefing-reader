#!/bin/bash
# Mac only. Copies the sample decks into the app's Documents folder in the booted iPad simulator,
# so the library is populated without any Finder step. Run from the project folder, after the app
# has been installed in the simulator (press Run in Xcode once):
#     bash tools/load-samples-simulator.sh
# The library picks the files up within 15 seconds, or on the next time the app comes to the front.
set -e
BUNDLE="com.altardstate.briefingreader"   # must match PRODUCT_BUNDLE_IDENTIFIER in project.yml
DATA="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
mkdir -p "$DATA/Documents"
cp SampleDecks/*.pdf "$DATA/Documents/"
echo "Copied $(ls SampleDecks/*.pdf | wc -l | tr -d ' ') decks to $DATA/Documents"
