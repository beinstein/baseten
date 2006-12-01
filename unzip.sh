ZIP_FILE_PATH=$1
TARGET_FILE_PATH=$2

unzip ()
{
	open "$ZIP_FILE_PATH"
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

