#!/bin/bash

if [ -z "$DOXYGEN" ]
then
    DOXYGEN=`which doxygen`
    if [ -z "$DOXYGEN" ]
    then
        if [ -x "/usr/local/bin/doxygen" ]
        then
            DOXYGEN="/usr/local/bin/doxygen"
        elif [ -x "/opt/local/bin/doxygen" ]
        then
            DOXYGEN="/opt/local/bin/doxygen"
        elif [ -x "/sw/bin/doxygen" ]
        then
            DOXYGEN="/sw/bin/doxygen"       
        ## Patch by Tim Bedford 2008-08-04
        else
            DOXYGENAPP=`mdfind "kMDItemFSName == 'Doxygen.app'"`
            if [ DOXYGENAPP ]
            then
                DOXYGEN="$DOXYGENAPP/Contents/Resources/doxygen"
            fi
        fi
        ## End patch
    fi
fi

if [ -x "$DOXYGEN" ]
then
    cd "$SRCROOT"
    "$DOXYGEN"
    ## Make some LaTeX files \inputted instead of \included to prevent \clearpage on chapter title pages.
    perl -i -p -e 's/\\include\{(general_usage|database_usage)\}/\\input\{$1\}/g' Documentation/latex/refman.tex
    ## Removed [implementation] remarks, because they make lines long and we don't care where the documentation was found.
    perl -i -p -e 's/(\\hspace\{0\.3cm\})?\{\\tt  \\mbox\{\[\}implementation\\mbox\{\]\}\}//g' Documentation/latex/*.tex
    make -C Documentation/html
    #open *.docset
else
    echo "warning: didn't find doxygen; documentation not created."
fi
exit 0
