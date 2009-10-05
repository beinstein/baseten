pushd "$BUILT_PRODUCTS_DIR/BaseTen Assistant.app/Contents/Resources/English.lproj/BaseTen Assistant Help" > /dev/null

which hiutil > /dev/null
if [ 0 -eq $? ]
then
    hiutil -Cf "BaseTen Assistant Help.helpindex" -a -g .
else
    "$SYSTEM_DEVELOPER_UTILITIES_DIR/Help Indexer.app/Contents/MacOS/Help Indexer" .
fi

popd > /dev/null
