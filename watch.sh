#!/bin/bash

INOTIFYWAIT=$(which inotifywait)
FSWATCH=$(which fswatch)

if [[ -n "$FSWATCH" ]]; then
    echo ""
    echo "Using fswatch…"
    echo ""
    ./dev-server/fswatch.sh
elif [[ -n "$INOTIFYWAIT" ]]; then
    echo ""
    echo "Using inotifywait…"
    echo ""
    ./dev-server/inotifywait.sh
else
    echo ""
    echo "Please install either fswatch or inotifywait…"
    echo ""
fi
