echo -n "Checking whether to build OCMock... "
if [ -d "$BUILD_DIR/Release/OCMock.framework" ]
then
    echo "already built."
else
    echo "yes."
    my_sdk="$PLATFORM_DEVELOPER_SDK_DIR/MacOSX10.4u.sdk"
    pushd ./Contrib/OCMock/OCMock-current-source/
    xcodebuild -configuration Release -target OCMock -sdk "$my_sdk" INSTALL_PATH="$BUILD_DIR/Release/" SYMROOT="$BUILD_DIR"
    popd
fi
