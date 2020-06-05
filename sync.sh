#!/bin/bash

rsync -az --progress --delete \
    --exclude=.git/ \
    --exclude=node_modules/ \
    --exclude=dist/ \
./ dev:/repo
