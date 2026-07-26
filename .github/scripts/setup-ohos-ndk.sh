#!/usr/bin/env bash
# Setup OHOS NDK for cross-compiling to aarch64-linux-ohos.
#
# Reference: https://gist.github.com/ronaldtse/78b6b610cfa00ead8fb3b8f935afaa3b
#
# Usage: setup-ohos-ndk.sh --prefix /opt/ohos
#
# Downloads ~4 GB total (ohos-sdk-public + LLVM-19) from the OpenHarmony
# daily_build API. Idempotent: skips downloads if $PREFIX already populated.

set -euo pipefail

PREFIX=""
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$PREFIX" ]; then
    echo "Usage: $0 --prefix /opt/ohos" >&2
    exit 2
fi

PREFIX="$(cd "$(mkdir -p "$PREFIX" && cd "$PREFIX" && pwd)" && pwd)"
echo "[setup-ohos-ndk] PREFIX=$PREFIX"

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }
command -v jq   >/dev/null || { echo "jq required"   >&2; exit 1; }
command -v unzip >/dev/null || { echo "unzip required" >&2; exit 1; }

# --- Query the OpenHarmony daily_build API (public, no auth) --------------
query_component() {
    local component="$1"
    # Build the JSON payload with jq to avoid fragile quote-juggling.
    local payload
    payload=$(jq -nc \
        --arg component "$component" \
        '{projectName:"openharmony", branch:"master", pageNum:1, pageSize:10,
          deviceLevel:"", component:$component, type:1,
          startTime:"2025080100000000", endTime:"20990101235959",
          sortType:"", sortField:"", hardwareBoard:"",
          buildStatus:"success", buildFailReason:"", withDomain:1}')
    curl --retry 5 --retry-delay 5 --retry-all-errors -fsSL \
        'https://dcp.openharmony.cn/api/daily_build/build/list/component' \
        -H 'Accept: application/json, text/plain, */*' \
        -H 'Content-Type: application/json' \
        --data-raw "$payload"
}

# --- Skip if the toolchain file is already in place ------------------------
TOOLCHAIN="$PREFIX/ohos-sdk/linux/native/build/cmake/ohos.toolchain.cmake"
if [ -f "$TOOLCHAIN" ] && [ -d "$PREFIX/llvm-19/sysroot/aarch64-linux-ohos" ]; then
    echo "[setup-ohos-ndk] already populated, skipping"
    exit 0
fi

echo "[setup-ohos-ndk] querying daily_build API for component URLs..."
SDK_URL=$(query_component "ohos-sdk-public" | jq -r '.data.list.dataList[0].obsPath')
LLVM_URL=$(query_component "LLVM-19"         | jq -r '.data.list.dataList[0].obsPath')

if [ -z "$SDK_URL" ] || [ "$SDK_URL" = "null" ]; then
    echo "[setup-ohos-ndk] failed to resolve ohos-sdk-public URL" >&2
    exit 1
fi
if [ -z "$LLVM_URL" ] || [ "$LLVM_URL" = "null" ]; then
    echo "[setup-ohos-ndk] failed to resolve LLVM-19 URL" >&2
    exit 1
fi
echo "[setup-ohos-ndk] sdk  = $SDK_URL"
echo "[setup-ohos-ndk] llvm = $LLVM_URL"

mkdir -p "$PREFIX/downloads"

SDK_TARBALL="$PREFIX/downloads/ohos-sdk.tar.gz"
LLVM_TARBALL="$PREFIX/downloads/llvm-19.tar.gz"

if [ ! -f "$SDK_TARBALL" ]; then
    echo "[setup-ohos-ndk] downloading ohos-sdk (~3.2 GB)..."
    curl --retry 5 --retry-delay 5 --retry-all-errors -fL "$SDK_URL" -o "$SDK_TARBALL"
fi

if [ ! -f "$LLVM_TARBALL" ]; then
    echo "[setup-ohos-ndk] downloading LLVM-19 (~670 MB)..."
    curl --retry 5 --retry-delay 5 --retry-all-errors -fL "$LLVM_URL" -o "$LLVM_TARBALL"
fi

# --- Extract ohos-sdk ----------------------------------------------------
# The outer archive is a .tar.gz containing `ohos-sdk/linux/*.zip`.
# The inner .zip files unpack the actual toolchain components.
echo "[setup-ohos-ndk] extracting ohos-sdk into $PREFIX..."
tar -xzf "$SDK_TARBALL" -C "$PREFIX"

# Unzip every nested zip under ohos-sdk/linux/.
cd "$PREFIX/ohos-sdk/linux"
for z in *.zip; do
    [ -e "$z" ] || continue
    echo "[setup-ohos-ndk]   unzipping $z"
    unzip -q -o "$z"
    rm -f "$z"
done

# --- Extract LLVM-19 -----------------------------------------------------
echo "[setup-ohos-ndk] extracting LLVM-19 into $PREFIX..."
# LLVM-19 archive layout (per build): outer .tar.gz contains nested
#   llvm-linux-x86_64.tar.gz   (the x86_64 clang that targets aarch64-linux-ohos)
#   ohos-sysroot.tar.gz        (per-arch sysroots)
# We extract the outer tar.gz, then look for nested .tar.gz files and
# extract those too. Final layout: $PREFIX/llvm-19/{llvm, sysroot}.
mkdir -p "$PREFIX/llvm-19-extract"
tar -xzf "$LLVM_TARBALL" -C "$PREFIX/llvm-19-extract"

