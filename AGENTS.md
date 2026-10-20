# linxira-wsl · Agent 开发规范

> **档位:B 内容仓** · 本仓是 **Linxira OS 的 WSL2 发行版镜像**(pacstrap 产出的 rootfs,纯 CLI 工具链 + 可经 WSLg 显示的 GUI 工具)。
> 通用条款见工作区总纲 `f:\Linxira-OS\AGENTS.md`,发布与测试口径见
> `linxira-os/docs/RELEASE_STANDARD.md`,本文件只写本仓特有事项,不复述通用条款。

## 职责

- 生成供 Windows 侧 `wsl --import` / `wsl --install --from-file` 导入的 rootfs `tar.gz`(不含内核/固件/引导,WSL 自带内核)。
- 内含 Linxira 一方工具链:`linxira-components` / `linxira-component-manager`、`linxira-config`(Config Hub)、
  `linxira-recovery-diagnostics`、`linxira-update`、`linxira-wiki`、`linxira-catalog`、`linxira-completion-agent`。

## 目录布局

- `build-wsl-rootfs.sh` —— 构建器(Arch/容器内跑 `pacstrap` + finalize + 打包 `tar.gz` + `.sha256`);产物在 `out/`。
- `wsl-packages.x86_64` —— 包清单,**30 个显式条目**(解析依赖后三百余个包;体积以构建输出为准)。
  2026-10-20 起:`ca-certificates` 改为**显式声明**(此前靠 `curl` 传递依赖),并补了常用 CLI 基线
  (git/wget/nano/less/man-db/man-pages/bash-completion/unzip/zip/which/rsync/dnsutils/jq)——
  本仓刻意**不做"绝对精简"镜像**。
- `wsl.conf` —— 构建时装入镜像 `/etc/wsl.conf`(`systemd=true`、`default=root`、`hostname=linxira`)。
- `.gitignore` —— 忽略 `out/`、`.build-wsl/`(构建产物,勿入仓)。

## 是否随 ISO 发布

- **不随 ISO 发布**。本仓产出的是 WSL 专用镜像,独立于桌面 ISO 链:`README.md` 说明经 GitHub Releases 分发
  `linxira-wsl-<YYYY.MM.DD>-x86_64.tar.gz` + `.sha256`。
- **新 WSL 镜像尚在开发、未发布**。措辞须遵循发布规范:可下载测试产物**不得称正式版/released**。

## 上游来源与去品牌化

- 自研一方构建,非 CachyOS 派生;全仓**未发现 `cachyos` 硬编码**(已 grep 无匹配)。
- 设计思路与 `linxira-iso-direct` 的 `target-packages-minimal.x86_64` 同源(无桌面精简系统),WSL 变体额外含 Linxira 工具链。

## 禁区

- 构建**必须避开 `/tmp`**(tmpfs 即内存;实际事故:写满后同机构建进程被 OOM 杀)—— 勿改回 `mktemp -d /tmp`。
- 不要给 WSL 变体加内核 / 固件 / 引导;不要装 `NetworkManager`(WSL 网络由 Windows 侧管理)。
- 构建期 `[linxira]` 仓库用 `SigLevel = Never` **仅为引导链**(密钥在被安装的包里,存在鸡生蛋问题);
  装入镜像的最终 `/etc/pacman.conf` 使用与 ISO 装机完全相同的验签配置 —— 勿改动这一威胁模型。
- **证书断言不可删**(`build-wsl-rootfs.sh` 的「证书断言」段):`update-ca-trust` + bundle 存在 +
  根证书 ≥100 张 + 三件套已装。曾出现「部分网站缺证书」的误判(实为宿主 Steam++ 的 `127.0.0.1`
  hosts 条目经 DNS 传导进 WSL),断言是为了将来真缺时**构建直接失败**而不是静默。
- **不要在镜像里内置 DNS/代理/hosts 覆盖**(`/etc/hosts`、`/etc/resolv.conf`、
  `[network] generate*=false` 都不要碰):国内网络问题属宿主侧,镜像须保持 WSL 默认,见 README「网络」。