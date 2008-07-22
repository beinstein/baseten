#!/bin/bash

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
rm -f BaseTen.dmg
#rm -f BaseTen-master.sparseimage

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
rm -rf /Volumes/BaseTen/BaseTen.framework
cp -pRP "$SYMROOT"/Release/BaseTen.framework /Volumes/BaseTen/.

rm -rf /Volumes/BaseTen/BaseTenAppKit.framework
cp -pRP "$SYMROOT"/Release/BaseTenAppKit.framework /Volumes/BaseTen/.

rm -rf /Volumes/BaseTen/BaseTen\ Assistant.app
cp -pRP "$SYMROOT"/Release/BaseTen\ Assistant.app /Volumes/BaseTen/.

rm -rf /Volumes/BaseTen/InterfaceBuilderPlugin.ibplugin
cp -pRP "$SYMROOT"/Release/"BaseTen Plug-in.ibplugin" /Volumes/BaseTen/.

rm -f /Volumes/BaseTen/Frameworks
ln -s /Library/Frameworks /Volumes/BaseTen/Frameworks

# Copy Finder .DS_Store data
cp DMG_DS_Store /Volumes/BaseTen/.DS_Store

# Copy volume icon and set it
#cp DMG_VolumeIcon.icns /Volumes/BaseTen/.VolumeIcon.icns
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
rm -f BaseTen-temp.sparseimage

