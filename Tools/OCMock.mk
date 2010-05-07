ENV = /usr/bin/env
XCODEBUILD = xcodebuild
GNUTAR = gnutar


.PHONY: all build clean OCMock-xc


build: $(BUILD_DIR)/Release/OCMock.framework


clean: OCMock-xc


$(BUILD_DIR)/Release/OCMock.framework: OCMock-xc ocmock-1.55


ocmock-1.55:
	$(GNUTAR) -xzf ocmock-1.55.tar.gz


OCMock-xc: ocmock-1.55
	@if [ -n "$(BUILD_DIR)" ] && [ -n "$(OBJROOT)" ]; then \
		cd ocmock-1.55; \
		$(ENV) -i PATH="$(PATH)" \
			$(XCODEBUILD) -configuration Release -target OCMock \
				$(MAKECMDGOALS) \
				SYMROOT="$(BUILD_DIR)" \
				OBJROOT="$(OBJROOT)"; \
	fi
