source "${SRCROOT}/Tools/defines.sh"
openssl_source_file=openssl-1.0.0.tar.gz
openssl_dir=openssl-1.0.0
openssl_root="$my_build_dir/$openssl_dir"


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
		patch -p1 -d "$openssl_root" < "$SRCROOT"/Patches/openssl.patch
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

	export CC="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc-4.2"
	mkdir -p "$my_build_dir"
	
	pushd "$SRCROOT"/Contrib/OpenSSL
	extract
	popd
	
	## Make tells that jobserver is unavailable and that -j may not be used.
	pushd "$openssl_root"
	make distclean || echo "Continuing..."
	./Configure darwin-arm-gcc no-asm no-shared threads zlib-dynamic no-gost
	exit_on_error
	make
	exit_on_error
	popd
else
    echo "already built."
fi
