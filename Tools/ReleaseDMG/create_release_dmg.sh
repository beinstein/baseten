#!/bin/bash

SYMROOT="$PWD"/BaseTen-dmg-build
OBJROOT="$SYMROOT"/Intermediates
CP=/bin/cp
RM=/bin/rm
CHFLAGS=/usr/bin/chflags

function exit_on_error
{
    exit_status="$?"
    if [ ! 0 -eq "$exit_status" ]; then
        exit "$exit_status"
    fi
}

if [ -e /Volumes/BaseTen ]
then
    echo "/Volumes/BaseTen already exists."
    exit 1
fi

echo -n "Using developer tools at path: "
xcode-select -print-path
exit_on_error

echo -n "Xcode version: "
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


# Check that OBJROOT exists
if [ ! -d "$OBJROOT" ]
then
	echo "Error: $OBJROOT doesn't exist."
	exit 1
fi

# Check that SYMROOT exists
if [ ! -d "$SYMROOT" ]
then
	echo "Error: $SYMROOT doesn't exist."
	exit 1
fi


# Remove all previous BaseTen disk images
"$RM" -f BaseTen.dmg
#"$RM" -f BaseTen-master.sparseimage

if [ -d "/Volumes/BaseTen" ]
then
	echo "Error: /Volumes/BaseTen already exists"
	exit 1
fi

# Attach the template image
gzip -dc BaseTen-master.sparseImage.gz > BaseTen-temp.sparseImage
hdiutil attach -private BaseTen-temp.sparseImage

if [ ! -d "/Volumes/BaseTen" ]
then
	echo "Error: /Volumes/BaseTen doesn't exist."
	exit 1
fi

# Copy built BaseTen.framework and BaseTenAppKit.framework to new disk image
"$RM" -rf /Volumes/BaseTen/BaseTen.framework
"$CP" -pRP "$SYMROOT"/Release/BaseTen.framework /Volumes/BaseTen/.

"$RM" -rf /Volumes/BaseTen/BaseTenAppKit.framework
"$CP" -pRP "$SYMROOT"/Release/BaseTenAppKit.framework /Volumes/BaseTen/.

"$RM" -rf /Volumes/BaseTen/BaseTen\ Assistant.app
"$CP" -pRP "$SYMROOT"/Release/BaseTen\ Assistant.app /Volumes/BaseTen/.

"$RM" -rf /Volumes/BaseTen/BaseTen.ibplugin
"$CP" -pRP "$SYMROOT"/Release/"BaseTen.ibplugin" /Volumes/BaseTen/BaseTenAppKit.framework/Resources/.

"$RM" -rf /Volumes/BaseTen/Manual.pdf
"$CP" -pRP ../../Documentation/latex/refman.pdf /Volumes/BaseTen/Manual.pdf

"$RM" -f /Volumes/BaseTen/Frameworks
ln -s /Library/Frameworks /Volumes/BaseTen/Frameworks

# Copy the background image
"$RM" -f /Volumes/BaseTen/DMG-design.png 
"$CP" -pRP DMG-design.png /Volumes/BaseTen/DMG-design.png
"$CHFLAGS" hidden /Volumes/BaseTen/DMG-design.png

# Copy Finder .DS_Store data
"$CP" DMG_DS_Store /Volumes/BaseTen/.DS_Store


# Copy volume icon and set it
#"$CP" DMG_VolumeIcon.icns /Volumes/BaseTen/.VolumeIcon.icns
#SetFile -a Ci /Volumes/BaseTen


# Unmount the finished disk image
hdiutil detach /Volumes/BaseTen
if [ -d "/Volumes/BaseTen" ]
then
    echo "warning: hdiutil detach failed - forcing detach"
    hdiutil detach -force /Volumes/BaseTen
fi


# Convert the master disk image to UDIF zlib-compressed image (UDZO) and copy the result file
hdiutil convert BaseTen-temp.sparseimage -format UDZO -o BaseTen.dmg

# Add license resources to BaseTen.dmg
hdiutil unflatten BaseTen.dmg
Rez -a ReleaseDiskImageResources.r -o BaseTen.dmg
hdiutil flatten BaseTen.dmg

# Internet-enable disk image
#hdiutil internet-enable BaseTen.dmg

# Verify disk image
hdiutil verify BaseTen.dmg

# Clean up
"$RM" -f BaseTen-temp.sparseimage


echo
echo
