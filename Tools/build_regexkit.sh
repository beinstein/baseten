ENV=/usr/bin/env
pushd ./Contrib/RegexKit/
"$ENV" -i PATH="$PATH" \
    xcodebuild -configuration Release -target "$my_target" \
        SYMROOT="$BUILD_DIR" \
        OBJROOT="$OBJROOT" 
popd
