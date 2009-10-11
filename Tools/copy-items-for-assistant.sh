CP=/bin/cp
FRAMEWORKS_DIR="$BUILT_PRODUCTS_DIR/BaseTen Assistant.app/Contents/Frameworks/"

if [ ! -d "$BUILT_PRODUCTS_DIR/BaseTen.ibplugin" ]
then
    ib_plugin="$SRCROOT/../InterfaceBuilderPlugin/build/$BUILD_STYLE/BaseTen.ibplugin"
    if [ -d "$ib_plugin" ]
    then
        "$CP" -a -f -v "$ib_pluin" "$BUILT_PRODUCTS_DIR"
    else
        echo "Didn't find BaseTen.ibplugin!"
        exit 1
    fi
fi

if [ ! -d "$FRAMEWORKS_DIR/RegexKit.framework" ]
then
    global_bd_rk="$BUILD_DIR/Release/RegexKit.framework"
    baseten_bd_rk="$SRCROOT/../build/Release/RegexKit.framework"

    if [ -d "$global_bd_rk" ]
    then
        "$CP" -a -f -v "$global_bd_rk" "$FRAMEWORKS_DIR"
    elif [ -d "$baseten_bd_rk" ]
    then
        "$CP" -a -f -v "$baseten_bd_rk" "$FRAMEWORKS_DIR"
    else
        echo "Didn't find RegexKit.framework!"
        exit 1
    fi
fi

exit 0
