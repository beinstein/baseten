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
        ln -s "postgresql-${version}" "$my_build_dir"/postgresql-src
        patch -p1 -d "$postgresql_root" < "$SRCROOT"/libpq.patch
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
	
	## ( architecture-name configure-host cc cflags cppflags ldflags )

	my_arch="$1"
	my_target="$2"
	export CC="$3"
	export CFLAGS="$4"
	export CPPFLAGS="$5"
	export LDFLAGS="$6"
	
	echo "Architecture: ${my_arch}"
	echo "Target:       ${my_target}"
	echo "CC:           ${CC}"
	echo "CFLAGS:       ${CFLAGS}"
	echo "CPPFLAGS:     ${CPPFLAGS}"
	echo "LDFLAGS:      ${LDFLAGS}"
	sleep 1

    pushd "$postgresql_root"
    make distclean 2>&1

	my_debug=""
    if [ "Debug" = "$BUILD_STYLE" ]
	then
		my_debug="--enable-debug"
	fi
	
	echo "Configure options: --target $my_target --disable-shared \
	--without-zlib --without-readline --with-openssl $my_debug\ 
	--prefix=$my_build_dir/$my_arch"
	./configure --target "$my_target" --disable-shared \
	--without-zlib --without-readline --with-openssl "$my_debug"\
	--prefix="$my_build_dir"/"$my_arch" 2>&1
	exit_on_error
	
    make clean 2>&1
	exit_on_error
	
    mkdir -p ../"$my_arch"
	exit_on_error
	
	## Required targets, see src/backend/Makefile: Make symlinks...
	make -j "$my_availcpu" -C src/backend ../../src/include/parser/parse.h
	exit_on_error
	make -j "$my_availcpu" -C src/backend ../../src/include/utils/fmgroids.h
	exit_on_error

    for x in src/include src/interfaces/libpq src/bin/psql
    do
        pushd "$x"
		make -j "$my_availcpu" 2>&1
		exit_on_error
		make -j "$my_availcpu" install 2>&1
		exit_on_error
        popd
    done
    
    popd

	## pg_config.h might be machine-dependent.
	pushd "$my_build_dir"
	if [ ! -d "$my_build_dir"/universal/include ]
	then
		mkdir -p "$my_build_dir"/universal
		cp -R "$my_arch"/include "$my_build_dir"/universal/include
		mkdir -p "$my_build_dir"/universal/include/machine
		
		pushd "$my_build_dir"/universal/include/
		rm pg_config.h
		cp "$SRCROOT"/Sources/pg_config.h ./
		popd
	fi
	
	mkdir -p "$my_build_dir"/universal/include/machine/"$my_arch"
	mv "$my_arch"/include/pg_config.h "$my_build_dir"/universal/include/machine/"$my_arch"/
	
	popd
}


if [ ! -e "$my_build_dir"/"$my_architecture"/lib/libpq.a ] || \
   [ ! -e "$my_build_dir"/"$my_architecture"/bin/psql ]
then
	mkdir -p "$my_build_dir"
	pushd "$SRCROOT"/Contrib/PostgreSQL
	extract
	
	## ( architecture-name configure-host cc cflags cppflags ldflags )
	if [ "ppc" = "$my_architecture" ]
	then
		opts=(
			ppc
			powerpc-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-4.0"
			"-arch ppc"
			"-arch ppc -mmacosx-version-min=10.4 -isysroot ${SDKROOT}"
			"-Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.4"
		)
	elif [ "i386" = "$my_architecture" ]
	then
		opts=(
			i386
			i386-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-4.0"
			"-arch i386"
			"-arch i386 -mmacosx-version-min=10.4 -isysroot ${SDKROOT}"
			"-Wl,-syslibroot,${SDKROOT} -mmacosx-version-min=10.4"
		)
	elif [ "arm" = "$my_architecture" ]
	then
		opts=(
			arm
			arm-apple-darwin
			"${PLATFORM_DEVELOPER_BIN_DIR}/gcc-4.0"
			"-arch armv6 -mthumb"
			"-arch armv6 -isysroot ${SDKROOT}"
			"-Wl,-syslibroot,${SDKROOT}"
		)
	else
		echo "Error: unsupported architecture: ${my_architecture}."
		exit 1
	fi
	
	build "${opts[@]}"

	popd
fi
return 0
