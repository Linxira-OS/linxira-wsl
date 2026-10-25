# linxira-wsl

Linxira OS as a WSL2 distribution: a CLI-first toolchain plus WSLg-capable
GUI tools, for `wsl --import` / `wsl --install --from-file` on Windows.

## What is this

A pacstrap-produced rootfs (tar.gz) with no kernel/firmware/bootloader
(WSL ships its own kernel) — only what you actually use in a terminal:

- `linxira-components` / `linxira-component-manager` — component installer
  (CLI, TUI and GUI share one transaction chain)
- `linxira-config` (Config Hub CLI) — mirrors, network, hardening,
  workspace guard, environment variables, software stacks
- `linxira-recovery-diagnostics` — evidence & repair planning (CLI + GUI)
- `linxira-update`, `linxira-wiki`, `linxira-catalog`,
  `linxira-completion-agent`, `linxira-crash-watch`

Full manifest: `wsl-packages.x86_64` — 16 explicit entries, ~318 packages after
dependency resolution (~1.7 GB installed, ~0.5 GB compressed; that measurement
predates adding `linxira-crash-watch`).

## Usage

```powershell
wsl --import linxira C:\path\for\vhdx linxira-wsl-<version>-x86_64.tar.gz --version 2
wsl -d linxira

wsl --unregister linxira   # remove
```

Default user is `root`, systemd is enabled (see `wsl.conf`).

## Relation to the desktop ISO

| | ISO install | WSL |
|---|---|---|
| Kernel / boot / partitioning | handled by installer | not applicable (WSL kernel) |
| Desktop | catalog choice (plasma/cosmic/server/minimal) | no session; GUI tools via WSLg (Win11) |
| Software stacks | installer / component-manager | `linxira-config stack` or component-manager (same chain) |
| Workspace guard | 30-min timer | off by default (WSL VMs stop when idle); opt-in |

### Zeta (optional, npm only)

The image deliberately does **not** ship Zeta. For terminal work the upstream
npm distribution is the right fit (and the only one that fits a headless WSL):

```bash
sudo pacman -S nodejs npm          # image ships no Node runtime
npm i -g @linxiraos/zeta           # zetacode — coding agent CLI
npm i -g @linxiraos/main           # zetawork — workbench (optional)
```

The full binary package (`linxira-zeta`, ~209 MiB) is the desktop path, not the
WSL one: it pulls X11/Wayland/Vulkan and is meant for an installed system.

## Build

On Arch (or in a container):

```bash
sudo pacman -S --needed arch-install-scripts
./build-wsl-rootfs.sh            # artifacts in out/
LINXIRA_MIRROR=https://mirrors.aliyun.com/archlinux ./build-wsl-rootfs.sh
```

The build deliberately avoids `/tmp` (tmpfs is RAM; a full tmpfs OOM-kills
other builds on the same machine — real incident).

## Releases

GitHub Releases carry `linxira-wsl-<YYYY.MM.DD>-x86_64.tar.gz` plus
`.sha256`. Chinese documentation follows.
---

## 简体中文

Linxira OS 的 WSL2 发行版镜像：纯 CLI 工具链 + 可经 WSLg 显示的图形工具，
供 Windows 侧 `wsl --import` / `wsl --install --from-file` 使用。

## 这是什么

一份 pacstrap 产出的 rootfs（tar.gz），不含内核/固件/引导（WSL 自带内核），
包含 Linxira 一方工具链：

- `linxira-components` / `linxira-component-manager` —— 组件安装（系统事务引擎）
- `linxira-config`（Config Hub CLI）—— 镜像源、网络、加固、工作区守护等系统配置
- `linxira-recovery-diagnostics` —— 恢复诊断（CLI + GUI）
- `linxira-update`、`linxira-wiki`、`linxira-catalog`、`linxira-completion-agent`、`linxira-crash-watch`

完整清单见 `wsl-packages.x86_64` —— 32 个显式条目,解析依赖后三百余个包
(安装体积/压缩体积以构建输出为准,脚本结尾会打印 `du -sh`)。证书栈是**硬要求**:
`ca-certificates` 显式声明,构建脚本会断言根证书库存在且证书数量正常(缺失即构建失败)。

## 网络（中国网络环境）

镜像**不内置**任何 DNS/代理/hosts 覆盖 —— `/etc/hosts` 与 `/etc/resolv.conf` 由 WSL 自动生成,
网络解析完全交给 Windows 侧。国内网络下"某些网站打不开"通常是宿主侧原因,与本镜像无关。
最常见的一种是 **Steam++ / Watt Toolkit 之类加速器**:它把域名写进 Windows `hosts` 指向
`127.0.0.1`(行尾带 `#S302` 标记),WSL2 经 Windows 解析器拿到这些地址,而 **WSL 里的
`127.0.0.1` 是 WSL 自己的虚拟机**,于是连接被拒(`Connection refused`)。这**不是证书问题**:
本镜像根证书库与 Arch 一致(三件套 + 约 120 张根证书)。

