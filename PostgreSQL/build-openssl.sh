. "$SRCROOT"/PostgreSQL/defines.sh
openssl_source_file=openssl-0.9.8h.tar.gz
openssl_dir=openssl-0.9.8h
openssl_root="$my_build_dir"/"$openssl_dir"


function extract
{
	# Extract the sources
	if [ ! -d "$openssl_root" ]
	then
    	if [ -e "$openssl_root" ]
    	then
        	echo "A file named ${openssl_root} exists and is not a folder. Exiting."
        	exit 1
    	fi

		gnutar -zxf "$openssl_source_file" -C "$my_build_dir"
		exit_on_error
		patch -p1 -d "$openssl_root" < "$SRCROOT"/PostgreSQL/openssl.patch
		exit_on_error
		
		pushd "$my_build_dir"
		ln -s "$openssl_dir" openssl
		popd
	fi
}


echo -n "Checking whether to build OpenSSL for architecture arm... "
if [ ! -e "$openssl_root"/libssl.a ] || \
   [ ! -e "$openssl_root"/libcrypto.a ]
then
    echo "yes."

	export CC="${PLATFORM_DEVELOPER_BIN_DIR}/gcc-4.0"
	mkdir -p "$my_build_dir"
	
	pushd "$SRCROOT"/Contrib/OpenSSL
	extract
	popd
	
	## Make tells that jobserver is unavailable and that -j may not be used.
	pushd "$openssl_root"
	make distclean
	./Configure darwin-arm-gcc
	exit_on_error
	make
	exit_on_error
	popd
else
    echo "already built."
fi
