### Introduction

## Dev Server (DigitalOcean)

Use this script to automatically install and configure DigitalOcean droplet using [cloud-init](https://cloudinit.readthedocs.io/en/latest/). Use either `cloud-config.sh` or `cloud-config.yml` as both provide the same configuration. Script defaults to `./dev-server/cloud-conf.yml` but you can override that behaviour. See env vars defined at the top of the `do.sh`. This script automates a number of actions. To get start with it, do `do.sh help` to list available commands. To make the script available from anywhere, copy it to `/usr/local/bin` (ideally symlink it to always keep it up-to-date). For a more complete documentation on how to use this script, please refer to [this article](https://alexkuc.github.io/articles/create-remote-dev-server-part-2/).

## Manual Scripts

This is a collection of Bash scripts to synchronize changes from local to remote. These scripts are used as a part of an article - [Create Remote Development Server](https://alexkuc.github.io/articles/create-remote-dev-server/).

Clone this repository as a [sub-module](https://git-scm.com/book/en/v2/Git-Tools-Submodules): 

`git submodule add https://github.com/alexkuc/remote-dev-server-scripts.git`

`./watch.sh` to watch current folder (PWD) for changes which get synced to remote

`./sync.sh` one-off sync of current folder (PWD) with remote

Given how everyone's setup is going to be different, this repository contains some concrete assumptions which are listed below:

- you have rsync installed locally *and* remotely
- you have fswatch installed locally
- ".git" folder is ignored and not synced to remote
- "node_modules" folder is ignored and not synced to remote
- "dist" folder is ignored and not synced to remote
- you have SSH connection with the name of "dev" in your SSH config which uses key-based connection

If default scenario is not suitable for you, I guess forking this repository is the right way to go. Alternatively, you can create an issue/PR to help make this code more agnostic.

