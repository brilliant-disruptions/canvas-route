#!/bin/sh
# Xcode Cloud runs this right after cloning, before it resolves packages or builds.
# Xcode never runs Flutter, so generate what Flutter normally creates on a
# developer's Mac: the plugin Swift package (ios/Flutter/ephemeral/Packages),
# Generated.xcconfig (entry point, version, build number), and the CocoaPods
# workspace that google_maps_flutter_ios still needs.
#
# The GitHub Actions iOS workflow runs this same script, so it stays tested.
set -e

FLUTTER_VERSION=3.47.7
ENTRY="${CANVASROUTE_ENTRY:-lib/main_demo.dart}" # demo build until a backend is chosen
REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"

if ! command -v flutter >/dev/null 2>&1; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

cd "$REPO"
flutter --version
flutter precache --ios
flutter pub get

DEFINES=""
[ -f .env.json ] && DEFINES="--dart-define-from-file=.env.json"

# Xcode Cloud numbers every build; TestFlight needs each upload to be unique.
# --no-codesign: there are no signing certificates on the build machine at this
# point (Xcode Cloud signs later, during the archive), and without the flag
# Flutter stops with "No development certificates available".
# shellcheck disable=SC2086
flutter build ios --config-only --release --no-codesign -t "$ENTRY" $DEFINES --build-number "${CI_BUILD_NUMBER:-1}"

# config-only normally runs pod install; make sure the Pods project exists either way.
if [ ! -d ios/Pods ]; then
  (cd ios && pod install)
fi
