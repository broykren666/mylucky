# Lucky 管理脚本 (Alpine Linux 专用)

一个专为 Alpine Linux (特别是 NAT VPS) 设计的 Lucky 一键管理脚本。支持 OpenRC 服务管理、自动架构识别、快捷命令以及脚本自动更新。

---

## 功能特点

- **一键安装/更新**：自动识别系统架构 (amd64, arm64, arm7 等) 并下载安装最新版 Lucky。
- **服务管理**：集成 OpenRC，支持启动、停止、重启及开机自启。
- **快捷启动**：安装后可通过 `lucky` 命令随时呼出管理菜单。
- **环境适配**：完美兼容 Alpine 的 `ash` 终端，自动处理依赖 (wget, curl, tar, ca-certificates)。
- **智能 IP 显示**：自动获取并缓存公网 IP，方便 NAT 用户查看管理地址。
- **自更新功能**：脚本内置从 GitHub 重新获取最新版本的功能。

## 快速开始

在终端输入以下命令即可一键下载并运行：

```bash
wget -qO lucky.sh https://raw.githubusercontent.com/broykren666/mylucky/refs/heads/main/lucky.sh && chmod +x lucky.sh && ./lucky.sh
```

## 使用说明

1. **运行脚本**：首次运行后，可直接输入 `lucky` 进入菜单。
2. **默认信息**：
   - **管理地址**：`http://你的公网IP:16601` (请确保 NAT 端口映射已正确配置)
   - **默认账号**：`666`
   - **默认密码**：`666`
3. **安装路径**：
   - 程序目录：`/opt/lucky`
   - 配置文件：`/opt/lucky/lucky.conf`
   - 服务脚本：`/etc/init.d/lucky`

## 菜单选项

- `1`: 安装或更新 Lucky 主程序。
- `2`: 彻底卸载 Lucky 及其相关配置和服务。
- `3-5`: 管理 Lucky 服务的运行状态。
- `6`: 从 GitHub 获取并更新本管理脚本。
- `0`: 退出脚本。

## 依赖要求

- 操作系统：Alpine Linux
- 用户权限：root 用户

## 开源协议

基于原项目 [Lucky](https://github.com/gkd-is/lucky) 进行二次脚本开发。
