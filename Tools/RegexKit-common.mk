CP = /bin/cp
RM = /bin/rm
MV = /bin/mv
ENV = /usr/bin/env
PATCH = /usr/bin/patch
XCODEBUILD = xcodebuild

BUILD_SETTINGS_DIR = RegexKit-patched-source/Source/Build/Xcode


.PHONY: all build clean RegexKit-xc


build: $(BUILD_DIR)/Release/$(RESULT)


clean: RegexKit-xc
	$(RM) -rf RegexKit-patched-source


$(BUILD_DIR)/Release/$(RESULT): RegexKit-patched-source RegexKit-xc


RegexKit-xc: RegexKit-patched-source
	@if [ -n "$(BUILD_DIR)" ] && [ -n "$(OBJROOT)" ]; then \
		cd RegexKit-patched-source; \
		$(ENV) -i PATH="$(PATH)" \
			$(XCODEBUILD) -configuration Release -target $(TARGET) \
				$(MAKECMDGOALS) \
				SYMROOT="$(BUILD_DIR)" \
				OBJROOT="$(OBJROOT)" \
				GCC_VERSION=4.0; \
	fi


RegexKit-patched-source:
	@if [ -z "$(BUILD_DIR)" ]; then \
		echo "BUILD_DIR wasn't set."; \
		exit 1; \
	fi

	@if [ -z "$(OBJROOT)" ]; then \
		echo "OBJROOT wasn't set."; \
		exit 1; \
	fi

	$(CP) -pLR RegexKit-current-source RegexKit-patched-source
	$(PATCH) -d RegexKit-patched-source -p0 < ../../Patches/pcre-makefile.patch

	$(MV) -i $(BUILD_SETTINGS_DIR)/"RegexKit Build Settings.xcconfig" $(BUILD_SETTINGS_DIR)/RegexKit_Build_Settings.xcconfig
	$(PATCH) -d RegexKit-patched-source -p0 < ../../Patches/pcre-build.patch
	$(MV) -i $(BUILD_SETTINGS_DIR)/RegexKit_Build_Settings.xcconfig $(BUILD_SETTINGS_DIR)/"RegexKit Build Settings.xcconfig"
