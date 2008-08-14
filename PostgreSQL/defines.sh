my_build_dir="$BUILT_PRODUCTS_DIR"/BaseTen-PostgreSQL
my_additions_dir="$BUILT_PRODUCTS_DIR"/BaseTen-PG-Additions
version="8.3.3"
postgresql_source_file="postgresql-${version}.tar.bz2"
postgresql_root="${my_build_dir}/postgresql-${version}"
my_availcpu=`/usr/sbin/sysctl -n hw.availcpu`

function exit_on_error
{
    exit_status="$?"
    if [ ! 0 -eq "$exit_status" ]; then
        exit "$exit_status"
    fi
}
