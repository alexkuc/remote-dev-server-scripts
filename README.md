### Introduction

This is a collection of Bash scripts to synchronize changes from local to remote. These scripts are used as a part of an article - [Create Remote Development Server](https://alexkuc.github.io/articles/create-remote-dev-server/).

Clone this repository as a [sub-module](https://git-scm.com/book/en/v2/Git-Tools-Submodules) with directory name "dev-server": 

`git submodule add https://github.com/alexkuc/remote-dev-server-scripts.git dev-server`

Given how everyone's setup is going to be different, this repository contains some concrete assumptions which are listed below:

- you have rsync installed locally *and* remotely
- you have either fswatch or inotifway installed locally
- ".git" folder is ignored and not synced to remote
- "node_modules" folder is ignored and not synced to remote
- you have SSH connection with the name of "dev" in your SSH config which uses key-based connection
- in case you have both, "fswatch" and "inotifywait" installed, Bash script defaults to "fswatch"

If default scenario is not suitable for you, I guess forking this repository is the right way to go. Alternatively, you can create an issue/PR to help make this code more agnostic.

