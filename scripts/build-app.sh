#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/The Squeeze.app"
contents_dir="$app_dir/Contents"
module_cache="$project_dir/.build/module-cache"

# Some Command Line Tools releases point MacOSX.sdk at an SDK from the next
# point release. Prefer the matching major SDK there; Xcode uses its selected SDK.
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
clt_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ "$sdk_path" == *CommandLineTools* && -d "$clt_sdk" ]]; then
    sdk_path="$clt_sdk"
fi

mkdir -p "$module_cache"
export SDKROOT="$sdk_path"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache"

cd "$project_dir"
swift build --disable-sandbox -c "$configuration"
binary_dir="$(swift build --disable-sandbox -c "$configuration" --show-bin-path)"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/MenuProgress" "$contents_dir/MacOS/MenuProgress"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"

codesign --force --deep --sign - "$app_dir"
echo "Built: $app_dir"
