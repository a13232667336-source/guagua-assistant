#!/usr/bin/env bash
# 呱呱助手 —— 一键产出「巨魔注入器（TrollFools）/ TrollStore」可直接用的文件。
#
# 用法：
#   ./build-trollfools.sh
#
# 产物（都在 packages/ 里）：
#   Guagua.dylib                     —— 单个 dylib，TrollFools 直接注入
#   Guagua-TrollFools.zip           —— dylib + 资源包（推荐，TrollFools 会一并装）
#   com.samuel.guagua_1.0.0_iphoneos-arm.deb —— 越狱 / TrollFools 的 deb 注入
#
# 依赖：Theos（$THEOS）、ldid、zip；FFmpeg 静态库（deps/ffmpeg-kit-next/build/lib）
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say() { printf '\033[1;32m%s\033[0m\n' "$1"; }
die() { printf '\033[1;31m错误: %s\033[0m\n' "$1" >&2; exit 1; }

command -v make >/dev/null 2>&1 || die "找不到 make"
[[ -n "${THEOS:-}" ]] || die "没有设置 THEOS（先安装 Theos 并 export THEOS=...）"

VERSION="$(sed -n 's/^Version: //p' control | head -n1)"
NAME="$(sed -n 's/^Name: //p' control | head -n1)"

# 依赖仓库（zip 分发时子模块目录是空的，这里按需补下来）
ensure_source() {
  local path="$1" url="$2"
  if [[ -z "$(ls -A "$path" 2>/dev/null || true)" ]]; then
    say "拉取依赖 $url → $path"
    git clone --depth 1 "$url" "$path"
  fi
}
ensure_source deps/ffmpeg-kit-next/upstream https://github.com/arthenica/ffmpeg-kit-next

# FFmpeg 静态库是编译期依赖，没编过就先编（很慢，第一次要几十分钟）
if [[ ! -f "$SCRIPT_DIR/deps/ffmpeg-kit-next/build/lib/libffmpegkit.a" ]]; then
  say "没有找到 FFmpeg 静态库，开始从源码编译（第一次比较久）…"
  git -C "$SCRIPT_DIR" submodule update --init deps/ffmpeg-kit-next/upstream
  "$SCRIPT_DIR/deps/ffmpeg-kit-next/build-ffmpeg.sh"
fi

say "编译 tweak（$(uname -s) / $(uname -m)）…"
rm -rf .theos
make clean >/dev/null 2>&1 || true
make

DYLIB=""
for candidate in .theos/obj/debug/Guagua.dylib .theos/obj/Guagua.dylib \
                 .theos/obj/arm64/Guagua.dylib .theos/obj/debug/arm64/Guagua.dylib; do
  if [[ -f "$candidate" ]]; then DYLIB="$candidate"; break; fi
done
[[ -n "$DYLIB" ]] || die "没找到编译出来的 Guagua.dylib"
say "dylib: $DYLIB"

mkdir -p packages
cp -f "$DYLIB" "packages/Guagua.dylib"

# TrollFools 的 zip：dylib + 资源包放同一层，注入时会一起装进 app
STAGE="$(mktemp -d)"
cp "$DYLIB" "$STAGE/Guagua.dylib"
cp -R "layout/Library/Application Support/Guagua/Guagua.bundle" "$STAGE/Guagua.bundle"
( cd "$STAGE" && zip -qry "$SCRIPT_DIR/packages/Guagua-TrollFools.zip" . )
rm -rf "$STAGE"

say "打包 deb…"
make package >/dev/null

say "完成，产物："
ls -lh packages | sed 's/^/  /'
