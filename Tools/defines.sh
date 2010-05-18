baseten_version="1.8"
my_build_dir="${BUILT_PRODUCTS_DIR}/BaseTen-PostgreSQL"
my_additions_dir="${BUILT_PRODUCTS_DIR}/BaseTen-PG-Additions"
postgresql_version="8.3.11"
postgresql_source_file="postgresql-${postgresql_version}.tar.bz2"
postgresql_root="${my_build_dir}/postgresql-${postgresql_version}"
my_availcpu=`/usr/sbin/sysctl -n hw.availcpu`

function exit_on_error
{
    exit_status="$?"
    if [ ! 0 -eq "$exit_status" ]; then
        exit "$exit_status"
    fi
}
