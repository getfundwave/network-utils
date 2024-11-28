#!/bin/bash

REMOTE_URL=$1
SUBDIR=$2
BRANCH=${3:-"main"}

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage [REMOTE-URL] [SUBDIRECTORY] [BRANCH]"
  echo "BRANCH argument is optional: defaults to main"
  exit 1
fi

# This specifies the directory name that is to be created
MAIN_DIR="$(echo "$REMOTE_URL" | sed -n 's|\(.*com\)/\([^/]*\)/\([^/]*\)|\3|p')"

# reference: https://stackoverflow.com/questions/4114887/is-it-possible-to-do-a-sparse-checkout-without-checking-out-the-whole-repository

test -d "$MAIN_DIR" || git clone --filter=blob:none --no-checkout --depth 1 --sparse "$REMOTE_URL"
cd "$MAIN_DIR"

git config core.sparseCheckout true
if test -f .git/info/sparse-checkout; then
  [ "$(grep -c "$SUBDIR" .git/info/sparse-checkout)" -eq 0 ] && git sparse-checkout add "$SUBDIR"
else
  git sparse-checkout set "$SUBDIR"
fi
git checkout --force
git pull origin "$BRANCH" --depth=1 --rebase --force

cd ..
