#!/bin/bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 UNSIGNED_APP_ZIP AD_HOC.mobileprovision 'Apple Distribution: Name (TEAMID)' IPAD_UDID OUTPUT.ipa" >&2
  exit 2
fi

unsigned_zip=$1
profile=$2
identity=$3
ipad_udid=$4
output=$5

for file in "$unsigned_zip" "$profile"; do
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
  fi
done

if ! security find-identity -v -p codesigning | grep -Fq "\"$identity\""; then
  echo "Signing identity not found in the keychain: $identity" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/legacy-pad-sign.XXXXXX")
trap 'rm -rf "$work"' EXIT
ditto -x -k "$unsigned_zip" "$work"
app="$work/LegacyPadDisplay.app"
if [[ ! -d "$app" ]]; then
  echo "LegacyPadDisplay.app was not found in the unsigned archive" >&2
  exit 1
fi

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
minimum_os=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app/Info.plist")
if [[ "$minimum_os" != 12.0 ]]; then
  echo "Unexpected minimum iOS version: $minimum_os" >&2
  exit 1
fi

security cms -D -i "$profile" > "$work/profile.plist"
plutil -extract Entitlements xml1 -o "$work/entitlements.plist" "$work/profile.plist"
profile_app_id=$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$work/entitlements.plist")
if [[ "$profile_app_id" != *".$bundle_id" ]]; then
  echo "Provisioning profile App ID does not match $bundle_id: $profile_app_id" >&2
  exit 1
fi
if ! /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$work/profile.plist" >/dev/null 2>&1; then
  echo "This is not a device provisioning profile; create an Ad Hoc profile containing the iPad UDID" >&2
  exit 1
fi
if ! /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$work/profile.plist" | grep -Fq "$ipad_udid"; then
  echo "The provisioning profile does not contain iPad UDID $ipad_udid" >&2
  exit 1
fi

ditto "$profile" "$app/embedded.mobileprovision"
if [[ -d "$app/Frameworks" ]]; then
  while IFS= read -r -d '' dylib; do
    codesign --force --sign "$identity" --timestamp=none "$dylib"
  done < <(find "$app/Frameworks" -type f -name '*.dylib' -print0)
  while IFS= read -r -d '' framework; do
    codesign --force --sign "$identity" --timestamp=none "$framework"
  done < <(find "$app/Frameworks" -type d -name '*.framework' -print0)
fi
codesign --force --sign "$identity" --timestamp=none \
  --entitlements "$work/entitlements.plist" "$app"
codesign --verify --deep --strict "$app"

mkdir "$work/Payload"
ditto "$app" "$work/Payload/LegacyPadDisplay.app"
output=$(cd "$(dirname "$output")" && pwd)/$(basename "$output")
ditto -c -k --sequesterRsrc --keepParent "$work/Payload" "$output"
echo "Signed $bundle_id for iOS $minimum_os+: $output"