# Recursively extract any nested .tar.gz files we find.
# This handles both single-level and multi-level nesting.
changed=1
while [ "$changed" = "1" ]; do
    changed=0
    while IFS= read -r -d '' tg; do
        echo "[setup-ohos-ndk]   expanding nested $(basename "$tg")"
        tar -xzf "$tg" -C "$(dirname "$tg")"
        rm -f "$tg"
        changed=1
    done < <(find "$PREFIX/llvm-19-extract" -name '*.tar.gz' -print0)
done

rm -rf "$PREFIX/llvm-19"
mkdir -p "$PREFIX/llvm-19/llvm" "$PREFIX/llvm-19/sysroot"

# Locate clang: prefer aarch64-linux-ohos-clang (target-specific) else generic clang.
CLANG_SRC=$(find "$PREFIX/llvm-19-extract" -type f -name 'aarch64-*-ohos-clang' -path '*/bin/*' | head -1)
[ -z "$CLANG_SRC" ] && CLANG_SRC=$(find "$PREFIX/llvm-19-extract" -type f -name 'clang' -path '*/bin/*' | head -1)

# Locate sysroot: an aarch64-linux-ohos/ directory whose usr/include/bits/ exists.
SYSROOT_SRC=""
while IFS= read -r -d '' cand; do
    if [ -d "$cand/usr/include/bits" ]; then
        SYSROOT_SRC="$cand"
        break
    fi
done < <(find "$PREFIX/llvm-19-extract" -type d -name 'aarch64-linux-ohos' -print0)

if [ -z "$CLANG_SRC" ] || [ -z "$SYSROOT_SRC" ]; then
    echo "[setup-ohos-ndk] FAIL: couldn't locate clang or per-arch sysroot after recursive extract" >&2
    echo "[setup-ohos-ndk] archive contents (depth 4):" >&2
    find "$PREFIX/llvm-19-extract" -maxdepth 4 -type d >&2 | head -40 || true
    echo "[setup-ohos-ndk] clang candidates:" >&2
    find "$PREFIX/llvm-19-extract" -type f -name '*clang*' >&2 | head -10 || true
    exit 1
fi

# Move the discovered clang's bin/, lib/, include/ etc into $PREFIX/llvm-19/llvm/.
LLVM_ROOT=$(cd "$(dirname "$CLANG_SRC")/.." && pwd)
if [ "$(basename "$LLVM_ROOT")" = "llvm-linux-x86_64" ] || [ "$(basename "$LLVM_ROOT")" = "llvm" ]; then
    rmdir "$PREFIX/llvm-19/llvm"
    mv "$LLVM_ROOT" "$PREFIX/llvm-19/llvm"
else
    cp -a "$LLVM_ROOT/." "$PREFIX/llvm-19/llvm/"
fi

# Move the sysroot into place.
rmdir "$PREFIX/llvm-19/sysroot"
mv "$SYSROOT_SRC" "$PREFIX/llvm-19/sysroot"
rm -rf "$PREFIX/llvm-19-extract"

# --- The two-sysroots fix (CRITICAL) -------------------------------------
# SDK ships a MULTIARCH sysroot (usr/include/<arch>/bits/...). The official
# ohos.toolchain.cmake expects PER-ARCH layout (<arch>/usr/include/bits/...).
# Replace the SDK's sysroot with a RELATIVE symlink to LLVM-19's per-arch
# sysroot. Relative (not absolute) so it survives container mount paths.
cd "$PREFIX/ohos-sdk/linux/native"
rm -rf sysroot
ln -s "../../../llvm-19/sysroot/aarch64-linux-ohos" sysroot

# Sanity check.
if [ ! -f "$TOOLCHAIN" ]; then
    echo "[setup-ohos-ndk] FAIL: ohos.toolchain.cmake missing at $TOOLCHAIN" >&2
    exit 1
fi
if [ ! -f "$PREFIX/ohos-sdk/linux/native/sysroot/usr/include/bits/alltypes.h" ]; then
    echo "[setup-ohos-ndk] FAIL: per-arch sysroot symlink did not resolve" >&2
    ls -la "$PREFIX/ohos-sdk/linux/native/sysroot/usr/include/" >&2 || true
    exit 1
fi
if [ ! -x "$PREFIX/llvm-19/llvm/bin/clang" ]; then
    echo "[setup-ohos-ndk] FAIL: clang not found at \$PREFIX/llvm-19/llvm/bin/clang" >&2
    ls -la "$PREFIX/llvm-19" >&2 || true
    exit 1
fi

echo "[setup-ohos-ndk] OK"
echo "[setup-ohos-ndk]   toolchain: $TOOLCHAIN"
echo "[setup-ohos-ndk]   sysroot:   $PREFIX/ohos-sdk/linux/native/sysroot -> $(readlink "$PREFIX/ohos-sdk/linux/native/sysroot")"
echo "[setup-ohos-ndk]   clang:     $PREFIX/llvm-19/llvm/bin/clang"
echo "[setup-ohos-ndk]   signer:    $PREFIX/ohos-sdk/linux/toolchains/lib/binary-sign-tool"
