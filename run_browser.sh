#!/bin/bash

SITE=""
PROXY="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --h)
            echo "Usage: ./run-browser.sh <website URL> [--proxy]"
            exit 0
            ;;
        --proxy)
            PROXY="true"
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

if [[ "$PROXY" == "true" ]] ; then
    http_proxy=http://"":""@127.0.0.1:8081 WebKitBuild/Release/bin/QtTestBrowser $SITE
else
	WebKitBuild/Release/bin/QtTestBrowser $SITE
fi
