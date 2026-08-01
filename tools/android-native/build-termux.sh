#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$WRAPPER_DIR/../.." && pwd)"
ANDROID_SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/android-sdk}}"
BUILD_TOOLS_35="$ANDROID_SDK_DIR/build-tools/35.0.0"
BUILD_TOOLS_36="$ANDROID_SDK_DIR/build-tools/36.0.0"
GRADLE_CMD="${GRADLE_CMD:-gradle}"
GRADLE_WORKERS="${GRADLE_WORKERS:-6}"
OUTPUT_NAME="${OUTPUT_NAME:-oneproyect-android-native-local.apk}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/storage/downloads}"

require_executable() {
	local target="$1"
	if [[ ! -x "$target" ]]; then
		echo "Falta herramienta ejecutable: $target" >&2
		exit 2
	fi
}

require_executable "$BUILD_TOOLS_35/aapt2"
require_executable "$BUILD_TOOLS_35/dexdump"
require_executable "$BUILD_TOOLS_35/split-select"
require_executable "$BUILD_TOOLS_35/llvm-rs-cc"
require_executable "$BUILD_TOOLS_36/apksigner"

# AGP 9.3 requires Build Tools 36, but Termux's ARM64 package omits three
# inspection helpers. Reuse their real ARM64 binaries from the complete 35.0.0
# package instead of installing x86 tools or invoking ADB.
for tool_name in dexdump split-select llvm-rs-cc; do
	target="$BUILD_TOOLS_36/$tool_name"
	if [[ ! -e "$target" ]]; then
		ln -s "../35.0.0/$tool_name" "$target"
	fi
	require_executable "$target"
done

export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"

cd "$WRAPPER_DIR"
"$GRADLE_CMD" \
	--daemon \
	--parallel \
	--max-workers="$GRADLE_WORKERS" \
	-Pandroid.aapt2FromMavenOverride="$BUILD_TOOLS_35/aapt2" \
	:app:assembleDebug

APK_PATH="$WRAPPER_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -s "$APK_PATH" ]]; then
	echo "El APK no existe o está vacío: $APK_PATH" >&2
	exit 3
fi

"$BUILD_TOOLS_36/apksigner" verify --verbose "$APK_PATH" >/dev/null
APK_LISTING="$(mktemp)"
trap 'rm -f "$APK_LISTING"' EXIT
unzip -Z1 "$APK_PATH" >"$APK_LISTING"
if ! grep -qx "lib/arm64-v8a/libgodot_android.so" "$APK_LISTING"; then
	echo "El APK no contiene Godot ARM64" >&2
	exit 4
fi

mkdir -p "$DOWNLOADS_DIR"
cp "$APK_PATH" "$DOWNLOADS_DIR/$OUTPUT_NAME"
sync

echo "ANDROID_NATIVE_APK_OK"
ls -lh "$DOWNLOADS_DIR/$OUTPUT_NAME"
sha256sum "$DOWNLOADS_DIR/$OUTPUT_NAME"
