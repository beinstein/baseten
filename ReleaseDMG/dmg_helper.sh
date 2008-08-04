#!/bin/bash

CP=/bin/cp
RM=/bin/rm

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
"$CP" -pRP "$SYMROOT"/Release/"BaseTen.ibplugin" /Volumes/BaseTen/.

"$RM" -rf /Volumes/BaseTen/Manual.pdf
"$CP" -pRP ../Documentation/latex/refman.pdf /Volumes/BaseTen/Manual.pdf

"$RM" -f /Volumes/BaseTen/Frameworks
ln -s /Library/Frameworks /Volumes/BaseTen/Frameworks

# Copy Finder .DS_Store data
"$CP" DMG_DS_Store /Volumes/BaseTen/.DS_Store

# Copy volume icon and set it
#"$CP" DMG_VolumeIcon.icns /Volumes/BaseTen/.VolumeIcon.icns
#SetFile -a Ci /Volumes/BaseTen


# Unmount the finished disk image
hdiutil detach /Volumes/BaseTen

# Convert the master disk image to UDIF zlib-compressed image (UDZO) and copy the result file
hdiutil convert BaseTen-temp.sparseimage -format UDZO -o BaseTen.dmg

# Add license resources to BaseTen.dmg
hdiutil unflatten BaseTen.dmg
/Developer/Tools/Rez -a ReleaseDiskImageResources.r -o BaseTen.dmg
hdiutil flatten BaseTen.dmg

# Internet-enable disk image
#hdiutil internet-enable BaseTen.dmg

# Verify disk image
hdiutil verify BaseTen.dmg

# Clean up
"$RM" -f BaseTen-temp.sparseimage

