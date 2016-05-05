#!/bin/bash

RECORD=$WEBERA_DIR/R4/record.sh
MC=$WEBERA_DIR/R4/model-check.sh

if (( ! $# > 0 )); then
    echo "Usage: ./r4.sh <website URL> [--manual] [--proxy] [--report] [--rawdir=<dir>] [--reportdir=<dir>] [--trigger-event-type=<str> --trigger-node-identifier=<str>]"
    exit 1
fi

AUTO="--auto"
HIGH_TIME_LIMIT=""
REPORT="false"
PROXY=""
RAWDIR=""
REPORTDIR=""
SITE=""
TRIGGER_EVENT_TYPE=""
TRIGGER_NODE_IDENTIFIER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --h)
            echo "Usage: ./r4.sh <website URL> [--high-time-limit] [--manual] [--proxy] [--report] [--rawdir=<dir>] [--reportdir=<dir>] [--trigger-event-type=<str> --trigger-node-identifier=<str>]"
            echo "Example: ./r4.sh abc.xyz --report"
            echo "Example: ./r4.sh abc.xyz --report --trigger-event-type=click --trigger-node-identifier=\"https://abc.xyz/ @ #document[0]/HTML[6]/BODY[3]/MAIN[1]/DIV[7]/DIV[1]/DIV[5]/P[1]/A[3]\""
            echo ""
            echo "Instructions for obtaining the node identifier:"
            echo "1) run the instrumented WebKit"
            echo "2) perform an event on the target node"
            echo "3) find the node identifier in the stdout of WebKit"
            exit 0
            ;;
        --high-time-limit)
            HIGH_TIME_LIMIT="--high-time-limit"
            ;;
        --manual)
            AUTO=""
            ;;
        --rawdir=*)
            RAWDIR="${1#*=}"
            ;;
        --proxy)
            PROXY="--proxy"
            ;;
        --report)
            REPORT="true"
            ;;
        --reportdir=*)
            REPORT="true"
            REPORTDIR="${1#*=}"
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
            if [[ $1 == --* ]] ; then
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
elif [[ $SITE == http* ]] ; then
    echo "Site must not include protocol"
    exit 1
fi

ID=${SITE//[:\/\.]/\-}

DEFAULT_RAWDIR=output
DEFAULT_REPORTDIR=report
TMPDIR=~/r4tmp/$RANDOM
while [ -f $TMPDIR ]; do
    TMPDIR=~/r4tmp/$RANDOM
done
OUTRUNNER=$TMPDIR/runner

rm -rf $TMPDIR
mkdir -p $OUTRUNNER
mkdir -p $DEFAULT_RAWDIR
mkdir -p $DEFAULT_REPORTDIR

echo "Running " $SITE " @ " $TMPDIR

ERROR=""

echo "Running CMD: $RECORD $SITE $TMPDIR $PROXY --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier=\"$TRIGGER_NODE_IDENTIFIER\" >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log"
$RECORD $SITE $TMPDIR $PROXY --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier="$TRIGGER_NODE_IDENTIFIER" >> $OUTRUNNER/record.log 2>> $OUTRUNNER/record.log
if [[ $? == 0 ]] ; then
    if [[ "$TRIGGER_EVENT_TYPE" != "" && "$TRIGGER_NODE_IDENTIFIER" != "" ]] ; then
        cat $TMPDIR/record/out.log | grep -F "Warning: Node ($TRIGGER_NODE_IDENTIFIER) not found..."
        if [[ $? == 0 ]] ; then
            exit 1
        fi
    fi

    echo "Running CMD: $MC $SITE $TMPDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier=\"$TRIGGER_NODE_IDENTIFIER\" $HIGH_TIME_LIMIT --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log"
    $MC $SITE $TMPDIR --verbose $AUTO $TRIGGER --trigger-event-type=$TRIGGER_EVENT_TYPE --trigger-node-identifier="$TRIGGER_NODE_IDENTIFIER" $HIGH_TIME_LIMIT --depth 1  >> $OUTRUNNER/mc.log 2>> $OUTRUNNER/mc.log
    if [[ ! $? == 0 ]] ; then
        ERROR="model-checker errord out, see $DEFAULT_RAWDIR/$ID/runner/mc.log"
    elif [ ! -d $TMPDIR/base ] ; then
        ERROR="Error: Repeating the initial recording failed"
    fi
else
    ERROR="Initial recording errord out, see $DEFAULT_RAWDIR/$ID/runner/record.log"
fi

rm -rf output/$ID
mv $TMPDIR $DEFAULT_RAWDIR/$ID

if [[ "$ERROR" != "" ]] ; then
    echo "$ERROR"
    exit 1
fi

if [[ "$REPORT" == "true" ]] ; then
    echo "Running CMD: ./utils/batch-report/report.py \"website\" $DEFAULT_RAWDIR $DEFAULT_REPORTDIR \"$ID\""
    ./utils/batch-report/report.py "website" $DEFAULT_RAWDIR $DEFAULT_REPORTDIR "$ID"
fi

if [[ "$RAWDIR" != "" ]] ; then
    rm -rf $RAWDIR
    mkdir -p $RAWDIR
    mv $DEFAULT_RAWDIR/$ID/* $RAWDIR/
fi

if [[ "$REPORTDIR" != "" ]] ; then
    rm -rf $REPORTDIR
    mkdir -p $REPORTDIR
    mv $DEFAULT_REPORTDIR/$ID/* $REPORTDIR/
fi
