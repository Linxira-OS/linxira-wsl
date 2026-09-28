# linxira-wsl

Linxira OS 的 WSL2 发行版镜像：纯 CLI 工具链 + 可经 WSLg 显示的图形工具，
供 Windows 侧 `wsl --import` / `wsl --install --from-file` 使用。

## 这是什么

一份 pacstrap 产出的 rootfs（tar.gz），不含内核/固件/引导（WSL 自带内核），
包含 Linxira 一方工具链：

- `linxira-components` / `linxira-component-manager` —— 组件安装（系统事务引擎）
- `linxira-config`（Config Hub CLI）—— 镜像源、网络、加固、工作区守护等系统配置
- `linxira-recovery-diagnostics` —— 恢复诊断（CLI + GUI）
- `linxira-update`、`linxira-wiki`、`linxira-catalog`、`linxira-completion-agent`

完整清单见 `wsl-packages.x86_64`（约 318 个包，装好 1.6G，压缩后约 0.5G）。

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

## 构建

在 Arch 环境（或 arch 容器）中：

```bash
sudo pacman -S --needed arch-install-scripts
./build-wsl-rootfs.sh            # 产物在 out/
LINXIRA_MIRROR=https://mirrors.aliyun.com/archlinux ./build-wsl-rootfs.sh
```

构建脚本避开 `/tmp`（tmpfs 即内存，实际事故：写满后同机构建进程被 OOM 杀）。

## 版本

以 GitHub Release 为准，命名 `linxira-wsl-<YYYY.MM.DD>-x86_64.tar.gz`，
同目录附 `.sha256`。
