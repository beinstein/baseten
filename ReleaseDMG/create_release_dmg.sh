#!/bin/bash

export SYMROOT=~/Build/BaseTen-dmg-build
export OBJROOT="$SYMROOT"/Intermediates

function exit_on_error
{
    exit_status="$?"
    if [ ! 0 -eq "$exit_status" ]; then
        exit "$exit_status"
    fi
}


for x in \
    ../BaseTen.xcodeproj \
    ../BaseTenAppKit/BaseTenAppKit.xcodeproj \
    ../BaseTenAssistant/BaseTenAssistant.xcodeproj \
    ../InterfaceBuilderPlugin/InterfaceBuilderPlugin.xcodeproj
do
    xcodebuild -project "$x" -configuration Release OBJROOT="$OBJROOT" SYMROOT="$SYMROOT"
    exit_on_error
done


echo

./dmg_helper.sh

echo
echo
