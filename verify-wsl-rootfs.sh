#!/usr/bin/env bash
# WSL rootfs 产物校验(发布门): 解包 tar.gz, 断言许可证据/品牌资产/crash-watch/包版本/证书。
#
# 用法: ./verify-wsl-rootfs.sh out/linxira-wsl-<ver>-x86_64.tar.gz
# 环境变量:
#   LINXIRA_ARTWORK_DIR  艺术仓路径(默认 ../linxira-artwork, 用于品牌资产一致性比对)
#
# 设计: 只读断言, 不改镜像; 任一断言失败退出非零。解包目录用 /var/tmp(普通磁盘),
# 不用 /tmp(理由同 build-wsl-rootfs.sh)。
set -uo pipefail

image=${1:?usage: $0 <image.tar.gz>}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
artwork=${LINXIRA_ARTWORK_DIR:-$here/../linxira-artwork}
packages_file=$here/wsl-packages.x86_64
[[ -r "$image" ]] || { echo "找不到 $image" >&2; exit 64; }
[[ -r "$packages_file" ]] || { echo "找不到 $packages_file" >&2; exit 64; }

work=$(mktemp -d /var/tmp/verify-wsl.XXXXXX)
trap 'rm -rf "$work"' EXIT

echo "== 解包 $image"
tar -xzf "$image" -C "$work" || exit 1
fail=0
check() { if [[ -s "$work/$1" ]]; then printf '  ok   %s\n' "$1"; else printf '  MISS %s\n' "$1"; fail=1; fi; }
same_lf() { # 逐字节比对(忽略 CRLF 差异; Windows 检出会把工作区行尾改成 CRLF)
  if [[ ! -f "$work/$1" || ! -f "$2" ]]; then printf '  MISS %s 或 %s\n' "$1" "$2"; fail=1; return; fi
  if cmp -s <(tr -d '\r' < "$work/$1") <(tr -d '\r' < "$2"); then printf '  ok   %s == 艺术仓\n' "$1"; else printf '  DIFF %s\n' "$1"; fail=1; fi
}

echo "== 许可证据三件套"
check usr/share/doc/linxira/THIRD-PARTY-NOTICES.md
check usr/share/doc/linxira/SOURCE-OFFER
check usr/share/doc/linxira/license-manifest.json

echo "== 镜像版本标识"
check etc/linxira-release
if [[ -s "$work/etc/linxira-release" ]]; then
  printf '  info %s\n' "$(cat "$work/etc/linxira-release")"
fi

echo "== 品牌资产 + 图标族"
check usr/share/linxira/linxira-icon.svg
check usr/share/linxira/linxira-logo-braille60.ansi
for icon in linxira.svg org.linxira.CrashWatch.svg linxira-update.svg linxira-package-center.svg \
            linxira-config-hub.svg linxira-components.svg; do
  check "usr/share/icons/hicolor/scalable/apps/$icon"
done
icons=$(ls "$work/usr/share/icons/hicolor/scalable/apps/"*.svg 2>/dev/null | wc -l)
echo "  info 族图标数量: $icons"; [[ $icons -ge 10 ]] || { echo "  MISS 族图标 <10"; fail=1; }

echo "== 终端标识与 shell 条目"
check etc/fastfetch/config.d/linxira.jsonc
check usr/share/linxira/catalog/catalog-v3.json
for c in component-fish component-nushell component-zsh; do
  if grep -q "\"$c\"" "$work/usr/share/linxira/catalog/catalog-v3.json"; then echo "  ok   catalog 含 $c"; else echo "  MISS catalog $c"; fail=1; fi
done

echo "== crash-watch(服务 + preset + diagnose-crash 技能)"
check usr/lib/systemd/user/linxira-crash-watch.service
check usr/lib/systemd/user-preset/90-linxira-crash-watch.preset
check usr/share/applications/org.linxira.CrashWatch.desktop
skill=$(find "$work" -path "*linxira_crash_watch/skills/diagnose-crash/SKILL.md" -print -quit)
if [[ -n "$skill" ]]; then echo "  ok   ${skill#"$work"}"; else echo "  MISS diagnose-crash/SKILL.md"; fail=1; fi

echo "== 包版本(清单内 Linxira 包)"
while read -r pkg; do
  [[ "$pkg" == linxira-* ]] || continue
  printf '  %-30s %s\n' "$pkg" "$(pacman --root "$work" --dbpath "$work/var/lib/pacman" -Q "$pkg" 2>/dev/null || echo MISSING)"
done < "$packages_file"

echo "== 许可目录"
missing=$(python3 - "$work" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
data = json.loads((root / "usr/share/doc/linxira/license-manifest.json").read_text())
miss = [p["name"] for p in data.get("packages", []) if p.get("builtBy") == "linxira" and not p.get("licensesDir")]
print(" ".join(miss))
PY
)
if [[ -n "$missing" ]]; then echo "  MISS licenses dir: $missing"; fail=1; else echo "  ok   全部 Linxira 包都有 licenses/"; fi

echo "== 与艺术仓一致性"
same_lf usr/share/linxira/linxira-icon.svg "$artwork/assets/logo/linxira-icon.svg"
same_lf usr/share/linxira/linxira-logo-braille60.ansi "$artwork/assets/ascii/linxira-logo-braille60.ansi"

echo "== 根证书"
ca=$(grep -c 'BEGIN CERTIFICATE' "$work/etc/ssl/certs/ca-certificates.crt" 2>/dev/null || echo 0)
echo "  info 根证书 $ca"; [[ $ca -ge 100 ]] || { echo "  MISS 根证书 <100"; fail=1; }

[[ $fail -eq 0 ]] && echo "== 校验全部通过" || echo "== 校验失败"
exit $fail
