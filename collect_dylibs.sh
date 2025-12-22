#!/bin/zsh
# Script to collect all dylibs used by imgclean, copy to imgclean-frameworks, re-sign, and fix rpath
set -e

# Paths
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXECUTABLE="$ROOT_DIR/imgclean/project/build/imgclean"
FRAMEWORKS_DIR="$ROOT_DIR/imgclean-frameworks"

# Create imgclean-frameworks directory
mkdir -p "$FRAMEWORKS_DIR"

# Helper to resolve non-absolute dylib paths
find_dylib_path() {
    local name="$1"
    local parent="$2"
    # Try build dir
    if [ -f "$ROOT_DIR/imgclean/project/build/$name" ]; then
        echo "$ROOT_DIR/imgclean/project/build/$name"
        return
    fi
    # Try /usr/local/lib
    if [ -f "/usr/local/lib/$name" ]; then
        echo "/usr/local/lib/$name"
        return
    fi
    # Try /opt/homebrew/lib (Apple Silicon)
    if [ -f "/opt/homebrew/lib/$name" ]; then
        echo "/opt/homebrew/lib/$name"
        return
    fi
    # Try /opt/homebrew/opt/gcc/lib/gcc/current/
    if [ -f "/opt/homebrew/opt/gcc/lib/gcc/current/$name" ]; then
        echo "/opt/homebrew/opt/gcc/lib/gcc/current/$name"
        return
    fi
    # Try /usr/lib
    if [ -f "/usr/lib/$name" ]; then
        echo "/usr/lib/$name"
        return
    fi
    # Try resolving @rpath using parent's rpaths
    if [[ -n "$parent" ]]; then
        local rpaths=($(otool -l "$parent" | awk '/LC_RPATH/ {getline; print $2}'))
        for rpath in $rpaths; do
            if [ -f "$rpath/$name" ]; then
                echo "$rpath/$name"
                return
            fi
        done
    fi
    # Not found
    echo ""
}

# Track already copied dylibs as a newline-separated string
COPIED_DYLIBS=""

copy_and_patch_dylib() {
    local dylib="$1"
    local parent="$2" # parent binary for install_name_tool
    local dylib_name=$(basename "$dylib")

    # Skip if already copied
    if [[ "$COPIED_DYLIBS" == *"\n$dylib_name\n"* ]]; then
        return
    fi

    # If not absolute, try to resolve
    local dylib_path="$dylib"
    if [[ ! "$dylib" = /* ]]; then
        dylib_path=$(find_dylib_path "$dylib_name" "$parent")
    fi
    if [ -z "$dylib_path" ] || [ ! -f "$dylib_path" ]; then
        echo "Warning: Could not find dylib $dylib_name (original: $dylib), skipping."
        return
    fi

    cp -f "$dylib_path" "$FRAMEWORKS_DIR/$dylib_name"
    codesign --force --sign - "$FRAMEWORKS_DIR/$dylib_name"
    # Update parent binary to use @rpath for this dylib
    if [ -n "$parent" ]; then
        install_name_tool -change "$dylib" "@rpath/$dylib_name" "$parent"
    fi
    COPIED_DYLIBS="$COPIED_DYLIBS\n$dylib_name\n"

    # Recursively process dependencies of this dylib
    local subdeps
    subdeps=("${(@f)$(otool -L "$FRAMEWORKS_DIR/$dylib_name" | awk '/\/(usr|System)\// {next} /dylib/ {print $1}')}")
    for subdylib in $subdeps; do
        copy_and_patch_dylib "$subdylib" "$FRAMEWORKS_DIR/$dylib_name"
    done
}

# Start with direct dependencies of imgclean
DYLIBS=(${(@f)$(otool -L "$EXECUTABLE" | awk '/\/(usr|System)\// {next} /dylib/ {print $1}')})
for dylib in $DYLIBS; do
    copy_and_patch_dylib "$dylib" "$EXECUTABLE"
done

install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE"

echo "All dylibs collected, re-signed, and rpath updated."
