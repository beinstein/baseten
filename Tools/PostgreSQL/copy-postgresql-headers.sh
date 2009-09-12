CP=/bin/cp
MKDIR=/bin/mkdir
PRIVATE_HEADERS="$BUILT_PRODUCTS_DIR"/"$PRIVATE_HEADERS_FOLDER_PATH"

for x in $ARCHS
do
    if [ ! -e "$PRIVATE_HEADERS"/postgresql/"$x" ]
    then
        "$MKDIR" -p "$PRIVATE_HEADERS"/postgresql/
        "$CP" -R "$BUILT_PRODUCTS_DIR"/BaseTen-PostgreSQL/"$x"/include "$PRIVATE_HEADERS"/postgresql/"$x"
    fi
done
