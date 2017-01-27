#!/bin/bash

set -o xtrace
set -eu

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "$(uname)" == "Darwin" ]; then
    ICON="$ROOT/build/icon.icns"
else
    ICON="$ROOT/build/icons/lbry48.png"
fi


if [ -n "${TEAMCITY_VERSION:-}" ]; then
  # install dependencies
  $ROOT/prebuild.sh

  VENV="$ROOT/build_venv"
  if [ -d "$VENV" ]; then
    rm -rf "$VENV"
  fi
  virtualenv "$VENV"
  set +u
  source "$VENV/bin/activate"
  set -u
  pip install -U pip setuptools
fi


(
  cd "$ROOT/app"
  npm install
)

(
  cd "$ROOT/lbry"
  pip install -r requirements.txt
  # need to install our version of lbryum, not
  # what is currently on master
  pushd "$ROOT/lbryum"
  pip install .
  popd
  pip install .
)

(
  cd "$ROOT/lbrynet"
  pyinstaller lbry.onefile.spec -y --windowed --onefile
)

(
  cd "$ROOT/lbry-web-ui"
  npm install
  node_modules/.bin/node-sass --output dist/css --sourcemap=none scss/
  node_modules/.bin/webpack
  rm -rf "$ROOT/app/dist"
  cp -r dist "$ROOT/app/dist"
)

mv "$ROOT/lbrynet/dist/lbry" "$ROOT/app/dist"


if [ -n "${TEAMCITY_VERSION:-}" ]; then

  (
    if [ "$(uname)" == "Darwin" ]; then
      security unlock-keychain -p ${KEYCHAIN_PASSWORD} osx-build.keychain
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
      OS="linux"
      PLATFORM="linux"
      tar cvzf "lbry-${OS}.tgz" "LBRY-${PLATFORM}-x64/"
    else
      OS="unknown"
    fi
  )

  node_modules/.bin/build

  echo 'Build and packaging complete.'
else
  echo 'Build complete. Run `electron electron` to launch the app'
fi

if [ -n "${TEAMCITY_VERSION:-}" ]; then
  deactivate
fi
