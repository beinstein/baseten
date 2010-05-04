source Tools/defines.sh

REV=`/usr/bin/svnversion -nc ${PROJECT_DIR} | /usr/bin/sed -e 's/^[^:]*://;s/[A-Za-z]//'`
exit_on_error

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${REV}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
exit_on_error
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${baseten_version}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
exit_on_error
