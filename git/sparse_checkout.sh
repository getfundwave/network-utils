#!/bin/bash

URL=$1
BRANCH=${2:-"main"}

if [ -z "$1" ]; then
  echo "Usage [REMOTE-URL] [BRANCH]"
  echo "BRANCH argument is optional: defaults to main"
  exit 1
fi

# This specifies the remote URL from which to fetch from
REMOTE="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\1/\2/\3.git|p')"

# This specifies the directory name that is to be created
MAIN_DIR="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\3|p')"

# This specifies which subdirectory to selectively clone
SUBDIR="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\4|p')"

test -d "$MAIN_DIR" || mkdir "$MAIN_DIR"
cd "$MAIN_DIR"

# reference: https://stackoverflow.com/questions/600079/how-do-i-clone-a-subdirectory-only-of-a-git-repository
test -d .git || git init --initial-branch="$BRANCH"
if [ "$(git remote show | wc -l)" = "0" ]; then
  git remote add origin "$REMOTE"
fi
git config core.sparseCheckout true
if test -f .git/info/sparse-checkout; then 
  git sparse-checkout add "$SUBDIR"
else
  git sparse-checkout set "$SUBDIR"
fi
git pull origin "$BRANCH" --depth=1 --ff-only

cd ..
