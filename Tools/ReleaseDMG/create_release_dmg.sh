#!/bin/bash

export SYMROOT="$PWD"/BaseTen-dmg-build
export OBJROOT="$SYMROOT"/Intermediates

function exit_on_error
{
    exit_status="$?"
    if [ ! 0 -eq "$exit_status" ]; then
        exit "$exit_status"
    fi
}

echo "Using developer tools at path:"
xcode-select -print-path
exit_on_error

echo "Xcode version:"
xcodebuild -version
exit_on_error

sleep 5

for x in \
    ../../BaseTen.xcodeproj \
    ../../BaseTenAppKit/BaseTenAppKit.xcodeproj \
    ../../BaseTenAssistant/BaseTenAssistant.xcodeproj \
    ../../InterfaceBuilderPlugin/InterfaceBuilderPlugin.xcodeproj
do
    xcodebuild -project "$x" -configuration Release OBJROOT="$OBJROOT" SYMROOT="$SYMROOT"
    exit_on_error
done

if [ ! "$1" = "--without-latex" ]
then
    make -C ../../Documentation/latex
    exit_on_error
fi


echo

./dmg_helper.sh

echo
echo
