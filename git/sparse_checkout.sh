#!/bin/bash

URL=$1

if [ -z "$1" ]; then
  echo "Usage [REMOTE-URL]"
  exit 1
fi

REMOTE="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\1/\2/\3.git|p')"
MAIN_DIR="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\3|p')"
SUBDIR="$(echo "$URL" | sed -n 's|\(.*github.com\)/\([^/]*\)/\([^/]*\)/\(.*\)|\4|p')"

test -d "$MAIN_DIR" || mkdir "$MAIN_DIR"
cd "$MAIN_DIR" || exit
test -d .git || git init --initial-branch=main
if [ "$(git remote show | wc -l)" = "0" ]; then
  git remote add origin "$REMOTE"
fi
git config core.sparseCheckout true
if test -f .git/info/sparse-checkout; then 
  git sparse-checkout add "$SUBDIR"
else
  git sparse-checkout set "$SUBDIR"
fi
git pull origin main --depth=1 --ff-only || git pull origin master --depth=1 --ff-only
cd ..
