#!/bin/bash

set -ue -o pipefail

# INPUT HANDLING

if (( ! $# > 0 )); then
    echo "Usage: <website URL> <base dir> [--verbose] [--auto] [--cookie key=value]* [--move-mouse]"  
    echo "Outputs result of recording to <base dir>/record"
    exit 1
fi

URL=$1
OUTDIR=$2

shift
shift

PROTOCOL=http
VERBOSE=0
AUTO=0
COOKIESCMD=""
MOVEMOUSE=0
PROXYCMD=""
TRIGGER_EVENT_TYPE=""
TRIGGER_NODE_IDENTIFIER=""

while [[ $# > 0 ]]; do
    case $1 in
        --auto)
            AUTO=1
            ;;
        --move-mouse)
            MOVEMOUSE=1
            ;;
        --verbose)
            VERBOSE=1
            ;;
        --cookie)
            shift
            COOKIESCMD="$COOKIESCMD -cookie $1"
            ;;
        --proxy)
            PROXYCMD="-proxy 127.0.0.1:8081"
            ;;
        --trigger-event-type=*)
            TRIGGER_EVENT_TYPE="${1#*=}"
            ;;
        --trigger-node-identifier=*)
            TRIGGER_NODE_IDENTIFIER="${1#*=}"
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
    shift
done

# DO SOMETHING

mkdir -p $OUTDIR

RECORD_BIN=$WEBERA_DIR/R4/clients/Record/bin/record
OUTRECORD=$OUTDIR/record

if [[ $VERBOSE -eq 1 ]]; then
    VERBOSECMD="-verbose"
else
    VERBOSECMD=""
fi

if [[ $AUTO -eq 1 ]]; then
    AUTOCMD="-hidewindow -autoexplore -autoexplore-timeout 10"
else
    if [[ $MOVEMOUSE -eq 1 ]]; then
        AUTOCMD=""
    else
        AUTOCMD="-ignore-mouse-move"
    fi
fi


if [[ "$TRIGGER_EVENT_TYPE" != "" && "$TRIGGER_NODE_IDENTIFIER" != "" ]] ; then
    TRIGGERCMD="-hidewindow -trigger -trigger-event-type $TRIGGER_EVENT_TYPE"
else
    TRIGGERCMD=""
fi

echo "Running "  $PROTOCOL $URL " @ " $OUTDIR
mkdir -p $OUTRECORD

ARGS="$PROXYCMD -out_dir $OUTRECORD $AUTOCMD $TRIGGERCMD $VERBOSECMD $COOKIESCMD"

if [[ $VERBOSE -eq 1 ]]; then
    echo "> $RECORD_BIN $ARGS -trigger-node-identifier \"$TRIGGER_NODE_IDENTIFIER\" $PROTOCOL://$URL"
    $RECORD_BIN $ARGS -trigger-node-identifier "$TRIGGER_NODE_IDENTIFIER" $PROTOCOL://$URL 2>&1 | tee $OUTRECORD/out.log
else
    $RECORD_BIN $ARGS -trigger-node-identifier "$TRIGGER_NODE_IDENTIFIER" $PROTOCOL://$URL &> $OUTRECORD/out.log
fi

