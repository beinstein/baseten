. "$SRCROOT"/PostgreSQL/defines.sh

if [ ! -e "$my_build_dir"/universal/lib/libpq.a ] || \
   [ ! -e "$my_build_dir"/universal/bin/psql ] ||
   [ ! -e "$my_build_dir"/postgresql ]
then
	mkdir -p "$my_build_dir"/universal/bin
	mkdir -p "$my_build_dir"/universal/lib

	for file in lib/libpq.a bin/psql
	do
        exec_lipo=0
        input_files=""
        for arch in "$ARCHS"
        do
            path="$my_build_dir"/"$arch"/"$file"
            if [ -f "$path" ]
            then
                exec_lipo=1
                input_files="${input_files} ${path}"
            else
                echo "Warning: file at '${path}' doesn't exist."
            fi
        done

        if [ $exec_lipo ]
        then
            lipo ${input_files} -create -output "$my_build_dir"/universal/"$file" $args
        fi
	done
	
	cp -R "$my_build_dir"/universal/include "$my_build_dir"/postgresql
fi
return 0
