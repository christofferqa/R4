#!/bin/bash

RECORD=$WEBERA_DIR/R4/record.sh
MC=$WEBERA_DIR/R4/model-check.sh

if (( ! $# > 0 )); then
    echo "Usage: ./r4.sh <website URL> [--manual] [--report] [--outdir=<dir>] [--trigger-event-type=<str> --trigger-node-identifier=<str>]"
    echo "Outputs result to <outdir>/<website dir>"
    exit 1
fi

AUTO="--auto"
DST_OUTPUT_DIR=output
REPORT="false"
SITE=""
TRIGGER_EVENT_TYPE=""
TRIGGER_NODE_IDENTIFIER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --h)
            echo "Usage: ./r4.sh <website URL> [--manual] [--outdir=<dir>] [--trigger-event-type=<str> --trigger-node-identifier=<str>]"
            echo "Example: ./r4.sh abc.xyz --trigger-event-type=click --trigger-node-identifier=\"https://abc.xyz/ @ #document[0]/HTML[6]/BODY[3]/...\""
            echo ""
            echo "Instructions for obtaining the node identifier:"
            echo "1) run the instrumented WebKit"
            echo "2) perform an event on the target node"
            echo "3) find the node identifier in the stdout of WebKit"
            exit 0
            ;;
        --manual)
            AUTO=""
            ;;
        --outdir=*)
            DST_OUTPUT_DIR="${1#*=}"
            ;;
        --report)
            REPORT="true"
            ;;
        --trigger-event-type=*)
            AUTO=""
            TRIGGER_EVENT_TYPE="${1#*=}"
            ;;
        --trigger-node-identifier=*)
            AUTO=""
            TRIGGER_NODE_IDENTIFIER="${1#*=}"
            ;;
        *)
            if [[ $1 == --* ]]; then
                echo "Invalid argument: $1."
                exit 1
            fi
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

ID=${SITE//[:\/\.]/\-}

OUTDIR=~/r4tmp/$RANDOM
while [ -f $OUTDIR ]; do
    OUTDIR=~/r4tmp/$RANDOM
done
OUTRUNNER=$OUTDIR/runner

rm -rf $OUTDIR
mkdir -p $OUTRUNNER
mkdir -p $DST_OUTPUT_DIR

echo "Running " $SITE " @ " $OUTDIR

echo "Running CMD: $RECORD $SITE $OUTDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier=\"$TRIGGER_NODE_IDENTIFIER\" >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log"
$RECORD $SITE $OUTDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier="$TRIGGER_NODE_IDENTIFIER" >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log
if [[ $? == 0 ]] ; then
    echo "Running CMD: $MC $SITE $OUTDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier=\"$TRIGGER_NODE_IDENTIFIER\" --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log"
    $MC $SITE $OUTDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier="$TRIGGER_NODE_IDENTIFIER" --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log
    if [[ ! $? == 0 ]] ; then
        echo "model-checker errord out, see $DST_OUTPUT_DIR/$ID/runner/mc.log"
    elif [ ! -d $OUTDIR/base ]; then
        echo "Error: Repeating the initial recording failed"
    fi

else
    echo "Initial recording errord out, see $DST_OUTPUT_DIR/$ID/runner/record.log"
fi

rm -rf output/$ID
mv $OUTDIR $DST_OUTPUT_DIR/$ID

if [[ "$REPORT" == "true" ]]; then
    mkdir -p report
    ./utils/batch-report/report.py "website" output report "$ID"
fi
