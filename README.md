# Introduction

## Dev Server (DigitalOcean)

### Requirements

- DigitalOcean account
- Bash, at least version 4
- doctl
- rsync (`do.sh sync`)
- fswatch (`do.sh watch`)
- scp (`do.sh copy` `do.sh scp`)

### Introduction

Use this script to automatically install and configure DigitalOcean droplet using [cloud-init](https://cloudinit.readthedocs.io/en/latest/). Use either `cloud-config.sh` or `cloud-config.yml` as both provide the same configuration. The script defaults to `./dev-server/cloud-conf.yml` but you can override that behavior. See env vars defined at the top of the `do.sh`. This script automates several actions. To get started with it, do `do.sh help`, to list available commands. To make this script available from anywhere, copy it to `/usr/local/bin` (ideally symlink it to always keep it up-to-date). For more complete documentation on how to use this script, please refer to [this article](https://alexkuc.github.io/articles/create-remote-dev-server-part-2/). Technically speaking, it would be very hard to make this script accommodate every possible configuration scenario out there. So there are two options, either to submit a PR or fork this repository.

### Intended Audience

This is not a homegrown puppet/chef/ansible/etc but rather a way to automatically provision a single remote development server. The idea is to move heavy processing from a local to a remote machine. Another scenario is where your local environment is not the most suitable. For example, OSX and Docker support where on Linux Docker runs much much better. Before you accuse me of being incompetent, I am referring to these issues:

- [File access in mounted volumes extremely slow #77](https://github.com/docker/for-mac/issues/77)
- [docker on Mac OS High Sierra is so slow: 20 time slower than Ubuntu #2659](https://github.com/docker/for-mac/issues/2659)
- [Docker in MacOs is very slow](https://stackoverflow.com/questions/55951014/docker-in-macos-is-very-slow)
- [Docker for Mac vs docker-toolbox?](https://www.reddit.com/r/docker/comments/5v8fc7/docker_for_mac_vs_dockertoolbox/)

### Cool Features

What makes this script better than me simply using `doctl` on my own?:

- one-button solution: to get started, simple do: `do.sh up`
- command chaining (only certain commands)*
  - see `do.sh help` for a list of commands which support chaining
- create ssh socket to avoid re-connecting to remote host for every command
- re-write remote path with local (`do.sh cmd`)
  - when running a command such as `ls -l`, replace remote cwd with local cwd
  - useful for debugging and investigating failed unit tests
- useful built-in commands, e.g. `do.sh scp` to copy from remote to local cwd
  - for a full list of commands, see `do.sh help`

>*only commands which support a fixed number of arguments, e.g. `do.sh up prep sync`

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

