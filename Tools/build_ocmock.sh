ENV=/usr/bin/env

pushd ./Contrib/OCMock/OCMock-current-source/
"$ENV" -i PATH="$PATH" \
    xcodebuild -configuration Release -target OCMock \
        LD_DYLIB_INSTALL_NAME="" \
        SYMROOT="$BUILD_DIR" \
        OBJROOT="$OBJROOT" 
popd