要让加速器/代理在 WSL 内生效,二选一:

- **镜像网络模式**(推荐,Win11 22H2+):在 `%UserProfile%\.wslconfig` 加
  `[wsl2]` / `networkingMode=mirrored`,然后 `wsl --shutdown` —— 此后 WSL 的 `127.0.0.1`
  就是 Windows 的 `127.0.0.1`;
- **显式代理**:WSL 内 `export HTTPS_PROXY=http://<Windows 宿主 IP>:<端口>`(NAT 模式的宿主
  IP 见 `/etc/resolv.conf` 的 nameserver),或写进 shell 启动文件。

## 使用

```powershell
# 导入（兼容面最广）
wsl --import linxira C:\path\for\vhdx linxira-wsl-<version>-x86_64.tar.gz --version 2
wsl -d linxira

# 卸载
wsl --unregister linxira
```

导入后默认 root、systemd 已启用（见 `wsl.conf`）。

## 与桌面版的关系

| | ISO 安装 | WSL |
|---|---|---|
| 内核/引导/分区 | 安装器处理 | 不适用（WSL 自带） |
| 桌面 | catalog 选择（plasma/cosmic/server/最小） | 无会话；GUI 工具走 WSLg（Win11） |
| 软件栈 | 装机时选择 / component-manager | `linxira-component-manager`（同一条链） |
| 工作区守护 | 定时器每 30 分钟 | 不默认启用（WSL VM 闲置即关停，定时器只在运行期触发）；可手动 `linxira-config workspace-guard enable` |

## Zeta（可选，仅推荐 npm 版）

镜像**有意不装** Zeta。终端场景用上游 npm 分发最合适，也是无图形环境里唯一合理的装法：

```bash
sudo pacman -S nodejs npm          # 镜像不自带 Node
npm i -g @linxiraos/zeta           # zetacode —— 编码 agent 命令行
npm i -g @linxiraos/main           # zetawork —— 工作台（可选）
```

完整二进制包（`linxira-zeta`，约 209 MiB）是**桌面系统**的路线，不是 WSL 的：
它依赖 X11/Wayland/Vulkan，面向已安装的桌面环境。

## 构建

在 Arch 环境（或 arch 容器）中：

```bash
sudo pacman -S --needed arch-install-scripts
./build-wsl-rootfs.sh            # 产物在 out/
LINXIRA_MIRROR=https://mirrors.aliyun.com/archlinux ./build-wsl-rootfs.sh
```

构建脚本避开 `/tmp`（tmpfs 即内存，实际事故：写满后同机构建进程被 OOM 杀）。

**构建位置（硬要求）**：必须在 WSL 发行版内部的 ext4 上跑，不能直接对着
`/mnt/c`、`/mnt/f` 这类 9p 转换路径构建——那里建不出字符/块设备节点
（`cp: cannot create special file ... Operation not supported`），且整条
pacstrap/chroot/tar 链路慢一个数量级。先把仓库和 `[linxira]` 仓库拷进 `~`：

```bash
mkdir -p ~/linxira-build/linxira-wsl
tar -C /mnt/f/Linxira-OS/linxira-wsl --exclude=.git --exclude=.build-wsl --exclude=out \
    -cf - . | tar -C ~/linxira-build -xf - --one-top-level=linxira-wsl
cp -a /mnt/f/Linxira-OS/linxira-packages ~/linxira-build/
mkdir -p ~/linxira-build/packages/scripts
cp /mnt/f/Linxira-OS/packages/scripts/generate-notices.py ~/linxira-build/packages/scripts/
cd ~/linxira-build/linxira-wsl
LINXIRA_REPO_URL=file://$HOME/linxira-build/linxira-packages OUTDIR=$HOME/linxira-build/out \
  ./build-wsl-rootfs.sh 2026.10.25
```

脚本会探测当前文件系统（`findmnt`），命中 9p/drvfs 直接拒绝（退出码 65）；
排障时可设 `LINXIRA_ALLOW_DRVFS=1` 强制跳过。产物 `out/` 再拷回 Windows 盘即可。

## 校验（发布门）

```bash
./verify-wsl-rootfs.sh out/linxira-wsl-<YYYY.MM.DD>-x86_64.tar.gz
```

只读断言：许可三件套、品牌资产与图标族、fastfetch 终端标识、catalog 的
`component-fish/nushell/zsh` 条目、crash-watch 服务 + `90-` preset + `diagnose-crash`
技能、清单内 Linxira 包版本、**每个 Linxira 包都有 `/usr/share/licenses/<pkg>/`**、
与 `linxira-artwork` 的品牌资产逐字节一致（忽略 CRLF）、根证书 ≥100 张。
任一失败退出非零，可直接接发布脚本。`LINXIRA_ARTWORK_DIR` 可指定艺术仓位置。

## 版本

以 GitHub Release 为准，命名 `linxira-wsl-<YYYY.MM.DD>-x86_64.tar.gz`，
同目录附 `.sha256`。
