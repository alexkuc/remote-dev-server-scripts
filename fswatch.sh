#!/bin/bash

BASEPATH="$(pwd)/"

fswatch -xLr0e "/\.git/" --event-flag-separator=', ' ./ | while read -rd "" FILE EVENT
do
    echo ""
    echo "File: ${FILE#$BASEPATH}"
    echo "Event: $EVENT"
    echo "Rsync: running…"
    ./dev-server/sync.sh
    echo ""
done
