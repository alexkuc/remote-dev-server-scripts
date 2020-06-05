#!/bin/bash

# save credentials
# (using AddKeysToAgent in ssh config)
ssh dev ls > /dev/null 2>&1

inotifywait -rm --exclude '\.git' './' |
while read -r path event file; do
    echo ""
    echo "===== Start ====="
    echo ""
    echo "File: $file"
    echo ""
    echo "Path: $path"
    echo ""
    echo "Event: $event"
    echo ""
    echo "Rsync: "
    echo ""
    ./dev-server/sync.sh
    echo ""
    echo "===== End ====="
done
