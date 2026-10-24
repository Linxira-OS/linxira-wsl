#!/usr/bin/env bash
# Linxira WSL rootfs 构建器
# 产物: linxira-wsl-<version>-x86_64.tar.gz (+ .sha256), 供 wsl --import 使用。
#
# 依赖: Arch 环境(或容器) + pacstrap + sudo; 需联网(Arch 镜像 + linxira 仓库)。
# 环境变量:
#   LINXIRA_REPO_URL  linxira 包仓库(默认官方 Pages 仓库)
#   LINXIRA_MIRROR    Arch 镜像(默认 USTC)
#
# 教训(2026-09-28 实际事故): 构建目录必须落在普通磁盘, 避开 /tmp ——
# rootfs 1.6G + tar.gz 0.5G, tmpfs 即内存, 写满后同机其它构建进程会被
# OOM 杀掉。本脚本的工作目录固定在当前目录下, 不用 mktemp -d /tmp。
set -euo pipefail

# 教训(2026-10-25 实际事故): 在 Windows 盘(/mnt/c|/mnt/f, 9p/drvfs)上构建会
# 1) 创建不了字符/块设备节点(gnupg 的 socket 直接报 "Operation not supported"),
# 2) 整条链路经 9p 转换层, pacstrap/chroot/tar 都慢一个数量级。
# 构建必须在 WSL 发行版内部 ext4 上: 先把仓库和源码拷进 ~ 再跑本脚本。
fs_type=$(findmnt -n -o FSTYPE --target "$PWD" 2>/dev/null || echo unknown)
case "$fs_type" in
  9p|drvfs|v9fs)
    echo "错误: 当前目录在 Windows 盘上($fs_type)，构建必须放在 WSL 内部 ext4。" >&2
    echo "      例: mkdir -p ~/build && tar -C \"$PWD\" -cf - . | tar -C ~/build -xf - --one-top-level=linxira-wsl" >&2
    if [[ ${LINXIRA_ALLOW_DRVFS:-0} == 1 ]]; then
      echo "警告: LINXIRA_ALLOW_DRVFS=1 覆盖了守卫，继续（仅供排障）。" >&2
    else
      exit 65
    fi
    ;;
esac

