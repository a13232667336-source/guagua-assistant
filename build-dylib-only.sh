#!/usr/bin/env bash
# 只出一个 Guagua.dylib（TrollFools 注入器直接选它）。
#   ./build-dylib-only.sh
# 产物：dist/Guagua.dylib
set -Eeuo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[1;32m%s\033[0m\n' "$1"; }
die() { printf '\033[1;31m错误: %s\033[0m\n' "$1" >&2; exit 1; }

command -v make >/dev/null 2>&1 || die "缺少 make"
[[ -n "${THEOS:-}" ]] || die "没有设置 THEOS，先装 Theos 并 export THEOS=~/theos"

# 依赖库（zip 分发时子模块目录是空的）
if [[ -z "$(ls -A deps/ffmpeg-kit-next/upstream 2>/dev/null || true)" ]]; then
  say "拉取 ffmpeg-kit-next …"
  git clone --depth 1 https://github.com/arthenica/ffmpeg-kit-next deps/ffmpeg-kit-next/upstream
fi

if [[ ! -f deps/ffmpeg-kit-next/build/lib/libffmpegkit.a ]]; then
  say "编译 FFmpeg 静态库（第一次很久）…"
  ./deps/ffmpeg-kit-next/build-ffmpeg.sh
fi

say "编译 tweak …"
make clean >/dev/null 2>&1 || true
make

DYLIB=$(find .theos/obj -name 'Guagua.dylib' | head -n1)
[[ -n "$DYLIB" ]] || die "没找到 Guagua.dylib"

mkdir -p dist
cp -f "$DYLIB" dist/Guagua.dylib
say "好了：$(pwd)/dist/Guagua.dylib"
ls -lh dist/Guagua.dylib
