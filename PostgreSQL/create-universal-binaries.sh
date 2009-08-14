. "$SRCROOT"/PostgreSQL/defines.sh

if [ ! -e "$my_build_dir"/universal/bin/psql ]
then
	mkdir -p "$my_build_dir"/universal/bin

	for file in bin/psql
	do
        exec_lipo=0
        input_files=""
        for arch in $ARCHS
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
fi
return 0
