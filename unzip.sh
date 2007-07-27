ZIP_FILE_PATH=$1
TARGET_FILE_PATH=$2

unzip ()
{
    if [ $MAC_OS_X_VERSION_ACTUAL -ge 1050 ]
    then
        open -a "/System/Library/CoreServices/Archive Utility.app" "$ZIP_FILE_PATH"
    else
        open -a "/System/Library/CoreServices/BOMArchiveHelper.app" "$ZIP_FILE_PATH"
    fi

	sleep 2
	if [ -e "$TARGET_FILE_PATH" ]
	then
		touch "$TARGET_FILE_PATH"
		echo "$TARGET_FILE_PATH unzipped ok"
	else
		echo "ERROR! Couldn't unzip $ZIP_FILE_PATH"
	fi
}

if [ -e "$TARGET_FILE_PATH" ]
then
	if [ "$ZIP_FILE_PATH" -nt "$TARGET_FILE_PATH" ]
	then
		rm -rf "$TARGET_FILE_PATH"
		unzip
	else
		echo "$TARGET_FILE_PATH exists"
	fi
else
	unzip
fi

