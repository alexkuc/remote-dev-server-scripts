#!/bin/bash

BASEPATH="$(pwd)/"

fswatch -xLr0 --event-flag-separator=', ' ./ \
    -e "/\.git" \
    -e "/node_modules" \
    -e "/dist" \
| while read -rd "" FILE EVENT
do
    echo ""
    echo "File: ${FILE#$BASEPATH}"
    echo "Event: $EVENT"
    echo "Rsync: running…"
    FOLDER=$(dirname "${BASH_SOURCE[0]}")
    "$FOLDER/sync.sh"
    echo ""
done
