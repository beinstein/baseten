. "$SRCROOT"/PostgreSQL/defines.sh

if [ ! -e "$my_build_dir"/universal/lib/libpq.a ] || \
   [ ! -e "$my_build_dir"/universal/bin/psql ] ||
   [ ! -e "$my_build_dir"/postgresql ]
then
	mkdir -p "$my_build_dir"/universal/bin
	mkdir -p "$my_build_dir"/universal/lib

	for file in lib/libpq.a bin/psql
	do
    	lipo -create -output "$my_build_dir"/universal/"$file" \
			"$my_build_dir"/i386/"$file" \
			"$my_build_dir"/ppc/"$file"
	done
	cp -R "$my_build_dir"/universal/include "$my_build_dir"/postgresql
	"$postgresql_root"/configure --version | head -n 1 > "$my_build_dir"/VERSION
fi
return 0