repo_url=${LINXIRA_REPO_URL:-https://linxira-os.github.io/linxira-packages}
mirror_url=${LINXIRA_MIRROR:-https://mirrors.ustc.edu.cn/archlinux}
version=${1:-$(date +%Y.%m.%d)}
outdir=${OUTDIR:-out}
work=".build-wsl"

usage() {
  printf 'Usage: %s [version]   (env: LINXIRA_REPO_URL LINXIRA_MIRROR OUTDIR)\n' "${0##*/}" >&2
  exit 64
}
[[ ${1:-} == --help ]] && usage

[[ -r wsl-packages.x86_64 ]] || { echo "wsl-packages.x86_64 not found (run from repo root)" >&2; exit 64; }
[[ -r wsl.conf ]] || { echo "wsl.conf not found (run from repo root)" >&2; exit 64; }

mkdir -p "$work/root" "$outdir"

cat > "$work/pacman.conf" <<EOF
[options]
HoldPkg = pacman glibc
Architecture = x86_64
SigLevel = Required DatabaseOptional

[core]
Server = $mirror_url/\$repo/os/\$arch

[extra]
Server = $mirror_url/\$repo/os/\$arch

# 构建期引导链说明: linxira-keyring 本身来自 [linxira], 对它做签名验证存在
# 鸡生蛋问题(密钥在被安装的包里)。因此构建期对本仓库不验签, 镜像整体完整性
# 由发布产物 sha256 把关(与 ISO 离线仓库同一威胁模型)。装入镜像的最终
# /etc/pacman.conf 使用与 ISO 装机完全相同的验签配置(见 finalize 阶段),
# 首次 pacman -Sy 即以 linxira-keyring 验签。
[linxira]
SigLevel = Never
Server = $repo_url/\$arch
EOF

mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' wsl-packages.x86_64)

# 明确不进系统(2026-10-25 决定): linxira-bio-sdk* 与 linxira-zeta*(含 zeta 五件套)。
# 它们可能存在于 [linxira] 仓库, 但镜像不得安装 —— 清单写了就构建失败。
forbidden='^linxira-(bio-sdk|zeta)(-|$)'
bad=()
for pkg in "${packages[@]}"; do
  [[ $pkg =~ $forbidden ]] && bad+=("$pkg")
done
if ((${#bad[@]})); then
  printf '错误: 包清单含禁止安装的包: %s\n' "${bad[*]}" >&2
  exit 66
fi

printf '==> pacstrap %s 个包...\n' "${#packages[@]}"
sudo pacstrap -C "$work/pacman.conf" "$work/root" "${packages[@]}"

# 依赖解析后也可能把它们带进来(例如某个包把 zeta 写成硬依赖), 装完必须复查。
if sudo pacman --root "$work/root" --dbpath "$work/root/var/lib/pacman" -Q 2>/dev/null \
     | grep -qE '^linxira-(bio-sdk|zeta)(-| )'; then
  sudo pacman --root "$work/root" --dbpath "$work/root/var/lib/pacman" -Q 2>/dev/null \
    | grep -E '^linxira-(bio-sdk|zeta)(-| )' >&2
  echo "错误: 镜像里出现了 bio-sdk / zeta 包(禁止项)" >&2
  exit 66
fi

# ---- finalize: 镜像内目标系统配置 ----
sudo rm -rf "$work/root/var/cache/pacman/pkg/"*

# /etc/os-release 符号链接: pacstrap 产物缺失, WSL 与 lsb_release 均依赖它
sudo ln -sf ../usr/lib/os-release "$work/root/etc/os-release"

sudo install -Dm644 wsl.conf "$work/root/etc/wsl.conf"

# 镜像版本标识: 与 ISO 的 /etc/linxira-release 对齐。许可生成器与排查都靠它
# (generate-notices.py 在未显式给 --version 时读这份文件)。
printf '%s\n' "$version" | sudo tee "$work/root/etc/linxira-release" >/dev/null

# 目标系统仓库配置 = ISO 装机同款(linxirapacstrap._enable_target_linxira_repo)。
# 实测(2026-09-28): pacstrap 不会把 -C 指定的构建配置拷入目标 /etc/pacman.conf
# (目标保留 stock 配置), 因此 [linxira] 段必须显式追加(幂等)。
if ! sudo grep -q '^\[linxira\]' "$work/root/etc/pacman.conf"; then
  {
    echo ""
    echo "[linxira]"
    echo "SigLevel = Required DatabaseOptional"
    echo "Server = ${repo_url}/\$arch"
  } | sudo tee -a "$work/root/etc/pacman.conf" >/dev/null
fi

# 服务: 仅启用 components 系统事务服务; guard 定时器刻意不默认启用
# (WSL VM 闲置即关停, 定时器只在运行期触发, 语义弱化——见 README)
sudo systemctl --root "$work/root" enable linxira-components.service

# ---- 品牌与终端标识(2026-10-24)----
# logo 由 linxira-artwork 提供: /usr/share/linxira/linxira-logo-braille60.ansi
# (原点框 Origin Frame, 真彩盲文 30x15 = 60x60 点; 生成器 linxira-artwork/tools/gen-brand-assets.py)。
# 只放配置不自动打印: 用户敲 fastfetch 才出现, 不污染管道/脚本输出。
sudo install -Dm644 fastfetch-linxira.jsonc "$work/root/etc/fastfetch/config.d/linxira.jsonc"

# ---- 证书断言(2026-10-20)----
# 背景: WSL 侧曾报「部分网站缺证书」, 实测为 Windows 侧 Steam++(hosts 里 #S302 条目)
# 把域名钉到 127.0.0.1, 再经 DNS 传导进 WSL —— 而 WSL 的 127.0.0.1 是它自己的虚拟机,
# 于是连接被拒。与镜像无关(实测镜像内 121 张根证书齐全)。但这里仍把「静默失证」变成
# 构建硬失败: update-ca-trust 必须跑过, bundle 必须存在且证书数量正常(正常 Arch ≈120+)。
sudo arch-chroot "$work/root" /usr/sbin/update-ca-trust 2>/dev/null || true
ca_bundle="$work/root/etc/ssl/certs/ca-certificates.crt"
[[ -e "$ca_bundle" ]] || { echo "错误: 缺少 $ca_bundle" >&2; exit 1; }
ca_count=$(grep -c 'BEGIN CERTIFICATE' "$work/root/etc/ca-certificates/extracted/tls-ca-bundle.pem" 2>/dev/null || true)
[[ "${ca_count:-0}" -ge 100 ]] || { echo "错误: 根证书数量异常(${ca_count:-0} < 100)" >&2; exit 1; }
sudo pacman --root "$work/root" --dbpath "$work/root/var/lib/pacman" -Q \
  ca-certificates ca-certificates-mozilla ca-certificates-utils >/dev/null \
  || { echo "错误: 证书三件套未安装" >&2; exit 1; }
printf '==> 证书检查通过: %s 张根证书\n' "$ca_count"

# ---- 发布证据: 第三方声明 + 源码提供(2026-10-24)----
# GPL/AGPL 二进制随镜像分发 ⇒ 必须带 THIRD-PARTY-NOTICES / SOURCE-OFFER /
# machine-readable license-manifest。生成器在 packages 仓(同一工作区), 缺失即构建失败。
notices_script="$(cd .. && pwd)/packages/scripts/generate-notices.py"
[[ -r "$notices_script" ]] || { echo "错误: 缺少 $notices_script" >&2; exit 1; }
sudo python3 "$notices_script" --root "$work/root" --version "$version"
for evidence in THIRD-PARTY-NOTICES.md SOURCE-OFFER license-manifest.json; do
  sudo test -s "$work/root/usr/share/doc/linxira/$evidence" \
    || { echo "错误: 缺少发布证据 $evidence" >&2; exit 1; }
done

# ---- 打包 ----
image="linxira-wsl-${version}-x86_64.tar.gz"
printf '==> 打包 %s...\n' "$outdir/$image"
sudo tar --numeric-owner -C "$work/root" -czf "$outdir/$image" .
(cd "$outdir" && sha256sum "$image" > "$image.sha256")
sudo du -sh "$work/root"
ls -lh "$outdir/$image"

sudo rm -rf "$work"
printf '完成: %s\n' "$outdir/$image"
