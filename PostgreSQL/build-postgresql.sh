. "$SRCROOT"/PostgreSQL/defines.sh
my_architecture="$1"


function extract
{
    # Extract the sources
    if [ ! -d "$postgresql_root" ]
    then
        if [ -e "$postgresql_root" ]
        then
            echo "A file named ${postgresql_root} exists and is not a folder. Exiting."
            exit 1
        fi
        gnutar -jxf "$postgresql_source_file" -C "$my_build_dir"
        ln -s "postgresql-${postgresql_version}" "$my_build_dir"/postgresql-src
        patch -p1 -d "$postgresql_root" < "$SRCROOT"/PostgreSQL/libpq.patch
    fi
}


function build
{	
	unset CC
	unset CPP
	unset CFLAGS
	unset CPPFLAGS
	unset CXXFLAGS
	unset LDFLAGS

	my_arch="$1"
	my_target="$2"
	export CC="$3"
	export CFLAGS="$4"
	export CPPFLAGS="$5"
	export LDFLAGS="$6"
	my_includes="$7"
	my_libraries="$8"
	
    pushd "$postgresql_root"
    my_machine=`config/config.guess`
    exit_on_error

    echo "Build machine: ${my_machine}"
	echo "Architecture:  ${my_arch}"
	echo "Target:        ${my_target}"
	echo "CC:            ${CC}"
	echo "CFLAGS:        ${CFLAGS}"
	echo "CPPFLAGS:      ${CPPFLAGS}"
	echo "LDFLAGS:       ${LDFLAGS}"
	sleep 1

    make distclean 2>&1

	my_debug=""
    if [ "Debug" = "$BUILD_STYLE" ]
	then
		my_debug="--enable-debug"
	fi
	
	if [ -n "$my_includes" ]
	then
		my_includes="--with-includes=${my_includes}"
	fi
	
	if [ -n "$my_libraries" ]
	then
		my_libraries="--with-libraries=${my_libraries}"
	fi
	
	
	echo "Configure options: --build=$my_machine --host=$my_target --target=$my_target --disable-shared \
        --without-zlib --without-readline --with-openssl $my_debug \
        --prefix=$my_build_dir/$my_arch $my_includes $my_libraries"
	./configure --build=$my_machine --host=$my_target --target=$my_target --disable-shared \
        --without-zlib --without-readline --with-openssl $my_debug \
        --prefix="$my_build_dir"/"$my_arch" $my_includes $my_libraries 2>&1

	exit_on_error
	
    make clean 2>&1
	exit_on_error
	
    mkdir -p ../"$my_arch"
	exit_on_error
	
    ## The selective build fails at times. Just make everything.
    make -j "$my_availcpu" 2>&1
    exit_on_error
    for x in src/include src/interfaces/libpq src/bin/psql
    do
        pushd "$x"
		make -j "$my_availcpu" install 2>&1
		exit_on_error
        popd
    done
	### Required targets, see src/backend/Makefile: Make symlinks...
	#make -j "$my_availcpu" -C src/backend ../../src/include/parser/parse.h
	#exit_on_error
	#make -j "$my_availcpu" -C src/backend ../../src/include/utils/fmgroids.h
	#exit_on_error
    #
    #for x in src/include src/interfaces/libpq src/bin/psql
    #do
    #   pushd "$x"
	#	make -j "$my_availcpu" 2>&1
	#	exit_on_error
	#	make -j "$my_availcpu" install 2>&1
	#	exit_on_error
    #   popd
    #done
    
    popd

	## pg_config.h might be machine-dependent.
	#pushd "$my_build_dir"
	#if [ ! -d "$my_build_dir"/universal/include ]
	#then
	#	mkdir -p "$my_build_dir"/universal
	#	cp -R "$my_arch"/include "$my_build_dir"/universal/include
	#	mkdir -p "$my_build_dir"/universal/include/machine
	#	
	#	pushd "$my_build_dir"/universal/include/
	#	rm pg_config.h
	#	cp "$SRCROOT"/Sources/pg_config.h ./
	#	popd
	#fi
	#
	#mkdir -p "$my_build_dir"/universal/include/machine/"$my_arch"
	#mv "$my_arch"/include/pg_config.h "$my_build_dir"/universal/include/machine/"$my_arch"/
	#
	#popd
}


echo -n "Checking whether to build PostgreSQL for architecture $my_architecture... "
if [ ! -e "$my_build_dir"/"$my_architecture"/lib/libpq.a ] || \
   [ ! -e "$my_build_dir"/"$my_architecture"/bin/psql ]
then
    echo "yes."

	mkdir -p "$my_build_dir"
	pushd "$SRCROOT"/Contrib/PostgreSQL
	extract
	
	## ( architecture-name configure-host cc cflags cppflags ldflags additional_options )
	if [ "ppc" = "$my_architecture" ]
	then
		opts=(
			ppc
			powerpc-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-${GCC_VERSION_ppc}"
			"-arch ppc"
			"-arch ppc -mmacosx-version-min=10.4 -isysroot ${SDKROOT}"
			"-arch ppc -Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.4"
			""
			""
		)
	elif [ "i386" = "$my_architecture" ]
	then
		opts=(
			i386
			i386-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-${GCC_VERSION_i386}"
			"-arch i386"
			"-arch i386 -mmacosx-version-min=10.4 -isysroot ${SDKROOT}"
			"-arch i386 -Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.4"
			""
			""
		)
	elif [ "ppc64" = "$my_architecture" ]
	then
		opts=(
			ppc64
			powerpc64-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-${GCC_VERSION_ppc64}"
			"-arch ppc64"
			"-arch ppc64 -mmacosx-version-min=10.5 -isysroot ${SDKROOT}"
			"-arch ppc64 -Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.5"
			""
			""
		)
	elif [ "x86_64" = "$my_architecture" ]
	then
		opts=(
			x86_64
			x86_64-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-${GCC_VERSION_x86_64}"
			"-arch x86_64"
			"-arch x86_64 -mmacosx-version-min=10.5 -isysroot ${SDKROOT}"
			"-arch x86_64 -Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.5"
			""
			""
		)
	elif [ "arm" = "$my_architecture" ]
	then
		opts=(
			arm
			arm-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-4.2"
			"-arch armv6 -mthumb"
			"-arch armv6 -isysroot ${SDKROOT}"
			"-Wl,-syslibroot,${SDKROOT}"
			"${my_build_dir}/openssl/include" 
			"${my_build_dir}/openssl"
		)
	else
		echo "Error: unsupported architecture: ${my_architecture}."
		exit 1
	fi
	
	build "${opts[@]}"
	popd
	"$postgresql_root"/configure --version | head -n 1 > "$my_build_dir"/VERSION
else
    echo "already built."
fi
return 0
