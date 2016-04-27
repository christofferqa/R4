#!/bin/bash

set -ue -o pipefail

# INPUT HANDLING

if (( ! $# > 0 )); then
    echo "Usage: <website URL> <base dir> [--verbose] [--auto] [--depth x] [--high-time-limit] [--old-style-bound] [--extras]"
    echo "Outputs result of model-checking the recording in <base dir>/record"
    exit 1
fi

URL=$1
OUTDIR=$2

shift
shift

PROTOCOL=http
AUTO=0
VERBOSE=0
COOKIESCMD=""
DEPTH=1
TIMEOUT=60
TIMEOUTCMD=""
BOUND=""
EXTRAS=""
PROXYCMD=""
TRIGGER_EVENT_TYPE=""
TRIGGER_NODE_IDENTIFIER=""

while [[ $# > 0 ]]; do
    case $1 in
        --extras)
            shift
            EXTRAS=$1
            ;;
        --high-time-limit)
            TIMEOUT="800"
            TIMEOUTCMD="-scheduler_timeout_ms 150000"
            ;;
        --old-style-bound)
            BOUND="-conflict_reversal_bound_oldstyle true"
            ;;
        --auto)
            AUTO=1
            ;;
        --verbose)
            VERBOSE=1
            ;;
        --cookie)
            shift
            #COOKIESCMD="$COOKIESCMD -cookie $1"
            ;;
        --depth)
            shift
            DEPTH=$1
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

REPLAY_BIN=$WEBERA_DIR/R4/clients/Replay/bin/replay
ER_BIN=$EVENTRACER_DIR/bin/eventracer/webera/run_schedules
BER_BIN=$EVENTRACER_DIR/bin/eventracer/webera/webera

OUTRECORD=$OUTDIR/record
OUTRUNNER=$OUTDIR/runner

if [[ $VERBOSE -eq 1 ]]; then
    VERBOSECMD="-verbose"
else
    VERBOSECMD=""
fi

if [[ $AUTO -eq 1 ]]; then
    AUTOCMD="-hidewindow"
elif [[ "$TRIGGER_EVENT_TYPE" != "" && "$TRIGGER_NODE_IDENTIFIER" != "" ]] ; then
    AUTOCMD="-hidewindow"
else
    AUTOCMD="-ignore-mouse-move"
fi

echo "Running " $PROTOCOL $URL " @ " $OUTDIR

mkdir -p $OUTRUNNER

CMD="/usr/bin/time -p $ER_BIN $BOUND $EXTRAS -conflict_reversal_bound=$DEPTH -in_dir=$OUTRECORD/ -in_schedule_file=$OUTRECORD/schedule.data -tmp_new_schedule_file=$OUTDIR/new_schedule.data -out_dir=$OUTDIR -tmp_error_log=$OUTDIR/out.errors.log -tmp_network_log=$OUTDIR/out.log.network.data -tmp_time_log=$OUTDIR/out.log.time.data -tmp_random_log=$OUTDIR/out.log.random.data -tmp_status_log=$OUTDIR/out.status.data -tmp_png_file=$OUTDIR/out.screenshot.png -tmp_schedule_file=$OUTDIR/out.schedule.data -tmp_stdout=$OUTDIR/stdout.txt -tmp_er_log_file=$OUTDIR/out.ER_actionlog --site=$PROTOCOL://$URL"

REPLAY_CMD="$REPLAY_BIN $AUTOCMD $PROXYCMD $VERBOSECMD $COOKIESCMD -out_dir $OUTDIR -timeout $TIMEOUT $TIMEOUTCMD -in_dir %s/ \"%s\" %s"

if [[ $VERBOSE -eq 1 ]]; then
    echo "> $CMD --replay_command=\"$REPLAY_CMD\""
    $CMD --replay_command="$REPLAY_CMD" 2>&1 | tee $OUTRUNNER/stdout.txt
else
    $CMD --replay_command="$REPLAY_CMD" &> $OUTRUNNER/stdout.txt
fi

if [ ! -d $OUTDIR/base ]; then
    echo "Error: Repeating the initial recording failed"
    exit 1
fi

