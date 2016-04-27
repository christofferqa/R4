#!/bin/bash

RECORD=$WEBERA_DIR/R4/record.sh
MC=$WEBERA_DIR/R4/model-check.sh

if (( ! $# > 0 )); then
    echo "Usage: <website URL> [--manual] [--outdir=<dir>]"
    echo "Outputs result to <outdir>/<website dir>"
    exit 1
fi

AUTO="--auto"
DST_OUTPUT_DIR=output
SITE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --h)
            echo "Usage: <website URL> [--manual] [--outdir=<dir>]"
            exit 0
            ;;
        --manual)
            AUTO=""
            ;;
        --outdir=*)
            DST_OUTPUT_DIR="${1#*=}"
            ;;
        *)
            SITE=$1
            ;;
    esac
    shift
done

if [[ "$SITE" == "" ]] ; then
    echo "Site is mandatory"
    exit 1
elif [[ $SITE == http* ]]; then
    echo "Site must not include protocol"
    exit 1
fi

OUTDIR=~/r4tmp/$RANDOM
while [ -f $OUTDIR ]; do
    OUTDIR=~/r4tmp/$RANDOM
done
OUTRUNNER=$OUTDIR/runner

rm -rf $OUTDIR
mkdir -p $OUTRUNNER
mkdir -p $DST_OUTPUT_DIR

echo "Running " $SITE " @ " $OUTDIR

echo "Running CMD: $RECORD $SITE $OUTDIR --verbose $AUTO >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log"
$RECORD $SITE $OUTDIR --verbose $AUTO >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log
if [[ $? == 0 ]] ; then
    echo "Running CMD: $MC $SITE $OUTDIR --verbose $AUTO --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log"
    $MC $SITE $OUTDIR --verbose $AUTO --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log
    if [[ ! $? == 0 ]] ; then
        echo "model-checker errord out, see $OUTRUNNER/mc.log"
    elif [ ! -d $OUTDIR/base ]; then
        echo "Error: Repeating the initial recording failed"
    fi

else
    echo "Initial recording errord out, see $OUTRUNNER/record.log"
fi

ID=${SITE//[:\/\.]/\-}

rm -rf output/$ID
mv $OUTDIR $DST_OUTPUT_DIR/$ID
