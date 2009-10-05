CP=/bin/cp
TARGET_DIR="$BUILT_PRODUCTS_DIR/BaseTen Assistant.app/Contents/Frameworks/"

if [ ! -d "$TARGET_DIR/RegexKit.framework" ]
then
    global_bd_rk="$BUILD_DIR/Release/RegexKit.framework"
    baseten_bd_rk="$SRCROOT/../build/Release/RegexKit.framework"

    if [ -d "$global_bd_rk" ]
    then
        "$CP" -a -f -v "$global_bd_rk" "$TARGET_DIR"
    elif [ -d "$baseten_bd_rk" ]
    then
        "$CP" -a -f -v "$baseten_bd_rk" "$TARGET_DIR"
    else
        echo "Didn't find RegexKit.framework!"
        exit 1
    fi
fi

exit 0
