#!/bin/bash

BASEPATH="$(pwd)/"

fswatch -xLr0e "/\.git/" --event-flag-separator=', ' ./ | while read -rd "" FILE EVENT
do
    echo ""
    echo "File: ${FILE#$BASEPATH}"
    echo "Event: $EVENT"
    echo "Rsync: running…"
    FOLDER=$(dirname "${BASH_SOURCE[0]}")
    "$FOLDER/sync.sh"
    echo ""
done
